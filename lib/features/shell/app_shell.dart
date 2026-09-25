import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/app_pages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../auth/providers/auth_provider.dart';
import '../authors/providers/author_provider.dart';
import '../bills/pages/bills_page.dart';
import '../bills/providers/bills_provider.dart';
import '../chat/pages/chat_page.dart';
import '../dashboard/pages/dashboard_page.dart';
import '../education/pages/education_page.dart';
import '../education/providers/education_provider.dart';
import '../finance/providers/finance_provider.dart';
import '../goals/pages/goals_page.dart';
import '../impersonation/providers/impersonation_provider.dart';
import '../notifications/pages/notifications_page.dart';
import '../notifications/providers/notifications_provider.dart';
import '../page_visibility/providers/page_visibility_provider.dart';
import '../reports/pages/reports_page.dart';
import '../settings/pages/settings_page.dart';
import '../superadmin/pages/superadmin_page.dart';
import '../transactions/pages/transactions_page.dart';
import 'widgets/dinflow_bottom_nav.dart';

/// Estrutura principal do app autenticado: cabeçalho, conteúdo e barra inferior.
///
/// A lista de destinos é montada a partir de [PageVisibilityProvider], que
/// reflete a configuração feita pelo superadmin no webapp (páginas ocultas
/// não aparecem e a ordem é respeitada). Também trata a impersonation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _currentKey = 'dashboard';
  ImpersonationProvider? _impersonation;
  String? _loadedUserId;
  bool _autoOpenedAdmin = false;

  @override
  void initState() {
    super.initState();
    _impersonation = context.read<ImpersonationProvider>();
    _impersonation!.addListener(_onImpersonationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PageVisibilityProvider>().load();
      _loadCurrentUser(force: false);
      _maybeOpenAdminPanel();
    });
  }

  /// Abre automaticamente o painel admin (como o webapp faz no `/superadmin`)
  /// quando o usuário logado é superadmin e não há impersonation em curso.
  void _maybeOpenAdminPanel() {
    if (_autoOpenedAdmin) return;
    if (_impersonation?.isImpersonating ?? false) return;
    final auth = context.read<AuthProvider>();
    final isSuperadmin = auth.profile?.isSuperadmin ?? false;
    if (!isSuperadmin) return;
    _autoOpenedAdmin = true;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SuperAdminPage()));
  }

  @override
  void dispose() {
    _impersonation?.removeListener(_onImpersonationChanged);
    super.dispose();
  }

  void _onImpersonationChanged() {
    if (!mounted) return;
    final target =
        context.read<ImpersonationProvider>().impersonatedUserId ??
        context.read<AuthProvider>().user?.id;
    if (target == _loadedUserId) {
      // Apenas os dados do perfil mudaram (ex.: nome/avatar); não recarrega tudo.
      setState(() {});
      return;
    }
    _loadCurrentUser(force: true);
  }

  /// Carrega os dados do usuário ativo (real ou impersonado).
  void _loadCurrentUser({required bool force}) {
    final auth = context.read<AuthProvider>();
    final impersonation = context.read<ImpersonationProvider>();
    final profile = impersonation.impersonatedProfile ?? auth.profile;
    final userId = profile?.id ?? auth.user?.id;
    if (userId == null) return;
    _loadedUserId = userId;

    context.read<FinanceProvider>().load(userId, force: force);
    context.read<FinanceProvider>().setAuthorFilter(null);
    context.read<BillsProvider>().load(userId, force: force);
    context.read<NotificationsProvider>().load(userId, force: force);
    context.read<EducationProvider>().load(force: force);
    context.read<AuthorProvider>().load(
      userId: userId,
      mainWhatsapp: profile?.whatsapp,
      mainName: profile?.name,
    );
  }

  void _openPage(String key) {
    final keys = context.read<PageVisibilityProvider>().orderedMobileKeys();
    if (keys.contains(key)) {
      setState(() => _currentKey = key);
    }
  }

  List<String> _resolvedKeys(PageVisibilityProvider visibility) {
    final keys = visibility.orderedMobileKeys();
    if (keys.isEmpty) return const ['dashboard'];
    return keys;
  }

  Widget _pageFor(String key) {
    switch (key) {
      case 'dashboard':
        return DashboardPage(onOpenPage: _openPage);
      case 'transactions':
        return const TransactionsPage();
      case 'reports':
        return const ReportsPage();
      case 'goals':
        return const GoalsPage();
      case 'education':
        return const EducationPage();
      case 'bills':
        return const BillsPage();
      case 'settings':
        return const SettingsPage();
      default:
        return DashboardPage(onOpenPage: _openPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibility = context.watch<PageVisibilityProvider>();
    final impersonation = context.watch<ImpersonationProvider>();
    final auth = context.watch<AuthProvider>();
    final activeProfile = impersonation.impersonatedProfile ?? auth.profile;
    // Sem plano ativo, apenas Configurações fica acessível (como no webapp).
    final requiresSubscription =
        activeProfile != null &&
        !activeProfile.isSubscriptionActive &&
        !impersonation.isImpersonating;

    var keys = _resolvedKeys(visibility);
    if (requiresSubscription) {
      keys = const ['settings'];
    }

    final currentKey = keys.contains(_currentKey)
        ? _currentKey
        : (keys.contains('dashboard') ? 'dashboard' : keys.first);
    final currentIndex = keys.indexOf(currentKey);
    final page = appPageByKey(currentKey);

    final items = [
      for (final key in keys)
        () {
          final page = appPageByKey(key);
          return DinFlowNavItem(
            label: page.label,
            icon: page.icon,
            activeIcon: page.activeIcon,
          );
        }(),
    ];

    return Scaffold(
      appBar: _buildHeader(
        context,
        isDashboard: currentKey == 'dashboard',
        pageLabel: page.label,
      ),
      body: Column(
        children: [
          if (impersonation.isImpersonating)
            _ImpersonationBanner(
              name: impersonation.impersonatedProfile?.displayName ?? 'usuário',
              onStop: () => context.read<ImpersonationProvider>().stop(),
            ),
          if (requiresSubscription) const _SubscriptionBanner(),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: [for (final key in keys) _pageFor(key)],
            ),
          ),
        ],
      ),
      bottomNavigationBar: DinFlowBottomNav(
        items: items,
        currentIndex: currentIndex,
        onTap: (index) => setState(() => _currentKey = keys[index]),
      ),
    );
  }

  void _showAuthorSheet(BuildContext context) {
    final authors = context.read<AuthorProvider>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Alternar usuário',
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Todos'),
              selected: authors.selected == null,
              onTap: () {
                authors.select(null);
                context.read<FinanceProvider>().setAuthorFilter(null);
                Navigator.pop(sheetContext);
              },
            ),
            for (final author in authors.authors)
              ListTile(
                leading: Icon(
                  author.isMain ? Icons.star_outline : Icons.person_outline,
                ),
                title: Text(author.name),
                subtitle: Text(author.whatsapp),
                selected: authors.selected?.whatsapp == author.whatsapp,
                onTap: () {
                  authors.select(author);
                  context.read<FinanceProvider>().setAuthorFilter(
                    author.whatsapp,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(
    BuildContext context, {
    required bool isDashboard,
    required String pageLabel,
  }) {
    final theme = Theme.of(context);

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            child: Row(
              children: [
                if (isDashboard)
                  _DashboardGreeting()
                else
                  Expanded(
                    child: Text(
                      pageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (!isDashboard) const Spacer(),
                _ContactButton(),
                _NotificationsButton(
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Alternar tema',
                  onPressed: () => context.read<ThemeController>().toggle(),
                  icon: Icon(
                    theme.brightness == Brightness.light
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!isDashboard)
                  _AccountButton(
                    onOpenAdmin: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SuperAdminPage()),
                    ),
                    onSwitchAuthor: () => _showAuthorSheet(context),
                    avatarSize: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Saudação com avatar (cabeçalho do dashboard). Tocar abre o menu de conta.
class _DashboardGreeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final impersonation = context.watch<ImpersonationProvider>();
    final activeProfile = impersonation.impersonatedProfile ?? auth.profile;
    final name =
        activeProfile?.firstName ??
        activeProfile?.displayName ??
        (auth.user?.email?.split('@').first ?? '');
    final displayName = name.trim().isEmpty ? 'Usuário' : name.trim();

    return Expanded(
      child: _AccountButton(
        onOpenAdmin: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SuperAdminPage())),
        onSwitchAuthor: () => _showAuthorSheet(context),
        child: Row(
          children: [
            _AccountAvatar(activeProfile: activeProfile, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthorSheet(BuildContext context) {
    final authors = context.read<AuthorProvider>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Alternar usuário',
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Todos'),
              selected: authors.selected == null,
              onTap: () {
                authors.select(null);
                context.read<FinanceProvider>().setAuthorFilter(null);
                Navigator.pop(sheetContext);
              },
            ),
            for (final author in authors.authors)
              ListTile(
                leading: Icon(
                  author.isMain ? Icons.star_outline : Icons.person_outline,
                ),
                title: Text(author.name),
                subtitle: Text(author.whatsapp),
                selected: authors.selected?.whatsapp == author.whatsapp,
                onTap: () {
                  authors.select(author);
                  context.read<FinanceProvider>().setAuthorFilter(
                    author.whatsapp,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.error.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sua assinatura não está ativa. Renove para liberar todos os recursos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpersonationBanner extends StatelessWidget {
  const _ImpersonationBanner({required this.name, required this.onStop});

  final String name;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mintColor = theme.brightness == Brightness.dark
        ? AppColors.mint
        : theme.colorScheme.primary;
    return Material(
      color: mintColor.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 18, color: mintColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Acessando como $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: mintColor,
                ),
              ),
            ),
            TextButton(
              onPressed: onStop,
              child: const Text('Parar de acessar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar do usuário ativo (imagem do perfil ou inicial).
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.activeProfile, required this.radius});

  final dynamic activeProfile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawName = (activeProfile?.displayName ?? '').trim();
    final initial = rawName.isEmpty ? 'U' : rawName[0].toUpperCase();
    final avatarUrl = activeProfile?.avatarUrl as String?;
    final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary,
      backgroundImage: hasImage ? NetworkImage(avatarUrl) : null,
      child: hasImage
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.85,
              ),
            ),
    );
  }
}

/// Botão de conta (menu popup) envolvendo o avatar ou a saudação do usuário.
class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.onOpenAdmin,
    required this.onSwitchAuthor,
    this.child,
    this.avatarSize = 18,
  });

  final VoidCallback onOpenAdmin;
  final VoidCallback onSwitchAuthor;
  final Widget? child;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final impersonation = context.watch<ImpersonationProvider>();
    final activeProfile = impersonation.impersonatedProfile ?? auth.profile;
    final isSuperadmin = auth.profile?.isSuperadmin ?? false;
    final hasAuthors = context.watch<AuthorProvider>().hasMultiple;

    return PopupMenuButton<String>(
      tooltip: 'Conta',
      onSelected: (value) {
        switch (value) {
          case 'logout':
            context.read<AuthProvider>().logout();
          case 'admin':
            onOpenAdmin();
          case 'author':
            onSwitchAuthor();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeProfile?.displayName ?? 'Usuário',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                activeProfile?.email ?? auth.user?.email ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (impersonation.isImpersonating)
                Text(
                  'Modo impersonation',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (hasAuthors)
          const PopupMenuItem<String>(
            value: 'author',
            child: Row(
              children: [
                Icon(Icons.switch_account_outlined, size: 18),
                SizedBox(width: 8),
                Text('Alternar usuário'),
              ],
            ),
          ),
        if (isSuperadmin && !impersonation.isImpersonating)
          const PopupMenuItem<String>(
            value: 'admin',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 18),
                SizedBox(width: 8),
                Text('Painel Admin'),
              ],
            ),
          ),
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
      child:
          child ??
          _AccountAvatar(activeProfile: activeProfile, radius: avatarSize),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unread = context.select<NotificationsProvider, int>(
      (provider) => provider.unreadCount,
    );

    return _SquareIconButton(
      onPressed: onOpen,
      tooltip: 'Notificações',
      icon: Icons.notifications_none_rounded,
      badge: unread > 0
          ? Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.mint : theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Botão de contato (WhatsApp ou assistente) no cabeçalho.
class _ContactButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final whatsapp = context.watch<AuthProvider>().globalSettings.whatsapp;

    if (whatsapp != null && whatsapp.isNotEmpty) {
      return _SquareIconButton(
        tooltip: 'Falar no WhatsApp',
        icon: Icons.chat_rounded,
        color: isDark ? AppColors.mint : theme.colorScheme.primary,
        onPressed: () => _open(context, whatsapp),
      );
    }
    return _SquareIconButton(
      tooltip: 'Assistente',
      icon: Icons.smart_toy_outlined,
      color: isDark ? AppColors.mint : theme.colorScheme.primary,
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ChatPage())),
    );
  }

  Future<void> _open(BuildContext context, String number) async {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }
}

/// Ícone no estilo das referências: botão quadrado compacto e arredondado.
class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    this.color,
    this.tooltip,
    this.onPressed,
    this.badge,
  });

  final IconData icon;
  final Color? color;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: iconColor),
                ?badge,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
