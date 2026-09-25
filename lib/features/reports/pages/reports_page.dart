import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/category.dart';
import '../../../models/transaction.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/capsule_selector.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/month_selector.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/summary_card.dart';
import '../../finance/providers/finance_provider.dart';
import '../services/report_exporter.dart';

enum _PeriodType { last6, year, specific }

enum _ReportTab { expenses, income }

class _MonthlyPoint {
  const _MonthlyPoint({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const _palette = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  _PeriodType _periodType = _PeriodType.last6;
  _ReportTab _reportTab = _ReportTab.expenses;
  int? _year;
  DateTimeRange? _range;
  bool _exporting = false;

  static const _monthNames = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) context.read<FinanceProvider>().load(userId);
  }

  bool _inPeriod(Transaction transaction, FinanceProvider finance) {
    final now = finance.currentDate;
    switch (_periodType) {
      case _PeriodType.last6:
        final start = DateTime(now.year, now.month - 5, 1);
        return !transaction.date.isBefore(start);
      case _PeriodType.year:
        final year = _year ?? now.year;
        return transaction.date.year == year;
      case _PeriodType.specific:
        if (_range == null) return true;
        final end = DateTime(
          _range!.end.year,
          _range!.end.month,
          _range!.end.day,
          23,
          59,
        );
        return !transaction.date.isBefore(_range!.start) &&
            !transaction.date.isAfter(end);
    }
  }

  List<Transaction> _filtered(FinanceProvider finance) =>
      finance.transactions.where((t) => _inPeriod(t, finance)).toList();

  List<_MonthlyPoint> _monthlySeries(
    FinanceProvider finance,
    List<Transaction> filtered,
  ) {
    final points = <_MonthlyPoint>[];
    final now = finance.currentDate;

    void addMonth(DateTime month) {
      final income = filtered
          .where(
            (t) =>
                t.isIncome &&
                t.date.year == month.year &&
                t.date.month == month.month,
          )
          .fold(0.0, (sum, t) => sum + t.amount);
      final expense = filtered
          .where(
            (t) =>
                t.isExpense &&
                t.date.year == month.year &&
                t.date.month == month.month,
          )
          .fold(0.0, (sum, t) => sum + t.amount);
      points.add(
        _MonthlyPoint(
          label:
              '${_monthNames[month.month - 1]}/${month.year.toString().substring(2)}',
          income: income,
          expense: expense,
        ),
      );
    }

    switch (_periodType) {
      case _PeriodType.last6:
        for (var i = 5; i >= 0; i--) {
          addMonth(DateTime(now.year, now.month - i, 1));
        }
      case _PeriodType.year:
        final year = _year ?? now.year;
        for (var month = 1; month <= 12; month++) {
          addMonth(DateTime(year, month, 1));
        }
      case _PeriodType.specific:
        if (_range == null) return points;
        var cursor = DateTime(_range!.start.year, _range!.start.month, 1);
        final end = DateTime(_range!.end.year, _range!.end.month, 1);
        while (!cursor.isAfter(end)) {
          addMonth(cursor);
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }
    }
    return points;
  }

