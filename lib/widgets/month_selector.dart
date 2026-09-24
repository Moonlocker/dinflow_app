import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Seletor de mês no estilo das referências:
/// `‹ Março [ Abril ] Maio ›` — mês atual em cápsula verde-menta.
///
/// Compartilhado entre o Dashboard e a tela de Relatórios para manter a
/// identidade visual consistente.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previous = DateTime(date.year, date.month - 1, 1);
    final next = DateTime(date.year, date.month + 1, 1);
    final arrowColor = theme.brightness == Brightness.dark
        ? AppColors.mint
        : theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPrevious,
            icon: Icon(Icons.chevron_left, size: 22, color: arrowColor),
            tooltip: 'Mês anterior',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _SideLabel(text: formatMonth(previous))),
                const SizedBox(width: 8),
                _SelectedMonth(text: formatMonth(date)),
                const SizedBox(width: 8),
                Flexible(child: _SideLabel(text: formatMonth(next))),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onNext,
            icon: Icon(Icons.chevron_right, size: 22, color: arrowColor),
            tooltip: 'Próximo mês',
          ),
        ],
      ),
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _SelectedMonth extends StatelessWidget {
  const _SelectedMonth({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.brightness == Brightness.dark
        ? AppColors.mint
        : theme.colorScheme.primary;
    final label = theme.brightness == Brightness.dark
        ? AppColors.onMint
        : theme.colorScheme.onPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: label,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: label),
        ],
      ),
    );
  }
}