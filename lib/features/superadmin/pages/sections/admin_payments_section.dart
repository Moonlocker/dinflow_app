import 'package:flutter/material.dart';

import '../../../../repositories/admin_repository.dart';
import '../../widgets/admin_widgets.dart';

/// Configurações de pagamento (somente leitura no painel).
class AdminPaymentsSection extends StatefulWidget {
  const AdminPaymentsSection({super.key});

  @override
  State<AdminPaymentsSection> createState() => _AdminPaymentsSectionState();
}

class _AdminPaymentsSectionState extends State<AdminPaymentsSection> {
  final _repo = AdminRepository();
  bool _loading = true;
  String? _error;
  String _gateway = 'stripe';

  static const _gateways = [
    ('stripe', 'Stripe', ['Cartão', 'Google Pay', 'Apple Pay']),
    ('mercadoPago', 'Mercado Pago', ['Cartão', 'PIX', 'Boleto']),
    ('pagarme', 'Pagar.me', ['Cartão', 'PIX', 'Boleto']),
    ('pagseguro', 'PagSeguro', ['Cartão', 'PIX', 'Boleto']),
    ('paypal', 'PayPal', ['Cartão', 'PayPal']),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gateway = await _repo.fetchActiveGateway();
      if (!mounted) return;
      setState(() {
        _gateway = gateway;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as configurações.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();
    if (_error != null) return AdminError(message: _error!, onRetry: _load);

    final theme = Theme.of(context);
    final activeName = _gateways
        .firstWhere((item) => item.$1 == _gateway,
            orElse: () => ('stripe', 'Stripe', const <String>[]))
        .$2;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AdminSectionCard(
            title: 'Gateway ativo',
            subtitle: 'Definido no backend (Secrets). Somente leitura.',
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  activeName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final gateway in _gateways)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminSectionCard(
                title: gateway.$2,
                trailing: gateway.$1 == _gateway
                    ? const AdminStatusBadge(
                        label: 'Ativo', color: Color(0xFF10B981))
                    : null,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final method in gateway.$3)
                      Chip(
                        label: Text(method),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'As credenciais dos gateways são gerenciadas pelos Secrets do '
            'backend e não podem ser editadas pelo aplicativo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
