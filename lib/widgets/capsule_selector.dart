import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Seletor em cápsula (ex.: `Despesas | Receitas`) no estilo das referências:
/// trilho escuro, segmento selecionado em verde-menta com texto escuro.
class CapsuleSelector extends StatelessWidget {
  const CapsuleSelector({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final track = isDark
        ? const Color(0xFF202226)
        : theme.colorScheme.surfaceContainerHighest;
    final selectedFill =
        isDark ? AppColors.mint : theme.colorScheme.primary;
    final selectedLabel =
        isDark ? AppColors.onMint : theme.colorScheme.onPrimary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? selectedFill : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: i == selectedIndex
                          ? selectedLabel
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}