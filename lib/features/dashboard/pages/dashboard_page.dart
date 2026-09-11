import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../goals/widgets/goal_form_sheet.dart';
import '../../transactions/widgets/transaction_form_sheet.dart';
import '../widgets/active_goals_card.dart';
import '../widgets/category_breakdown_card.dart';
import '../widgets/month_navigator.dart';
import '../widgets/quick_actions_card.dart';
import '../widgets/recent_transactions_card.dart';
import '../widgets/summary_card.dart';

/// Dashboard do DinFlow — primeira tela funcional do aplicativo.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onOpenTab});

  /// Permite abrir outra aba da navegação inferior (Transações, Metas, etc.).
  final ValueChanged<int>? onOpenTab;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      context.read<FinanceProvider>().load(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<FinanceProvider>();

    if (dashboard.loading && !dashboard.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final greetingName = auth.profile?.firstName ??
        (auth.user?.email?.split('@').first ?? '');

    final incomeComparison =
        dashboard.comparison(dashboard.monthlyIncome, dashboard.previousMonthIncome);
    final expenseComparison = -dashboard.comparison(
      dashboard.monthlyExpenses,
      dashboard.previousMonthExpenses,
    );
    final balanceComparison = dashboard.comparison(
      dashboard.monthlyBalance,
      dashboard.previousMonthBalance,
    );

    return RefreshIndicator(
      onRefresh: dashboard.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Olá, $greetingName!',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Aqui está o resumo das suas finanças.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          MonthNavigator(
            date: dashboard.currentDate,
            onPrevious: dashboard.previousMonth,
            onNext: dashboard.nextMonth,
          ),
          const SizedBox(height: 16),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 128,
            ),
            children: [
              SummaryCard(
                title: 'Receitas',
                value: _currency(dashboard.monthlyIncome),
                icon: Icons.trending_up,
                accent: const Color(0xFF10B981),
                footer: ComparisonLabel(comparison: incomeComparison),
              ),
              SummaryCard(
                title: 'Despesas',
                value: _currency(dashboard.monthlyExpenses),
                icon: Icons.trending_down,
                accent: const Color(0xFFEF4444),
                footer: ComparisonLabel(comparison: expenseComparison),
              ),
              SummaryCard(
                title: 'Saldo',
                value: _currency(dashboard.monthlyBalance),
                icon: Icons.attach_money,
                accent: dashboard.monthlyBalance >= 0
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFF97316),
                footer: ComparisonLabel(comparison: balanceComparison),
              ),
              SummaryCard(
                title: 'Metas',
                value: '${dashboard.completedGoalsCount}/${dashboard.totalGoals}',
                icon: Icons.check_circle_outline,
                accent: const Color(0xFF8B5CF6),
                footer: Text(
                  dashboard.totalGoals > 0
                      ? '${(dashboard.goalsCompletionRate * 100).round()}% concluídas'
                      : 'Nenhuma meta',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RecentTransactionsCard(
            transactions: dashboard.recentTransactions,
            onViewAll: () => widget.onOpenTab?.call(1),
          ),
          const SizedBox(height: 16),
          ActiveGoalsCard(
            goals: dashboard.activeGoals,
            onViewAll: () => widget.onOpenTab?.call(3),
          ),
          const SizedBox(height: 16),
          QuickActionsCard(
            actions: [
              QuickAction(
                label: 'Nova Transação',
                icon: Icons.add,
                onTap: () => showTransactionForm(context),
              ),
              QuickAction(
                label: 'Nova Meta',
                icon: Icons.flag_outlined,
                onTap: () => showGoalForm(context),
              ),
              QuickAction(
                label: 'Relatórios',
                icon: Icons.bar_chart,
                onTap: () => widget.onOpenTab?.call(2),
              ),
              QuickAction(
                label: 'Chat IA',
                icon: Icons.smart_toy_outlined,
                onTap: () => _showComingSoon('Chat IA'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CategoryBreakdownCard(
            title: 'Saídas por Categoria',
            icon: Icons.pie_chart_outline,
            accent: const Color(0xFFEF4444),
            totals: dashboard.expenseCategories,
            emptyMessage: 'Sem saídas neste mês',
          ),
          const SizedBox(height: 16),
          CategoryBreakdownCard(
            title: 'Entradas por Categoria',
            icon: Icons.pie_chart_outline,
            accent: const Color(0xFF10B981),
            totals: dashboard.incomeCategories,
            emptyMessage: 'Sem entradas neste mês',
          ),
        ],
      ),
    );
  }

  String _currency(double value) => formatCurrency(value);

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature estará disponível em breve no aplicativo.')),
    );
  }
}
