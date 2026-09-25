import 'package:flutter/material.dart';

import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/bill.dart';
import '../../../models/category.dart';

enum _BillAction { pay, unpay, edit, delete }

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
    required this.onUnpay,
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
  final VoidCallback onUnpay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color background;
    final Color border;
    if (isPaid) {
      background = const Color(0xFF10B981)
          .withValues(alpha: isDark ? 0.12 : 0.08);
      border = const Color(0xFF10B981).withValues(alpha: 0.4);
    } else if (isOverdue) {
      background = theme.colorScheme.error.withValues(
        alpha: isDark ? 0.14 : 0.08,
      );
      border = theme.colorScheme.error.withValues(alpha: 0.4);
    } else {
      background = theme.colorScheme.surface;
      border = theme.colorScheme.outline;
    }

    final categoryColor = category?.parsedColor ?? theme.colorScheme.outline;

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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  category == null
                      ? Icons.receipt_long_outlined
                      : categoryIconFor(category!.icon),
                  size: 19,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vence dia ${bill.dueDay} do mês',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isPaid)
                const _Badge(label: 'Paga', color: Color(0xFF10B981))
              else
                _Badge(label: dueLabel, color: dueColor),
              PopupMenuButton<_BillAction>(
                tooltip: 'Ações',
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _BillAction.pay:
                      onPay();
                      break;
                    case _BillAction.unpay:
                      onUnpay();
                      break;
                    case _BillAction.edit:
                      onEdit();
                      break;
                    case _BillAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (!isPaid)
                    const PopupMenuItem(
                      value: _BillAction.pay,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF10B981),
                        ),
                        title: Text('Marcar como paga'),
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: _BillAction.unpay,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.undo, color: Colors.blueGrey),
                        title: Text('Desfazer pagamento'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: _BillAction.edit,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _BillAction.delete,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                      ),
                      title: Text('Excluir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Valor estimado',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatCurrency(bill.amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (bill.description != null &&
              bill.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              bill.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!isPaid)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onPay,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Pagar'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onUnpay,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Desmarcar pagamento'),
              ),
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
