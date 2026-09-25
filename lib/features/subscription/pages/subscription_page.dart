import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/plan.dart';
import '../../../repositories/subscription_repository.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';

/// Tela de assinatura: escolha de plano e gestão via Stripe.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _repo = SubscriptionRepository();
  bool _loading = true;
  String? _error;
  List<Plan> _plans = const [];
  String _gateway = 'stripe';
  String? _busyPlanId;
  String _cycle = 'monthly';
  bool _loadingHistory = false;

  List<Plan> get _visiblePlans => _cycle == 'monthly'
      ? _plans.where((plan) => plan.recurrence == 'monthly').toList()
      : _plans.where((plan) => plan.recurrence != 'monthly').toList();

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
      final results = await Future.wait([
        _repo.fetchActivePlans(),
        _repo.fetchActiveGateway(),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<Plan>;
        _gateway = results[1] as String;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os planos.';
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _snack('Link inválido.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _snack('Não foi possível abrir o checkout.');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _subscribe(Plan plan) async {
    setState(() => _busyPlanId = plan.id);
    try {
      final url = await _repo.createCheckout(plan.id);
      if (url == null) {
        _snack('Não foi possível iniciar o checkout.');
        return;
      }
      await _openUrl(url);
    } catch (_) {
      _snack('Erro ao iniciar o checkout.');
    } finally {
      if (mounted) setState(() => _busyPlanId = null);
    }
  }

  Future<void> _openPortal() async {
    try {
      final url = await _repo.openCustomerPortal();
      if (url == null) {
        _snack('Não foi possível abrir o portal de assinatura.');
        return;
      }
      await _openUrl(url);
    } catch (_) {
      _snack('Erro ao abrir o portal de assinatura.');
    }
  }

  Future<void> _cancel() async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar assinatura?'),
        content: const Text(
          'Você mantém o acesso até o fim do período já pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Manter'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.cancelSubscription('Cancelamento via aplicativo');
      await auth.refresh();
      _snack('Assinatura cancelada.');
    } catch (_) {
      _snack('Erro ao cancelar a assinatura.');
    }
  }

  Future<void> _openHistory() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    setState(() => _loadingHistory = true);
    try {
      final payments = await _repo.fetchPayments(userId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Histórico de Pagamentos'),
          content: SizedBox(
            width: 420,
            child: payments.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'Nenhum pagamento registrado.',
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final payment in payments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(
                            formatCurrency(
                              ((payment['amount'] ?? 0) as num).toDouble(),
                            ),
                          ),
                          subtitle: Text(
                            '${_paymentStatusLabel('${payment['status']}')} • '
                            '${_shortDate(payment['created_at'])}',
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (_) {
      _snack('Não foi possível carregar o histórico.');
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Pago';
      case 'pending':
        return 'Pendente';
      case 'failed':
        return 'Falhou';
      case 'refunded':
        return 'Reembolsado';
      default:
        return status;
    }
  }

  String _shortDate(dynamic value) {
    if (value == null) return '-';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return '-';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Assinatura')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sua assinatura',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status: ${_statusLabel(profile?.subscriptionStatus)}',
                          ),
                          if (profile?.trialEndsAt != null &&
                              profile?.subscriptionStatus == 'trial')
                            Text(
                              'Trial até ${formatDateOnly(profile!.trialEndsAt!.toIso8601String())}',
                            ),
                          if (profile?.subscriptionEndDate != null)
                            Text(
                              'Válida até ${formatDateOnly(profile!.subscriptionEndDate!.toIso8601String())}',
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _openPortal,
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text('Gerenciar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _loadingHistory
                                    ? null
                                    : _openHistory,
                                icon: _loadingHistory
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.receipt_long_outlined,
                                        size: 18,
                                      ),
                                label: const Text('Histórico'),
                              ),
                              if (profile?.subscriptionStatus == 'active')
                                OutlinedButton.icon(
                                  onPressed: _cancel,
                                  icon: Icon(
                                    Icons.cancel_outlined,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  label: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'monthly', label: Text('Mensal')),
                        ButtonSegment(value: 'yearly', label: Text('Anual')),
                      ],
                      selected: {_cycle},
                      onSelectionChanged: (value) =>
                          setState(() => _cycle = value.first),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Planos disponíveis',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pagamento seguro via ${_gateway == 'stripe' ? 'Stripe' : _gateway}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_visiblePlans.isEmpty)
                      const EmptyState(
                        icon: Icons.credit_card_outlined,
                        message: 'Nenhum plano disponível no momento.',
                      )
                    else
                      for (final plan in _visiblePlans)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        plan.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      '${formatCurrency(plan.price)} / ${plan.recurrenceLabel}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                                if (plan.features.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  for (final feature in plan.features)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Color(0xFF10B981),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(feature)),
                                        ],
                                      ),
                                    ),
                                ],
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _busyPlanId == null
                                        ? () => _subscribe(plan)
                                        : null,
                                    child: _busyPlanId == plan.id
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Assinar'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
      ),
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
      default:
        return status ?? 'Inativa';
    }
  }
}
