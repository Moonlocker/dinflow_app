import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/profile.dart';
import '../../../repositories/affiliate_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../../widgets/app_card.dart';
import '../../affiliate/pages/affiliate_page.dart';
import '../../auth/providers/auth_provider.dart';
import '../../impersonation/providers/impersonation_provider.dart';
import '../../subscription/pages/subscription_page.dart';
import 'category_settings_page.dart';
import 'security_settings_page.dart';
import 'whatsapp_helper_page.dart';
import 'whatsapp_numbers_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _uploadingAvatar = false;
  String _country = 'BR';
  bool _affiliateEnabled = false;
  ImpersonationProvider? _impersonation;

  static const _countries = ['BR', 'US', 'PT', 'ES', 'AR', 'MX', 'CA', 'FR', 'DE', 'IT'];

  /// Perfil ativo (impersonado, quando aplicável; senão o do usuário real).
  Profile? _activeProfile() =>
      _impersonation?.impersonatedProfile ?? context.read<AuthProvider>().profile;

  @override
  void initState() {
    super.initState();
    _impersonation = context.read<ImpersonationProvider>();
    _impersonation!.addListener(_onImpersonationChanged);
    _fillControllers(_activeProfile());
    _loadAffiliate();
  }

  Future<void> _loadAffiliate() async {
    try {
      final config = await AffiliateRepository().fetchConfig();
      if (!mounted) return;
      setState(() => _affiliateEnabled = config?['enabled'] == true);
    } catch (_) {
      // Mantém desabilitado em caso de erro.
    }
  }

  @override
  void dispose() {
    _impersonation?.removeListener(_onImpersonationChanged);
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onImpersonationChanged() {
    if (!mounted) return;
    _fillControllers(_activeProfile());
    setState(() {});
  }

  void _fillControllers(Profile? profile) {
    _nameController.text = profile?.name ?? '';
    _emailController.text = profile?.email ?? '';
    _whatsappController.text = profile?.whatsapp ?? '';
    _country = profile?.country ?? 'BR';
  }

  Future<void> _saveProfile() async {
    final values = {
      'name': _nameController.text.trim(),
      'whatsapp': _whatsappController.text.trim(),
      'country': _country,
    };
    setState(() => _savingProfile = true);
    try {
      await _persistProfile(values);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar o perfil.')),
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  /// Grava os dados no usuário ativo (impersonado ou o próprio).
  Future<void> _persistProfile(Map<String, dynamic> values) async {
    final impersonation = context.read<ImpersonationProvider>();
    if (impersonation.isImpersonating) {
      final id = impersonation.impersonatedUserId!;
      final repo = ProfileRepository();
      await repo.updateProfile(id, values);
      final updated = await repo.fetchProfile(id);
      if (updated != null) impersonation.start(updated);
    } else {
      await context.read<AuthProvider>().updateProfile(values);
    }
  }

  Future<void> _pickAvatar() async {
    final impersonation = context.read<ImpersonationProvider>();
    final auth = context.read<AuthProvider>();
    final userId = impersonation.impersonatedUserId ?? auth.user?.id;
    if (userId == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      var extension =
          picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      if (extension == 'jpeg') extension = 'jpg';

      if (impersonation.isImpersonating) {
        final repo = ProfileRepository();
        final url = await repo.uploadAvatar(
          userId: userId,
          bytes: bytes,
          extension: extension,
        );
        await repo.updateProfile(userId, {'avatar_url': url});
        final updated = await repo.fetchProfile(userId);
        if (updated != null) impersonation.start(updated);
      } else {
        await auth.uploadAvatar(bytes: bytes, extension: extension);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar atualizado!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao enviar a imagem.')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await _persistProfile({'avatar_url': null});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar removido.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao remover o avatar.')),
      );
    }
  }

  Future<void> _changePassword() async {
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A senha deve ter ao menos 6 caracteres.')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem.')),
      );
      return;
    }
    setState(() => _savingPassword = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(_passwordController.text);
    if (!mounted) return;
    setState(() => _savingPassword = false);
    if (ok) {
      _passwordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Erro ao alterar a senha.')),
      );
      auth.clearError();
    }
  }

  Future<void> _togglePreference(String key, bool value) async {
    try {
      await _persistProfile({key: value});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar a preferência.')),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Você precisará entrar novamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final impersonation = context.watch<ImpersonationProvider>();
    final profile = impersonation.impersonatedProfile ?? auth.profile;
    final isImpersonating = impersonation.isImpersonating;
    final themeController = context.watch<ThemeController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Configurações',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          'Gerencie sua conta e preferências',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isImpersonating) ...[
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Você está acessando como ${profile?.displayName ?? 'usuário'}. '
                    'As edições de perfil e preferências são aplicadas a este usuário; '
                    'ações de conta (senha, segurança e assinatura) ficam indisponíveis.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informações Pessoais',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.primary,
                    backgroundImage:
                        (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                    child:
                        (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty)
                            ? Text(
                                (profile?.displayName ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _uploadingAvatar ? null : _pickAvatar,
                          icon: _uploadingAvatar
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_outlined, size: 18),
                          label: const Text('Alterar foto'),
                        ),
                        if (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                          TextButton(
                            onPressed: _removeAvatar,
                            child: const Text('Remover foto'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome completo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                enabled: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'WhatsApp principal'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _country,
                decoration: const InputDecoration(labelText: 'País'),
                items: [
                  for (final country in _countries)
                    DropdownMenuItem(value: country, child: Text(country)),
                ],
                onChanged: (value) => setState(() => _country = value ?? 'BR'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _savingProfile ? null : _saveProfile,
                child: _savingProfile
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salvar Alterações'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aparência',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: themeController.isDark,
                onChanged: (_) => themeController.toggle(),
                title: const Text('Tema escuro'),
                subtitle: Text(themeController.isDark ? 'Ativado' : 'Desativado'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assinatura',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Status', value: _statusLabel(profile?.subscriptionStatus)),
              if (profile?.subscriptionStatus == 'trial')
                _InfoRow(label: 'Dias restantes', value: '${profile?.trialDaysLeft ?? 0}'),
              if (profile?.subscriptionEndDate != null)
                _InfoRow(
                  label: 'Válida até',
                  value: formatDateOnly(profile!.subscriptionEndDate!.toIso8601String()),
                ),
              if (!isImpersonating) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                    ),
                    icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                    label: const Text('Gerenciar Assinatura'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notificações',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: profile?.expenseAlerts ?? true,
                onChanged: (value) => _togglePreference('expense_alerts', value),
                title: const Text('Alertas de despesas'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: profile?.goalReminders ?? true,
                onChanged: (value) => _togglePreference('goal_reminders', value),
                title: const Text('Lembretes de metas'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: profile?.monthlyReports ?? false,
                onChanged: (value) => _togglePreference('monthly_reports', value),
                title: const Text('Relatórios mensais'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: profile?.billReminders ?? true,
                onChanged: (value) => _togglePreference('bill_reminders', value),
                title: const Text('Lembretes de contas'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CategorySettingsPage()),
          ),
          child: Row(
            children: [
              const Icon(Icons.category_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categorias',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Gerencie suas categorias de receitas e despesas',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WhatsappNumbersPage()),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_android),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Números de WhatsApp',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Adicione números extras para lançamentos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WhatsappHelperPage()),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Oficial',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Lançamentos por mensagem',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        if (_affiliateEnabled) ...[
          const SizedBox(height: 16),
          AppCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AffiliatePage()),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Indique e Ganhe',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Compartilhe seu link e ganhe pontos',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppCard(
          onTap: isImpersonating
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SecuritySettingsPage()),
                  ),
          child: Row(
            children: [
              const Icon(Icons.security_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Segurança',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Autenticação em dois fatores',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!isImpersonating)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alterar Senha',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova senha'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _savingPassword ? null : _changePassword,
                child: _savingPassword
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Alterar Senha'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sobre',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _InfoRow(label: 'Aplicativo', value: auth.globalSettings.appName),
              const _InfoRow(label: 'Versão', value: '1.0.0'),
              const _InfoRow(label: 'Suporte', value: AppConfig.supportEmail),
            ],
          ),
        ),
        if (!isImpersonating) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            label: const Text('Sair da conta',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ],
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'Ativa';
      case 'trial':
        return 'Período de teste';
      case 'canceled':
        return 'Cancelada';
      case 'past_due':
        return 'Pagamento pendente';
      case 'expired':
        return 'Expirada';
      case 'inactive':
        return 'Inativa';
      default:
        return status ?? '-';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
