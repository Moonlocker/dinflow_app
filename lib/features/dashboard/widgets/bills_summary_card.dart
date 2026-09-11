import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/bill.dart';
import '../../../widgets/app_card.dart';

/// Resumo das contas fixas do mês no dashboard.
class BillsSummaryCard extends StatelessWidget {
  const BillsSummaryCard({
    super.key,
    required this.bills,
    required this.isPaid,
    required this.onViewAll,
  });

  final List<Bill> bills;
  final bool Function(String billId) isPaid;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = bills.fold<double>(0, (sum, bill) => sum + bill.amount);
    final paidCount = bills.where((bill) => isPaid(bill.id)).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Contas do mês',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewAll,
                child: const Text('Ver Todas'),
              ),
            ],
          ),
          if (bills.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma conta cadastrada.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _metric(
                    theme,
                    'Total estimado',
                    formatCurrency(total),
                    theme.colorScheme.onSurface,
                  ),
                ),
                Expanded(
                  child: _metric(
                    theme,
                    'Pagas',
                    '$paidCount/${bills.length}',
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final bill in bills.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      isPaid(bill.id)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: isPaid(bill.id)
                          ? const Color(0xFF10B981)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      'Dia ${bill.dueDay} • ${formatCurrency(bill.amount)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

  Widget _metric(ThemeData theme, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
