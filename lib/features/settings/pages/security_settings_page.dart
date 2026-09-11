import 'package:flutter/material.dart';
import 'package:otp/otp.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../repositories/account_repository.dart';
import '../../../widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../finance/providers/finance_provider.dart';

/// Configurações de segurança do usuário (autenticação em dois fatores).
class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool _saving = false;

  Future<void> _enable() async {
    final auth = context.read<AuthProvider>();
    final secret = OTP.randomSecret();
    final email = auth.user?.email ?? 'usuario';
    final uri = 'otpauth://totp/DinFlow:$email'
        '?secret=$secret&issuer=DinFlow&algorithm=SHA1&digits=6&period=30';

    final codeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ativar 2FA'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Escaneie o QR Code no seu aplicativo autenticador e informe o código gerado.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              QrImageView(data: uri, size: 180),
              const SizedBox(height: 8),
              SelectableText(
                'Chave: $secret',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final code = codeController.text.trim();
    if (!_verifyCode(secret, code)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código inválido. Tente novamente.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await auth.updateProfile({
        'two_factor_enabled': true,
        'two_factor_secret': secret,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('2FA ativado com sucesso!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao ativar o 2FA.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _verifyCode(String secret, String code) {
    if (code.length != 6) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final offset in [-1, 0, 1]) {
      final generated = OTP.generateTOTPCodeString(
        secret,
        now + offset * 30000,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      if (generated == code) return true;
    }
    return false;
  }

  Future<void> _disable() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desativar 2FA'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Senha atual'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    setState(() => _saving = true);
    try {
      final ok = await auth.verifyPassword(passwordController.text);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha incorreta.')),
        );
        return;
      }
      await auth.updateProfile({
        'two_factor_enabled': false,
        'two_factor_secret': null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('2FA desativado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao desativar o 2FA.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetData() async {
    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar dados financeiros?'),
        content: const Text(
          'Transações, metas e pagamentos de contas serão removidos. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final userId = auth.user?.id;
    if (userId == null) return;
    try {
      await AccountRepository().resetFinancialData(userId);
      await finance.reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados financeiros removidos.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao resetar os dados.')),
      );
    }
  }

  Future<void> _logoutAll() async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair de todos os dispositivos?'),
        content: const Text('Você precisará entrar novamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<AuthProvider>().profile;
    final enabled = profile?.twoFactorEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Segurança')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      enabled ? Icons.verified_user : Icons.gpp_maybe_outlined,
                      color: enabled
                          ? const Color(0xFF10B981)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Autenticação em dois fatores',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  enabled
                      ? 'O 2FA está ativado na sua conta.'
                      : 'Adicione uma camada extra de segurança à sua conta.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: enabled
                      ? OutlinedButton.icon(
                          onPressed: _saving ? null : _disable,
                          icon: const Icon(Icons.lock_open_outlined, size: 18),
                          label: const Text('Desativar 2FA'),
                        )
                      : FilledButton.icon(
                          onPressed: _saving ? null : _enable,
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: const Text('Ativar 2FA'),
                        ),
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
                  'Zona de Perigo',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logoutAll,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sair de todos os dispositivos'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resetData,
                    icon: Icon(Icons.delete_forever,
                        size: 18, color: theme.colorScheme.error),
                    label: Text(
                      'Resetar dados financeiros',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
