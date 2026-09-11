import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import '../../widgets/brand_logo.dart';
import '../auth/providers/auth_provider.dart';
import '../bills/pages/bills_page.dart';
import '../dashboard/pages/dashboard_page.dart';
import '../education/pages/education_page.dart';
import '../goals/pages/goals_page.dart';
import '../reports/pages/reports_page.dart';
import '../settings/pages/settings_page.dart';
import '../transactions/pages/transactions_page.dart';
import 'widgets/dinflow_bottom_nav.dart';

/// Estrutura principal do app autenticado: cabeçalho, conteúdo e barra inferior.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const List<DinFlowNavItem> _navItems = [
    DinFlowNavItem(label: 'Início', icon: Icons.home_outlined, activeIcon: Icons.home),
    DinFlowNavItem(label: 'Transações', icon: Icons.credit_card_outlined, activeIcon: Icons.credit_card),
    DinFlowNavItem(label: 'Relatórios', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart),
    DinFlowNavItem(label: 'Metas', icon: Icons.flag_outlined, activeIcon: Icons.flag),
    DinFlowNavItem(label: 'Educação', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book),
    DinFlowNavItem(label: 'Contas', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long),
    DinFlowNavItem(label: 'Ajustes', icon: Icons.settings_outlined, activeIcon: Icons.settings),
  ];

  List<Widget> _buildPages() {
    return [
      DashboardPage(
        onOpenTab: (index) => setState(() => _currentIndex = index),
      ),
      const TransactionsPage(),
      const ReportsPage(),
      const GoalsPage(),
      const EducationPage(),
      const BillsPage(),
      const SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildHeader(context),
      body: IndexedStack(index: _currentIndex, children: _buildPages()),
      bottomNavigationBar: DinFlowBottomNav(
        items: _navItems,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: Row(
              children: [
                const BrandLogo(height: 34),
                const Spacer(),
                IconButton(
                  tooltip: 'Notificações',
                  onPressed: () => _showComingSoon(context, 'Notificações'),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                IconButton(
                  tooltip: 'Alternar tema',
                  onPressed: () => context.read<ThemeController>().toggle(),
                  icon: Icon(
                    theme.brightness == Brightness.light
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                ),
                _AccountMenu(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature estará disponível em breve.')),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final rawName = (profile?.displayName ?? auth.user?.email ?? 'U').trim();
    final initial = rawName.isEmpty ? 'U' : rawName[0].toUpperCase();

    return PopupMenuButton<String>(
      tooltip: 'Conta',
      onSelected: (value) {
        if (value == 'logout') {
          context.read<AuthProvider>().logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.displayName ?? 'Usuário',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                auth.user?.email ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: 8),
              Text('Sair'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary,
          backgroundImage: (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty)
              ? Text(
                  initial,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
