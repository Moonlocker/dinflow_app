import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/transaction.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/category_breakdown_card.dart';
import '../../dashboard/widgets/summary_card.dart';
import '../../finance/providers/finance_provider.dart';

enum _PeriodType { last6, year, specific }

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
  _PeriodType _periodType = _PeriodType.last6;
  int? _year;
  DateTimeRange? _range;

  static const _monthNames = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
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
        final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59);
        return !transaction.date.isBefore(_range!.start) && !transaction.date.isAfter(end);
    }
  }

  List<Transaction> _filtered(FinanceProvider finance) =>
      finance.transactions.where((t) => _inPeriod(t, finance)).toList();

  List<_MonthlyPoint> _monthlySeries(FinanceProvider finance, List<Transaction> filtered) {
    final points = <_MonthlyPoint>[];
    final now = finance.currentDate;

    void addMonth(DateTime month) {
      final income = filtered
          .where((t) => t.isIncome && t.date.year == month.year && t.date.month == month.month)
          .fold(0.0, (sum, t) => sum + t.amount);
      final expense = filtered
          .where((t) => t.isExpense && t.date.year == month.year && t.date.month == month.month)
          .fold(0.0, (sum, t) => sum + t.amount);
      points.add(_MonthlyPoint(
        label: '${_monthNames[month.month - 1]}/${month.year.toString().substring(2)}',
        income: income,
        expense: expense,
      ));
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
      if (total > 0) totals.add(CategoryTotal(category: category, total: total));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = context.watch<FinanceProvider>();

    if (finance.loading && !finance.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered(finance);
    final income = filtered.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
    final expense = filtered.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final balance = income - expense;
    final series = _monthlySeries(finance, filtered);
    final years = finance.transactions
        .map((t) => t.date.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Relatórios',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          'Análises e estatísticas das suas finanças',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SegmentedButton<_PeriodType>(
                segments: const [
                  ButtonSegment(value: _PeriodType.last6, label: Text('6 meses')),
                  ButtonSegment(value: _PeriodType.year, label: Text('Ano')),
                  ButtonSegment(value: _PeriodType.specific, label: Text('Período')),
                ],
                selected: {_periodType},
                onSelectionChanged: (value) async {
                  setState(() => _periodType = value.first);
                  if (_periodType == _PeriodType.specific && _range == null) {
                    await _pickRange();
                  }
                },
              ),
            ],
          ),
        ),
        if (_periodType == _PeriodType.year) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _year ?? (years.isNotEmpty ? years.first : DateTime.now().year),
            decoration: const InputDecoration(labelText: 'Ano'),
            items: [
              for (final year in (years.isEmpty ? [DateTime.now().year] : years))
                DropdownMenuItem(value: year, child: Text(year.toString())),
            ],
            onChanged: (value) => setState(() => _year = value),
          ),
        ],
        if (_periodType == _PeriodType.specific) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              _range == null
                  ? 'Selecionar período'
                  : '${formatDateOnly(_range!.start.toIso8601String())} - ${formatDateOnly(_range!.end.toIso8601String())}',
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Entradas',
                value: formatCurrency(income),
                icon: Icons.trending_up,
                accent: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'Saídas',
                value: formatCurrency(expense),
                icon: Icons.trending_down,
                accent: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SummaryCard(
          title: 'Saldo do período',
          value: formatCurrency(balance),
          icon: Icons.attach_money,
          accent: balance >= 0 ? const Color(0xFF3B82F6) : const Color(0xFFF97316),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visão Geral Financeira',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (series.isEmpty || series.every((p) => p.income == 0 && p.expense == 0))
                const EmptyState(icon: Icons.bar_chart, message: 'Sem dados no período.')
              else
                _MonthlyBars(points: series),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CategoryBreakdownCard(
          title: 'Saídas por Categoria',
          icon: Icons.pie_chart_outline,
          accent: const Color(0xFFEF4444),
          totals: _categoryTotals(finance, filtered, 'expense'),
          emptyMessage: 'Sem saídas no período',
        ),
        const SizedBox(height: 16),
        CategoryBreakdownCard(
          title: 'Entradas por Categoria',
          icon: Icons.pie_chart_outline,
          accent: const Color(0xFF10B981),
          totals: _categoryTotals(finance, filtered, 'income'),
          emptyMessage: 'Sem entradas no período',
        ),
        const SizedBox(height: 16),
        _InsightsCard(income: income, expense: expense, transactionCount: filtered.length),
      ],
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
                  Text(
                    point.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
        text: 'Você gastou mais do que ganhou no período. Revise suas despesas.',
        color: const Color(0xFFEF4444),
        icon: Icons.warning_amber_outlined,
      ));
    } else if (savingsRate >= 0.2) {
      insights.add((
        text: 'Ótimo! Você poupou ${(savingsRate * 100).toStringAsFixed(0)}% da sua renda.',
        color: const Color(0xFF10B981),
        icon: Icons.check_circle_outline,
      ));
    } else if (income > 0) {
      insights.add((
        text: 'Sua taxa de poupança foi de ${(savingsRate * 100).toStringAsFixed(0)}%. Tente chegar a 20%.',
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
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
