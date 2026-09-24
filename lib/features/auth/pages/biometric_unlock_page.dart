import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../widgets/brand_logo.dart';
import '../providers/auth_provider.dart';

/// Tela exibida ao reabrir o app com sessão salva e biometria habilitada.
class BiometricUnlockPage extends StatefulWidget {
  const BiometricUnlockPage({super.key});

  @override
  State<BiometricUnlockPage> createState() => _BiometricUnlockPageState();
}

class _BiometricUnlockPageState extends State<BiometricUnlockPage> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_checking) return;
    setState(() => _checking = true);
    final ok = await context.read<AuthProvider>().unlockBiometric();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometria não reconhecida. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const BrandLogo(height: 56),
              const SizedBox(height: 32),
              Text(
                'Bem-vindo de volta',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Toque para desbloquear o DinFlow',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              _FingerprintButton(
                onPressed: _checking ? null : _unlock,
                checking: _checking,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                child: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FingerprintButton extends StatelessWidget {
  const _FingerprintButton({required this.onPressed, required this.checking});

  final VoidCallback? onPressed;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Desbloquear com biometria',
      button: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 96,
            height: 96,
            child: checking
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.fingerprint,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
          ),
        ),
      ),
    );
  }
}