import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../widgets/app_card.dart';

/// Executa verificações de configuração/infraestrutura do painel.
class AdminDiagnostics extends StatefulWidget {
  const AdminDiagnostics({super.key});

  @override
  State<AdminDiagnostics> createState() => _AdminDiagnosticsState();
}

class _AdminDiagnosticsState extends State<AdminDiagnostics> {
  bool _running = false;
  List<_DiagResult> _results = const [];

  // `stripe-config-check` é verificado à parte (abaixo), por isso não entra aqui.
  static const _criticalFunctions = [
    'stripe-create-checkout',
    'stripe-check-subscription',
    'stripe-customer-portal',
  ];

  static const _optionalFunctions = [
    'mercadopago-create-checkout',
  ];

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results = const [];
    });
    final client = Supabase.instance.client;
    final results = <_DiagResult>[];

    // 1. Configurações básicas.
    results.add(_DiagResult(
      title: 'Configurações Básicas',
      ok: AppConfig.supabaseUrl.isNotEmpty,
      detail: AppConfig.supabaseUrl,
    ));

    // 2. Gateways de pagamento.
    try {
      final response =
          await client.functions.invoke('stripe-config-check', body: const {});
      final data = response.data;
      final configured = data is Map ? data['configured'] == true : false;
      results.add(_DiagResult(
        title: 'Gateway Stripe',
        ok: configured,
        detail: configured ? 'Configurado' : 'Credenciais ausentes',
      ));
    } catch (_) {
      results.add(const _DiagResult(
        title: 'Gateway Stripe',
        ok: false,
        detail: 'Falha ao verificar',
      ));
    }

    // 3. Planos ativos.
    try {
      final data = await client
          .from('plans')
          .select('id, name, price, status')
          .eq('status', 'Ativo');
      final list = data as List;
      results.add(_DiagResult(
        title: 'Planos Ativos',
        ok: list.isNotEmpty,
        detail: '${list.length} plano(s) ativo(s)',
      ));
    } catch (_) {
      results.add(const _DiagResult(
        title: 'Planos Ativos',
        ok: false,
        detail: 'Falha ao consultar planos',
      ));
    }

    // 4. Edge Functions críticas.
    for (final fn in _criticalFunctions) {
      results.add(await _ping(client, fn, critical: true));
    }
    for (final fn in _optionalFunctions) {
      results.add(await _ping(client, fn, critical: false));
    }

    // 5. Autenticação.
    final user = client.auth.currentUser;
    results.add(_DiagResult(
      title: 'Autenticação',
      ok: user != null,
      detail: user?.email ?? 'Sem sessão',
    ));

    if (!mounted) return;
    setState(() {
      _results = results;
      _running = false;
    });
  }

  Future<_DiagResult> _ping(
    SupabaseClient client,
    String name, {
    required bool critical,
  }) async {
    try {
      await client.functions.invoke(name, body: const {'test': true});
      return _DiagResult(title: name, ok: true, detail: 'Respondendo');
    } on FunctionException catch (error) {
      // 400-499 significa que a função existe e respondeu (payload inválido,
      // autenticação, etc). Só 404/rede indicam indisponibilidade real.
      final exists = error.status >= 400 && error.status < 500;
      return _DiagResult(
        title: name,
        ok: exists,
        detail: exists ? 'Respondendo' : 'Indisponível',
      );
    } catch (_) {
      return _DiagResult(
        title: name,
        ok: false,
        detail: critical ? 'Indisponível' : 'Opcional indisponível',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final okCount = _results.where((r) => r.ok).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnóstico do Sistema',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Verifica configuração, gateways, planos e Edge Functions.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.health_and_safety_outlined, size: 18),
              label: const Text('Executar Diagnóstico'),
            ),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '$okCount/${_results.length} verificações OK',
              style: theme.textTheme.bodySmall?.copyWith(
                color: okCount == _results.length
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final result in _results)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      result.ok ? Icons.check_circle : Icons.error_outline,
                      size: 18,
                      color: result.ok
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.title,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            result.detail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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

class _DiagResult {
  const _DiagResult({
    required this.title,
    required this.ok,
    required this.detail,
  });

  final String title;
  final bool ok;
  final String detail;
}