  List<CategoryTotal> _categoryTotals(
    FinanceProvider finance,
    List<Transaction> filtered,
    String type,
  ) {
    final totals = <CategoryTotal>[];
    for (final category in finance.categories) {
      if (category.type != type) continue;
      final total = filtered
          .where((t) => t.categoryId == category.id)
          .fold(0.0, (sum, t) => sum + t.amount);
      if (total > 0) {
        totals.add(CategoryTotal(category: category, total: total));
      }
    }
    totals.sort((a, b) => b.total.compareTo(a.total));
    return totals;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  String _periodLabel(FinanceProvider finance) {
    switch (_periodType) {
      case _PeriodType.last6:
        return 'Últimos 6 meses';
      case _PeriodType.year:
        return 'Ano ${_year ?? finance.currentDate.year}';
      case _PeriodType.specific:
        if (_range == null) return 'Período';
        return '${formatDateOnly(_range!.start.toIso8601String())} - '
            '${formatDateOnly(_range!.end.toIso8601String())}';
    }
  }

  Future<void> _export({required bool pdf}) async {
    final finance = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final filtered = _filtered(finance);
    final income = filtered
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = filtered
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final data = ReportExportData(
      periodLabel: _periodLabel(finance),
      transactions: filtered,
      categories: finance.categories,
      income: income,
      expense: expense,
    );

    setState(() => _exporting = true);
    try {
      if (pdf) {
        await ReportExporter.exportPdf(data);
      } else {
        await ReportExporter.exportExcel(data);
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível exportar o relatório.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = context.watch<FinanceProvider>();

    if (finance.loading && !finance.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered(finance);
    final periodIncome = filtered
        .where((t) => t.isIncome)
        .fold(0.0, (s, t) => s + t.amount);
    final periodExpense = filtered
        .where((t) => t.isExpense)
        .fold(0.0, (s, t) => s + t.amount);
    final periodBalance = periodIncome - periodExpense;
    final series = _monthlySeries(finance, filtered);
    final years = finance.transactions.map((t) => t.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    final tabType = _reportTab == _ReportTab.expenses ? 'expense' : 'income';
    final tabTotals = _categoryTotals(finance, filtered, tabType);
    final tabTotal = tabTotals.fold<double>(0, (sum, item) => sum + item.total);
    final tabCount = filtered.where((t) => t.type == tabType).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        MonthSelector(
          date: finance.currentDate,
          onPrevious: finance.previousMonth,
          onNext: finance.nextMonth,
        ),
        const SizedBox(height: 16),
        _MonthBalanceCard(
          currentMonth: finance.currentDate,
          income: finance.monthlyIncome,
          expenses: finance.monthlyExpenses,
        ),
        const SizedBox(height: 16),
        _ReportDonutCard(
          tab: _reportTab,
          onTabChanged: (index) => setState(
            () => _reportTab = index == 0
                ? _ReportTab.expenses
                : _ReportTab.income,
          ),
          totals: tabTotals,
          total: tabTotal,
          transactionCount: tabCount,
          palette: _palette,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exporting ? null : () => _export(pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Exportar PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exporting ? null : () => _export(pdf: false),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Exportar Excel'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PeriodPickerCard(
          periodType: _periodType,
          onPeriodChanged: (value) async {
            setState(() => _periodType = value);
            if (_periodType == _PeriodType.specific && _range == null) {
              await _pickRange();
            }
          },
          year: _year,
          years: years,
          onYearChanged: (value) => setState(() => _year = value),
          range: _range,
          onPickRange: _pickRange,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Entradas',
                value: formatCurrency(periodIncome),
                icon: Icons.trending_up,
                accent: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'Saídas',
                value: formatCurrency(periodExpense),
                icon: Icons.trending_down,
                accent: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SummaryCard(
          title: 'Saldo do período',
          value: formatCurrency(periodBalance),
          icon: Icons.attach_money,
          accent: periodBalance >= 0
              ? const Color(0xFF3B82F6)
              : const Color(0xFFF97316),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visão Geral Financeira',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (series.isEmpty ||
                  series.every((p) => p.income == 0 && p.expense == 0))
                const EmptyState(
                  icon: Icons.bar_chart,
                  message: 'Sem dados no período.',
                )
              else
                _MonthlyBars(points: series),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo Acumulado',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (series.isEmpty ||
                  series.every((p) => p.income == 0 && p.expense == 0))
                const EmptyState(
                  icon: Icons.show_chart,
                  message: 'Sem dados no período.',
                )
              else
                SizedBox(height: 180, child: _BalanceAreaChart(points: series)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ComparisonTable(points: series),
        const SizedBox(height: 16),
        _InsightsCard(
          income: periodIncome,
          expense: periodExpense,
          transactionCount: filtered.length,
        ),
        const SizedBox(height: 16),
        _HealthCard(
          income: periodIncome,
          expense: periodExpense,
          transactionCount: filtered.length,
        ),
      ],
    );
  }
}

/// Card de saldo do mês com barras de progresso de receitas e despesas.
class _MonthBalanceCard extends StatelessWidget {
  const _MonthBalanceCard({
    required this.currentMonth,
    required this.income,
    required this.expenses,
  });

  final DateTime currentMonth;
  final double income;
  final double expenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mint = isDark ? AppColors.mint : const Color(0xFF10B981);
    final max = income > expenses ? income : expenses;
    final effectiveMax = max <= 0 ? 1.0 : max;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saldo em ${formatMonth(currentMonth)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                formatCurrency(income - expenses),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressLine(
            label: 'Receitas',
            value: income,
            ratio: income / effectiveMax,
            color: mint,
          ),
          const SizedBox(height: 10),
          _ProgressLine(
            label: 'Despesas',
            value: expenses,
            ratio: expenses / effectiveMax,
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final String label;
  final double value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              formatCurrency(value),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card principal: gráfico de rosca + lista de categorias + rodapé.
class _ReportDonutCard extends StatelessWidget {
  const _ReportDonutCard({
    required this.tab,
    required this.onTabChanged,
    required this.totals,
    required this.total,
    required this.transactionCount,
    required this.palette,
  });

  final _ReportTab tab;
  final ValueChanged<int> onTabChanged;
  final List<CategoryTotal> totals;
  final double total;
  final int transactionCount;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = tab == _ReportTab.income;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: CapsuleSelector(
              options: const ['Despesas', 'Receitas'],
              selectedIndex: tab == _ReportTab.expenses ? 0 : 1,
              onChanged: onTabChanged,
            ),
          ),
          const SizedBox(height: 16),
          if (totals.isEmpty)
            const EmptyState(
              icon: Icons.pie_chart_outline,
              message: 'Sem dados no período.',
            )
          else ...[
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      // Ring interno + raio das seções precisam caber no box
                      // (200px de altura) para o gráfico não invadir o seletor
                      // de cápsulas acima nem as linhas de categorias abaixo.
                      centerSpaceRadius: 58,
                      startDegreeOffset: -90,
                      sections: [
                        for (var i = 0; i < totals.length; i++)
                          PieChartSectionData(
                            value: totals[i].total,
                            color: _colorFor(totals[i].category, i),
                            radius: 40,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isIncome ? 'Receitas' : 'Despesas',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatCurrency(total),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < totals.length; i++) ...[
              if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
              _DonutCategoryRow(
                total: totals[i],
                color: _colorFor(totals[i].category, i),
                percent: total <= 0 ? 0.0 : totals[i].total / total,
                isIncome: isIncome,
              ),
            ],
            const SizedBox(height: 4),
            Divider(height: 1, color: theme.colorScheme.outline),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    '$transactionCount ${transactionCount == 1 ? 'transação' : 'transações'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${isIncome ? '+' : '-'} ${formatCurrency(total).replaceFirst(r'R$', '').trim()}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorFor(Category category, int index) {
    final parsed = category.parsedColor;
    if (parsed != Colors.grey) return parsed;
    return palette[index % palette.length];
  }
}

class _DonutCategoryRow extends StatelessWidget {
  const _DonutCategoryRow({
    required this.total,
    required this.color,
    required this.percent,
    required this.isIncome,
  });

  final CategoryTotal total;
  final Color color;
  final double percent;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = isIncome
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              categoryIconFor(total.category.icon),
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              total.category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${(percent * 100).round()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${isIncome ? '+' : '-'} ${formatCurrency(total.total).replaceFirst(r'R$', '').trim()}',
                maxLines: 1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card com os controles de período (6 meses / ano / período).
class _PeriodPickerCard extends StatelessWidget {
  const _PeriodPickerCard({
    required this.periodType,
    required this.onPeriodChanged,
    required this.year,
    required this.years,
    required this.onYearChanged,
    required this.range,
    required this.onPickRange,
  });

  final _PeriodType periodType;
  final ValueChanged<_PeriodType> onPeriodChanged;
  final int? year;
  final List<int> years;
  final ValueChanged<int?> onYearChanged;
  final DateTimeRange? range;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Período da análise',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_PeriodType>(
              segments: const [
                ButtonSegment(value: _PeriodType.last6, label: Text('6 meses')),
                ButtonSegment(value: _PeriodType.year, label: Text('Ano')),
                ButtonSegment(
                  value: _PeriodType.specific,
                  label: Text('Período'),
                ),
              ],
              selected: {periodType},
              onSelectionChanged: (value) => onPeriodChanged(value.first),
            ),
          ),
          if (periodType == _PeriodType.year) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue:
                  year ??
                  (years.isNotEmpty ? years.first : DateTime.now().year),
              decoration: const InputDecoration(labelText: 'Ano'),
              items: [
                for (final year
                    in (years.isEmpty ? [DateTime.now().year] : years))
                  DropdownMenuItem(value: year, child: Text(year.toString())),
              ],
              onChanged: onYearChanged,
            ),
          ],
          if (periodType == _PeriodType.specific) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                range == null
                    ? 'Selecionar período'
                    : '${formatDateOnly(range!.start.toIso8601String())} - ${formatDateOnly(range!.end.toIso8601String())}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.points});

  final List<_MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = points
        .map((p) => p.income > p.expense ? p.income : p.expense)
        .fold(0.0, (max, value) => value > max ? value : max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar(point.income / safeMax, const Color(0xFF10B981)),
                      const SizedBox(width: 2),
                      _bar(point.expense / safeMax, const Color(0xFFEF4444)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      point.label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(double ratio, Color color) {
    const maxHeight = 130.0;
    return Container(
      width: 8,
      height: (ratio.clamp(0, 1) * maxHeight) + 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  final double income;
  final double expense;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savingsRate = income > 0 ? (income - expense) / income : 0.0;
    final insights = <({String text, Color color, IconData icon})>[];

    if (transactionCount < 5) {
      insights.add((
        text: 'Registre mais transações para gerar análises mais precisas.',
        color: Colors.blueGrey,
        icon: Icons.info_outline,
      ));
    }
    if (income > 0 && savingsRate < 0) {
      insights.add((
        text:
            'Você gastou mais do que ganhou no período. Revise suas despesas.',
        color: const Color(0xFFEF4444),
        icon: Icons.warning_amber_outlined,
      ));
    } else if (savingsRate >= 0.2) {
      insights.add((
        text:
            'Ótimo! Você poupou ${(savingsRate * 100).toStringAsFixed(0)}% da sua renda.',
        color: const Color(0xFF10B981),
        icon: Icons.check_circle_outline,
      ));
    } else if (income > 0) {
      insights.add((
        text:
            'Sua taxa de poupança foi de ${(savingsRate * 100).toStringAsFixed(0)}%. Tente chegar a 20%.',
        color: const Color(0xFFF59E0B),
        icon: Icons.trending_up,
      ));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final insight in insights) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(insight.icon, size: 18, color: insight.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(insight.text, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  final double income;
  final double expense;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = _score();
    final color = score == null
        ? theme.colorScheme.onSurfaceVariant
        : score >= 8
        ? const Color(0xFF10B981)
        : score >= 5
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saúde Financeira',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (score == null)
            Text(
              'Registre ao menos 5 transações no período para calcular seu score.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  '$score',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  '/10',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: score / 10,
                minHeight: 8,
                backgroundColor: theme.colorScheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(_message(score), style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  int? _score() {
    if (transactionCount < 5) return null;
    final savingsRate = income > 0
        ? (income - expense) / income
        : (expense > 0 ? -1.0 : 0.0);
    final base = 5 + (savingsRate * 10);
    return base.clamp(1, 10).round();
  }

  String _message(int score) {
    if (score >= 8) {
      return 'Excelente! Sua saúde financeira está muito boa. Continue assim.';
    }
    if (score >= 5) {
      return 'Sua saúde financeira é razoável. Busque poupar pelo menos 20% da renda.';
    }
    return 'Atenção: seus gastos estão elevados em relação à renda. Revise o orçamento.';
  }
}

class _BalanceAreaChart extends StatelessWidget {
  const _BalanceAreaChart({required this.points});

  final List<_MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var running = 0.0;
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      running += points[i].income - points[i].expense;
      spots.add(FlSpot(i.toDouble(), running));
    }
    final minValue = spots
        .map((s) => s.y)
        .fold<double>(0, (m, v) => v < m ? v : m);
    final maxValue = spots
        .map((s) => s.y)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final range = (maxValue - minValue).abs() < 1 ? 1.0 : (maxValue - minValue);

    return LineChart(
      LineChartData(
        minY: minValue - range * 0.1,
        maxY: maxValue + range * 0.1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              // Em intervalos maiores, mostra apenas alguns meses para os
              // rótulos não sobreporem uns aos outros.
              interval: points.length > 6
                  ? ((points.length / 3).ceil()).toDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                // Sempre exibe o primeiro e o último ponto (início/fim).
                if (index != 0 &&
                    index != points.length - 1 &&
                    value != value.roundToDouble()) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      points[index].label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.points});

  final List<_MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) return const SizedBox.shrink();

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparação Mensal',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: Text('Mês', style: headerStyle)),
              Expanded(
                child: Text(
                  'Entradas',
                  style: headerStyle,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  'Saídas',
                  style: headerStyle,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  'Variação',
                  style: headerStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const Divider(),
          for (var i = 1; i < points.length; i++) ...[
            Builder(
              builder: (context) {
                final previous = points[i - 1].expense;
                final current = points[i].expense;
                final variation = previous == 0
                    ? (current > 0 ? 100.0 : 0.0)
                    : (current - previous) / previous * 100;
                final color = variation > 0
                    ? const Color(0xFFEF4444)
                    : variation < 0
                    ? const Color(0xFF10B981)
                    : theme.colorScheme.onSurfaceVariant;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          points[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatCurrency(points[i].income),
                            maxLines: 1,
                            style: const TextStyle(color: Color(0xFF10B981)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatCurrency(points[i].expense),
                            maxLines: 1,
                            style: const TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${variation >= 0 ? '+' : ''}${variation.toStringAsFixed(0)}%',
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
