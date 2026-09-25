import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../core/config/app_config.dart';

final Map<OAuthProvider, ({String label, IconData icon})> _meta = {
  OAuthProvider.google: (
    label: 'Continuar com Google',
    icon: Icons.g_mobiledata,
  ),
  OAuthProvider.apple: (label: 'Continuar com Apple', icon: Icons.apple),
};

/// Botões de login social (Google/Apple) construídos a partir da configuração
/// real do projeto ([AppConfig.enabledOAuthProviders]).
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({
    super.key,
    required this.enabled,
    required this.onProvider,
  });

  /// `false` enquanto o formulário estiver em processamento (desabilita).
  final bool enabled;
  final void Function(OAuthProvider provider) onProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers = AppConfig.enabledOAuthProviders;
    if (providers.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('ou', style: theme.textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < providers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: enabled ? () => onProvider(providers[i]) : null,
            icon: Icon(_meta[providers[i]]!.icon, size: 24),
            label: Text(_meta[providers[i]]!.label),
          ),
        ],
      ],
    );
  }
}
