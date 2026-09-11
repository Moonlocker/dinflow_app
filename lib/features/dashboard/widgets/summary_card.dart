import 'package:flutter/material.dart';

/// Card de indicador financeiro (Receitas, Despesas, Saldo, Metas).
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.footer,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final darker = Color.lerp(accent, Colors.black, 0.25)!;

    return Material(
      color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, darker],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 4),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rótulo de comparação com o mês anterior (seta + percentual).
class ComparisonLabel extends StatelessWidget {
  const ComparisonLabel({super.key, required this.comparison});

  final double comparison;

  @override
  Widget build(BuildContext context) {
    if (comparison == 0 || !comparison.isFinite) {
      return const SizedBox(height: 16);
    }
    final isPositive = comparison > 0;
    final color = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return SizedBox(
      height: 16,
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              '${comparison.abs().toStringAsFixed(1)}% vs mês anterior',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
