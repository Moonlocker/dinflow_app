import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';

/// Instruções para usar o WhatsApp oficial do DinFlow.
class WhatsappHelperPage extends StatelessWidget {
  const WhatsappHelperPage({super.key});

  Future<void> _open(BuildContext context, String number) async {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent('Olá! Quero lançar uma transação.')}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<AuthProvider>().globalSettings;
    final whatsapp = settings.whatsapp;

    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Oficial')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (whatsapp == null || whatsapp.isEmpty)
            const EmptyState(
              icon: Icons.chat_bubble_outline,
              message: 'WhatsApp indisponível no momento.',
            )
          else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF25D366)),
                      const SizedBox(width: 8),
                      Text(
                        'Número oficial do ${settings.appName}',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    whatsapp,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                      ),
                      onPressed: () => _open(context, whatsapp),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('Iniciar Conversa no WhatsApp'),
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
                    'O que você pode fazer',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const _Bullet('Adicionar transações: "Gastei 50 reais no almoço"'),
                  const _Bullet('Editar ou excluir lançamentos pelo ID'),
                  const _Bullet('Solicitar relatórios financeiros'),
                  const _Bullet('Consultar saldo e resumo do mês'),
                  const SizedBox(height: 8),
                  Text(
                    'Cada lançamento recebe um ID único (ex.: WP26) para '
                    'edições e exclusões posteriores.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
