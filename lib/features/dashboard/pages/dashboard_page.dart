import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../authors/providers/author_provider.dart';
import '../../bills/providers/bills_provider.dart';
import '../../chat/pages/chat_page.dart';
import '../../finance/providers/finance_provider.dart';
import '../../goals/widgets/goal_form_sheet.dart';
import '../../impersonation/providers/impersonation_provider.dart';
import '../../transactions/widgets/transaction_form_sheet.dart';
import '../widgets/active_goals_card.dart';
import '../widgets/bills_summary_card.dart';
import '../widgets/category_breakdown_card.dart';
import '../widgets/month_navigator.dart';
import '../widgets/quick_actions_card.dart';
import '../widgets/recent_transactions_card.dart';
import '../widgets/summary_card.dart';

/// Dashboard do DinFlow — primeira tela funcional do aplicativo.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onOpenPage});

  /// Permite abrir outra página da navegação (Transações, Metas, etc.).
  final ValueChanged<String>? onOpenPage;

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
      context.read<BillsProvider>().load(userId);
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

    final greetingName = context.watch<ImpersonationProvider>().impersonatedProfile?.firstName ??
        auth.profile?.firstName ??
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
          if (context.watch<AuthorProvider>().hasMultiple) ...[
            const SizedBox(height: 12),
            _AuthorFilter(
              authors: context.watch<AuthorProvider>(),
              current: dashboard.authorFilter,
              onChanged: dashboard.setAuthorFilter,
            ),
          ],
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
            onViewAll: () => widget.onOpenPage?.call('transactions'),
          ),
          const SizedBox(height: 16),
          ActiveGoalsCard(
            goals: dashboard.activeGoals,
            onViewAll: () => widget.onOpenPage?.call('goals'),
          ),
          const SizedBox(height: 16),
          BillsSummaryCard(
            bills: context.watch<BillsProvider>().bills,
            isPaid: context.read<BillsProvider>().isPaid,
            onViewAll: () => widget.onOpenPage?.call('bills'),
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
                onTap: () => widget.onOpenPage?.call('reports'),
              ),
              QuickAction(
                label: 'Chat IA',
                icon: Icons.smart_toy_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatPage()),
                ),
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
}

class _AuthorFilter extends StatelessWidget {
  const _AuthorFilter({
    required this.authors,
    required this.current,
    required this.onChanged,
  });

  final AuthorProvider authors;
  final String? current;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: current,
      decoration: const InputDecoration(
        labelText: 'Autor',
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        for (final author in authors.authors)
          DropdownMenuItem(
            value: author.whatsapp,
            child: Text(
              author.isMain ? '${author.name} (principal)' : author.name,
            ),
          ),
      ],
      onChanged: (value) {
        onChanged(value);
        if (value == null) {
          authors.select(null);
        } else {
          for (final author in authors.authors) {
            if (author.whatsapp == value) {
              authors.select(author);
              break;
            }
          }
        }
      },
    );
  }
}
