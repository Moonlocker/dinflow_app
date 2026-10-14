import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Seletor de mês rolável: `‹ [jan] [fev] [ Março ] [abr] [mai] ›`.
///
/// Permite arrastar horizontalmente para percorrer os meses e tocar em
/// qualquer mês visível para selecioná-lo, sem depender apenas das setas.
/// Compartilhado entre o Dashboard e a tela de Relatórios.
class MonthSelector extends StatefulWidget {
  const MonthSelector({
    super.key,
    required this.date,
    required this.onPrevious,
    required this.onNext,
    this.onSelect,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Seleciona diretamente o mês tocado na faixa rolável.
  final ValueChanged<DateTime>? onSelect;

  @override
  State<MonthSelector> createState() => _MonthSelectorState();
}

class _MonthSelectorState extends State<MonthSelector> {
  static const int _baseYear = 2000;
  static const int _endYear = 2100;
  static const double _itemExtent = 104;
  static final int _itemCount = (_endYear - _baseYear + 1) * 12;

  final ScrollController _controller = ScrollController();
  double _viewportWidth = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexFor(DateTime date) => (date.year - _baseYear) * 12 + (date.month - 1);

  DateTime _dateFor(int index) {
    final year = _baseYear + index ~/ 12;
    final month = index % 12 + 1;
    return DateTime(year, month, 1);
  }

  double _offsetForIndex(int index) =>
      index * _itemExtent - (_viewportWidth - _itemExtent) / 2;

  void _centerOnSelected({bool animate = false}) {
    if (!_controller.hasClients || _viewportWidth <= 0) return;
    final position = _controller.position;
    final target = _offsetForIndex(_indexFor(widget.date)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animate) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(covariant MonthSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date.year != widget.date.year ||
        oldWidget.date.month != widget.date.month) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnSelected(animate: true);
      });
    }
  }

  void _select(DateTime month) {
    final onSelect = widget.onSelect;
    if (onSelect != null) {
      onSelect(month);
      return;
    }
    // Sem callback direto: aproxima usando as setas.
    var current = widget.date;
    while (current.year != month.year || current.month != month.month) {
      if (month.isBefore(current)) {
        widget.onPrevious();
        current = DateTime(current.year, current.month - 1, 1);
      } else {
        widget.onNext();
        current = DateTime(current.year, current.month + 1, 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrowColor = theme.brightness == Brightness.dark
        ? AppColors.mint
        : theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.onPrevious,
            icon: Icon(Icons.chevron_left, size: 22, color: arrowColor),
            tooltip: 'Mês anterior',
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth != _viewportWidth) {
                  _viewportWidth = constraints.maxWidth;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _centerOnSelected();
                  });
                }
                return SizedBox(
                  height: 46,
                  child: ListView.builder(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    itemExtent: _itemExtent,
                    itemCount: _itemCount,
                    itemBuilder: (context, index) {
                      final month = _dateFor(index);
                      final selected =
                          month.year == widget.date.year &&
                          month.month == widget.date.month;
                      return _MonthChip(
                        label: formatMonth(month),
                        year: month.year,
                        selected: selected,
                        onTap: () => _select(month),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.onNext,
            icon: Icon(Icons.chevron_right, size: 22, color: arrowColor),
            tooltip: 'Próximo mês',
          ),
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.year,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int year;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: selected
            ? Material(
                color: isDark ? AppColors.mint : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isDark
                                ? AppColors.onMint
                                : theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$year',
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: (isDark
                                    ? AppColors.onMint
                                    : theme.colorScheme.onPrimary)
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '$year',
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
