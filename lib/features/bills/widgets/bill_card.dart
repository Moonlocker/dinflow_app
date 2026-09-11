import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/bill.dart';
import '../../../models/category.dart';

class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.bill,
    required this.category,
    required this.isPaid,
    required this.isOverdue,
    required this.dueLabel,
    required this.dueColor,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final Bill bill;
  final Category? category;
  final bool isPaid;
  final bool isOverdue;
  final String dueLabel;
  final Color dueColor;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color background;
    final Color border;
    if (isPaid) {
      background = const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08);
      border = const Color(0xFF10B981).withValues(alpha: 0.4);
    } else if (isOverdue) {
      background = theme.colorScheme.error.withValues(alpha: isDark ? 0.14 : 0.08);
      border = theme.colorScheme.error.withValues(alpha: 0.4);
    } else {
      background = theme.colorScheme.surface;
      border = theme.colorScheme.outline;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (isPaid)
                const _Badge(label: 'Paga', color: Color(0xFF10B981))
              else
                _Badge(label: dueLabel, color: dueColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vencimento: Dia ${bill.dueDay} do mês',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (bill.amount > 0)
            Text(
              'Valor estimado: ${formatCurrency(bill.amount)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (bill.description != null && bill.description!.trim().isNotEmpty)
            Text(
              bill.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (category != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: category!.parsedColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(category!.name, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (!isPaid)
                OutlinedButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.attach_money, size: 16),
                  label: const Text('Pagar'),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Editar',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Excluir',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
