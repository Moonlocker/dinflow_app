import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/goal.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_form_sheet.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) context.read<FinanceProvider>().load(userId);
  }

  bool _isAttention(Goal goal) {
    if (goal.isCompleted) return false;
    final now = DateTime.now();
    if (goal.dueDate != null) {
      final days = goal.dueDate!.difference(now).inDays;
      if (goal.dueDate!.isBefore(now)) return true;
      if (days <= 7) return true;
    }
    if (goal.type == 'category_budget') {
      final threshold = (goal.alertThreshold ?? 90) / 100;
      if (goal.progress >= threshold) return true;
    }
    return false;
  }

  Future<void> _addValue(Goal goal) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adicionar a ${goal.title}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor (R\$)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0 || !mounted) return;
    try {
      await context.read<FinanceProvider>().addToGoal(goal.id, value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor adicionado à meta!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao adicionar o valor.')),
      );
    }
  }

  Future<void> _confirmDelete(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Meta?'),
        content: Text('A meta "${goal.title}" será removida permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<FinanceProvider>().deleteGoal(goal.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meta excluída!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao excluir a meta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = context.watch<FinanceProvider>();

    if (finance.loading && !finance.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final goals = finance.goals;
    final active = goals.where((g) => !g.isCompleted).toList();
    final completed = goals.where((g) => g.isCompleted).toList();
    final attention = goals.where(_isAttention).toList();

    final filtered = switch (_filter) {
      'active' => active,
      'completed' => completed,
      'attention' => attention,
      _ => goals,
    };

    final totalProgress = goals.isEmpty
        ? 0.0
        : goals.fold<double>(0, (acc, g) => acc + g.progress) / goals.length;

    final filters = [
      ('active', 'Ativas', active.length, theme.colorScheme.primary),
      ('completed', 'Concluídas', completed.length, const Color(0xFF10B981)),
      ('attention', 'Atenção', attention.length, const Color(0xFFF97415)),
      ('all', 'Todas', goals.length, theme.colorScheme.onSurfaceVariant),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-goal',
        onPressed: () => showGoalForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova Meta'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Metas Financeiras',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Defina objetivos e acompanhe seu progresso',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progresso Geral das Metas Ativas',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: totalProgress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.outline,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${(totalProgress * 100).toStringAsFixed(1)}% de todas as metas concluído',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in filters) ...[
                  ChoiceChip(
                    label: Text('${filter.$2} (${filter.$3})'),
                    selected: _filter == filter.$1,
                    onSelected: (_) => setState(() => _filter = filter.$1),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.flag,
                message: 'Nenhuma meta encontrada. Tente outro filtro ou crie uma meta.',
              ),
            )
          else
            Column(
              children: [
                for (final goal in filtered) ...[
                  GoalCard(
                    goal: goal,
                    onEdit: () => showGoalForm(context, goal: goal),
                    onDelete: () => _confirmDelete(goal),
                    onAdd: () => _addValue(goal),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
