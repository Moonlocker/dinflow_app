import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../widgets/brand_logo.dart';
import '../../auth/providers/auth_provider.dart';
import 'sections/admin_affiliates_section.dart';
import 'sections/admin_analytics_section.dart';
import 'sections/admin_communication_section.dart';
import 'sections/admin_dashboard_section.dart';
import 'sections/admin_education_section.dart';
import 'sections/admin_payments_section.dart';
import 'sections/admin_plans_section.dart';
import 'sections/admin_settings_section.dart';
import 'sections/admin_users_section.dart';
import 'sections/admin_webhooks_section.dart';
import 'sections/admin_whatsapp_section.dart';

class _AdminSection {
  const _AdminSection(this.title, this.icon, this.builder);

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Painel de administração (superadmin) do aplicativo.
class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  int _index = 0;

  static final List<_AdminSection> _sections = [
    _AdminSection('Visão Geral', Icons.dashboard_outlined,
        (_) => const AdminDashboardSection()),
    _AdminSection('Usuários', Icons.people_outline,
        (_) => const AdminUsersSection()),
    _AdminSection('Planos', Icons.credit_card_outlined,
        (_) => const AdminPlansSection()),
    _AdminSection('Pagamentos', Icons.attach_money,
        (_) => const AdminPaymentsSection()),
    _AdminSection('E-mail & Notificação', Icons.mail_outline,
        (_) => const AdminCommunicationSection()),
    _AdminSection('Webhooks', Icons.webhook_outlined,
        (_) => const AdminWebhooksSection()),
    _AdminSection('WhatsApp', Icons.chat_outlined,
        (_) => const AdminWhatsAppSection()),
    _AdminSection('Afiliados', Icons.card_giftcard_outlined,
        (_) => const AdminAffiliatesSection()),
    _AdminSection('Analytics', Icons.bar_chart_outlined,
        (_) => const AdminAnalyticsSection()),
    _AdminSection('Educação', Icons.menu_book_outlined,
        (_) => const AdminEducationSection()),
    _AdminSection('Configurações', Icons.settings_outlined,
        (_) => const AdminSettingsSection()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_sections[_index].title),
        actions: [
          IconButton(
            tooltip: 'Sair do painel',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const BrandLogo(height: 32),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  auth.profile?.displayName ?? auth.user?.email ?? 'Administrador',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: _sections.length,
                  itemBuilder: (context, index) {
                    final section = _sections[index];
                    final selected = index == _index;
                    return ListTile(
                      selected: selected,
                      leading: Icon(section.icon),
                      title: Text(section.title),
                      onTap: () {
                        setState(() => _index = index);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair da conta'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await context.read<AuthProvider>().logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [for (final section in _sections) section.builder(context)],
      ),
    );
  }
}
