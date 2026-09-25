import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transaction.dart';
import '../../../widgets/capsule_selector.dart';
import '../../../widgets/month_selector.dart';
import '../../auth/providers/auth_provider.dart';
import '../../authors/providers/author_provider.dart';
import '../../bills/providers/bills_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../widgets/recent_transactions_card.dart';

/// Dashboard do DinFlow — tela principal no estilo dos designs de referência:
/// saldo acumulado, seletor de mês, resumo do mês e categorias em carrossel.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onOpenPage});

  /// Permite abrir outra página da navegação (Transações, Metas, etc.).
  final ValueChanged<String>? onOpenPage;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _palette = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];

  int _categoryTab = 0;
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      context.read<FinanceProvider>().load(userId);
      context.read<BillsProvider>().load(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dashboard = context.watch<FinanceProvider>();

    if (dashboard.loading && !dashboard.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final incomeComparison = dashboard.comparison(
      dashboard.monthlyIncome,
      dashboard.previousMonthIncome,
    );
    final expenseComparison = dashboard.comparison(
      dashboard.monthlyExpenses,
      dashboard.previousMonthExpenses,
    );
    final balanceComparison = dashboard.comparison(
      dashboard.monthlyBalance,
      dashboard.previousMonthBalance,
    );

    return RefreshIndicator(
      onRefresh: dashboard.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _BalanceSummary(
            value: dashboard.accumulatedBalance,
            hidden: _hideBalance,
            onToggleHidden: () => setState(() => _hideBalance = !_hideBalance),
          ),
          const SizedBox(height: 16),
          MonthSelector(
            date: dashboard.currentDate,
            onPrevious: dashboard.previousMonth,
            onNext: dashboard.nextMonth,
          ),
          if (context.watch<AuthorProvider>().hasMultiple) ...[
            const SizedBox(height: 12),
            _AuthorFilter(
              authors: context.watch<AuthorProvider>(),
              current: dashboard.authorFilter,
              onChanged: dashboard.setAuthorFilter,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Resumo do mês',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _MonthSummaryCard(
            balance: dashboard.monthlyBalance,
            comparison: balanceComparison,
            income: dashboard.monthlyIncome,
            incomeComparison: incomeComparison,
            expenses: dashboard.monthlyExpenses,
            expenseComparison: expenseComparison,
            currentMonth: dashboard.currentDate,
            hidden: _hideBalance,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: CapsuleSelector(
                    options: const ['Despesas', 'Receitas'],
                    selectedIndex: _categoryTab,
                    onChanged: (index) => setState(() => _categoryTab = index),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: isDark
                      ? AppColors.mint
                      : theme.colorScheme.primary,
                ),
                onPressed: () => widget.onOpenPage?.call('transactions'),
                child: const Text('Detalhes'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CategoryCarousel(
            totals: _categoryTab == 0
                ? dashboard.expenseCategories
                : dashboard.incomeCategories,
            isIncome: _categoryTab == 1,
            palette: _palette,
            hidden: _hideBalance,
          ),
          const SizedBox(height: 18),
          RecentTransactionsCard(
            transactions: dashboard.recentTransactions,
            onViewAll: () => widget.onOpenPage?.call('transactions'),
          ),
        ],
      ),
    );
  }
}

/// Bloco de "Saldo acumulado" com valor em destaque e indicador de variação.
class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({
    required this.value,
    required this.hidden,
    required this.onToggleHidden,
  });

  final double value;
  final bool hidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Seu saldo acumulado',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hidden ? r'R$ ••••••' : formatCurrency(value),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 34,
                  ),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onToggleHidden,
              icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Chip de tendência (ex.: "+12% ref. Último mês") com fundo translúcido.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.text, required this.color, this.dense = false});

  final String text;
  final Color color;

  /// Versão reduzida, usada quando o chip precisa ficar mais discreto.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dense ? 0.12 : 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: dense ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Card "Resumo do mês": saldo do mês, receitas e despesas.
class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.balance,
    required this.comparison,
    required this.income,
    required this.incomeComparison,
    required this.expenses,
    required this.expenseComparison,
    required this.currentMonth,
    required this.hidden,
  });

  final double balance;
  final double comparison;
  final double income;
  final double incomeComparison;
  final double expenses;
  final double expenseComparison;
  final DateTime currentMonth;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final previousMonth = DateTime(
      currentMonth.year,
      currentMonth.month - 1,
      1,
    );
    final balanceTrend = comparison != 0 && comparison.isFinite
        ? _TrendChip(
            dense: true,
            text:
                '${comparison >= 0 ? '↑' : '↓'} ${comparison.abs().toStringAsFixed(0)}% ref. a ${formatMonth(previousMonth).toLowerCase()}',
            color: comparison >= 0
                ? (isDark ? AppColors.mint : const Color(0xFF10B981))
                : const Color(0xFFEF4444),
          )
        : null;

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Seu saldo em ${formatMonth(currentMonth)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (balanceTrend != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: balanceTrend,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hidden ? r'R$ ••••••' : formatCurrency(balance),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          _CategoryLine(
            icon: Icons.trending_up,
            label: 'Receitas',
            color: const Color(0xFF10B981),
            comparison: incomeComparison,
            value: formatCurrency(income),
          ),
          const SizedBox(height: 10),
          _CategoryLine(
            icon: Icons.trending_down,
            label: 'Despesas',
            color: const Color(0xFFEF4444),
            comparison: expenseComparison,
            value: formatCurrency(expenses),
          ),
        ],
      ),
    );
  }
}

