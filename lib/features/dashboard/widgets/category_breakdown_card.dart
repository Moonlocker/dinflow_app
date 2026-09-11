import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../finance/providers/finance_provider.dart';

/// Card de distribuição por categoria.
///
/// O webapp usa gráficos de pizza (recharts). Aqui a mesma informação é
/// apresentada como barras proporcionais, sem dependências extras.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.totals,
    required this.emptyMessage,
    this.fallbackColors = const [
      Color(0xFFEF4444),
      Color(0xFFF97316),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFF84CC16),
      Color(0xFF22C55E),
    ],
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<CategoryTotal> totals;
  final String emptyMessage;
  final List<Color> fallbackColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxTotal = totals.isEmpty
        ? 0.0
        : totals.map((item) => item.total).reduce((a, b) => a > b ? a : b);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: totals.isEmpty
                ? EmptyState(icon: icon, message: emptyMessage, iconColor: accent)
                : Column(
                    children: [
                      for (var i = 0; i < totals.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        _CategoryRow(
                          total: totals[i],
                          maxTotal: maxTotal,
                          fallbackColor: fallbackColors[i % fallbackColors.length],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.total,
    required this.maxTotal,
    required this.fallbackColor,
  });

  final CategoryTotal total;
  final double maxTotal;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = total.category.color != null ? total.category.parsedColor : fallbackColor;
    final ratio = maxTotal <= 0 ? 0.0 : total.total / maxTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                total.category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              formatCurrency(total.total),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: theme.colorScheme.outline,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
