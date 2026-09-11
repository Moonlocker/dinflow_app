import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/goal.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';

/// Card "Metas Ativas" do dashboard.
class ActiveGoalsCard extends StatelessWidget {
  const ActiveGoalsCard({super.key, required this.goals, this.onViewAll});

  final List<Goal> goals;
  final VoidCallback? onViewAll;

  static const Color _purple = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: goals.isEmpty
                ? const EmptyState(
                    icon: Icons.flag,
                    message: 'Nenhuma meta ativa no momento.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < goals.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _GoalTile(goal: goals[i]),
                      ],
                    ],
                  ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton(
              onPressed: onViewAll,
              child: const Text('Ver Todas'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ActiveGoalsCard._purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.flag, size: 20, color: ActiveGoalsCard._purple),
          ),
          const SizedBox(width: 10),
          Text(
            'Metas Ativas',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (goal.isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Vencida',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outline,
              valueColor: const AlwaysStoppedAnimation<Color>(ActiveGoalsCard._purple),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                formatCurrency(goal.currentAmount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${(goal.progress * 100).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ActiveGoalsCard._purple,
                ),
              ),
              const Spacer(),
              Text(
                formatCurrency(goal.targetAmount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