/// Linha de receita/despesa com ícone, badge de variação e valor.
class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.icon,
    required this.label,
    required this.color,
    required this.comparison,
    required this.value,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double comparison;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasComparison = comparison != 0 && comparison.isFinite;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasComparison)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${comparison >= 0 ? '+' : ''}${comparison.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: child,
    );
  }
}

/// Carrossel horizontal de cards por categoria com anel de progresso.
class _CategoryCarousel extends StatelessWidget {
  const _CategoryCarousel({
    required this.totals,
    required this.isIncome,
    required this.palette,
    required this.hidden,
  });

  final List<CategoryTotal> totals;
  final bool isIncome;
  final List<Color> palette;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (totals.isEmpty) {
      return _DarkCard(
        child: Text(
          isIncome ? 'Sem receitas neste mês.' : 'Sem despesas neste mês.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final total = totals.fold<double>(0, (sum, item) => sum + item.total);

    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totals.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = totals[index];
          final color = item.category.parsedColor != Colors.grey
              ? item.category.parsedColor
              : palette[index % palette.length];
          final percent = total <= 0 ? 0.0 : item.total / total;
          final sign = isIncome ? '+' : '-';
          final accent = isIncome
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444);

          return _CategoryRingCard(
            name: item.category.name,
            icon: categoryIconFor(item.category.icon),
            percent: percent,
            color: color,
            sign: sign,
            value: formatCurrency(item.total),
            valueColor: accent,
            hidden: hidden,
            onTap: () => _showCategoryDetail(context, item, color),
          );
        },
      ),
    );
  }

  void _showCategoryDetail(
    BuildContext context,
    CategoryTotal item,
    Color color,
  ) {
    final transactions = context.read<FinanceProvider>().categoryTransactions(
      item.category.id,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CategoryTransactionsSheet(
        name: item.category.name,
        icon: categoryIconFor(item.category.icon),
        color: color,
        isIncome: isIncome,
        total: item.total,
        transactions: transactions,
      ),
    );
  }
}

/// Card individual da categoria com ring de progresso no centro.
class _CategoryRingCard extends StatelessWidget {
  const _CategoryRingCard({
    required this.name,
    required this.icon,
    required this.percent,
    required this.color,
    required this.sign,
    required this.value,
    required this.valueColor,
    required this.hidden,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final double percent;
  final Color color;
  final String sign;
  final String value;
  final Color valueColor;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 118,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CustomPaint(
                          painter: _RingPainter(
                            value: percent,
                            color: color,
                            trackColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      Text(
                        (percent * 100).round().toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    hidden
                        ? '••••••'
                        : '$sign ${value.replaceFirst(r'R$', '')}'.trim(),
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal com os lançamentos que compõem o total de uma categoria.
class _CategoryTransactionsSheet extends StatelessWidget {
  const _CategoryTransactionsSheet({
    required this.name,
    required this.icon,
    required this.color,
    required this.isIncome,
    required this.total,
    required this.transactions,
  });

  final String name;
  final IconData icon;
  final Color color;
  final bool isIncome;
  final double total;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    // `useSafeArea` do modal só evita o topo; garante o recuo dos botões de
    // navegação/gestos do sistema no rodapé.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${transactions.length} ${transactions.length == 1 ? 'lançamento' : 'lançamentos'} no mês',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${isIncome ? '+' : '-'} ${formatCurrency(total)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outline),
        if (transactions.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
            child: Text(
              'Nenhum lançamento neste período.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
              itemCount: transactions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.description ?? 'Sem descrição',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatDateOnly(transaction.date.toIso8601String()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${isIncome ? '+' : '-'} ${formatCurrency(transaction.amount)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Desenha um anel de progresso com pontas arredondadas.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 3.14159 * 2, false, track);

    final sweep = value.clamp(0.0, 1.0) * 3.14159 * 2;
    if (sweep <= 0) return;

    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -3.14159 / 2, sweep, false, progress);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

class _AuthorFilter extends StatelessWidget {
  const _AuthorFilter({
    required this.authors,
    required this.current,
    required this.onChanged,
  });

  final AuthorProvider authors;
  final String? current;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: current,
      decoration: const InputDecoration(
        labelText: 'Autor',
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        for (final author in authors.authors)
          DropdownMenuItem(
            value: author.whatsapp,
            child: Text(
              author.isMain ? '${author.name} (principal)' : author.name,
            ),
          ),
      ],
      onChanged: (value) {
        onChanged(value);
        if (value == null) {
          authors.select(null);
        } else {
          for (final author in authors.authors) {
            if (author.whatsapp == value) {
              authors.select(author);
              break;
            }
          }
        }
      },
    );
  }
}
