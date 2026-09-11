import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../models/admin_user.dart';
import '../../../../repositories/admin_repository.dart';
import '../../../../widgets/app_card.dart';
import '../../widgets/admin_widgets.dart';

/// Gerenciamento do programa de afiliados.
class AdminAffiliatesSection extends StatefulWidget {
  const AdminAffiliatesSection({super.key});

  @override
  State<AdminAffiliatesSection> createState() => _AdminAffiliatesSectionState();
}

class _AdminAffiliatesSectionState extends State<AdminAffiliatesSection>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  late final TabController _tabController;
  bool _loading = true;
  Map<String, dynamic> _stats = const {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _repo.fetchAffiliateStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.9,
              children: [
                AdminStatCard(
                  title: 'Indicações',
                  value: '${_stats['referrals'] ?? 0}',
                  icon: Icons.people_outline,
                  accent: const Color(0xFF3B82F6),
                ),
                AdminStatCard(
                  title: 'Pontos Ativos',
                  value: '${_stats['active_points'] ?? 0}',
                  icon: Icons.stars_outlined,
                  accent: const Color(0xFF8B5CF6),
                ),
                AdminStatCard(
                  title: 'Saques Pendentes',
                  value: '${_stats['pending_withdrawals'] ?? 0}',
                  icon: Icons.schedule,
                  accent: const Color(0xFFF59E0B),
                ),
                AdminStatCard(
                  title: 'Valor Pendente',
                  value: formatCurrency(
                    ((_stats['pending_value'] ?? 0) as num).toDouble(),
                  ),
                  icon: Icons.payments_outlined,
                  accent: const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Configuração'),
            Tab(text: 'Indicações'),
            Tab(text: 'Saques'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_AffiliateConfigTab(), _ReferralsTab(), _WithdrawalsTab()],
          ),
        ),
      ],
    );
  }
}

class _AffiliateConfigTab extends StatefulWidget {
  const _AffiliateConfigTab();

  @override
  State<_AffiliateConfigTab> createState() => _AffiliateConfigTabState();
}

class _AffiliateConfigTabState extends State<_AffiliateConfigTab> {
  final _repo = AdminRepository();
  final _pointsReferralController = TextEditingController();
  final _pointsRealController = TextEditingController();
  final _minPointsController = TextEditingController();
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pointsReferralController.dispose();
    _pointsRealController.dispose();
    _minPointsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await _repo.fetchAffiliateConfig();
      if (config != null) {
        _enabled = (config['enabled'] ?? false) as bool;
        _pointsReferralController.text = '${config['points_per_referral'] ?? 0}';
        _pointsRealController.text = '${config['points_per_real'] ?? 0}';
        _minPointsController.text = '${config['min_points_withdrawal'] ?? 0}';
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.saveAffiliateConfig({
        'enabled': _enabled,
        'points_per_referral': int.tryParse(_pointsReferralController.text) ?? 0,
        'points_per_real': int.tryParse(_pointsRealController.text) ?? 0,
        'min_points_withdrawal': int.tryParse(_minPointsController.text) ?? 0,
      });
      if (!mounted) return;
      showAdminSnack(context, 'Configurações salvas.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao salvar.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AdminSectionCard(
          title: 'Programa de Afiliados',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                title: const Text('Sistema Ativo'),
              ),
              TextField(
                controller: _pointsReferralController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Pontos por indicação paga'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pointsRealController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Pontos por real (opcional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minPointsController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Pontos mínimos para saque'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Salvar Configurações'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferralsTab extends StatefulWidget {
  const _ReferralsTab();

  @override
  State<_ReferralsTab> createState() => _ReferralsTabState();
}

class _ReferralsTabState extends State<_ReferralsTab> {
  final _repo = AdminRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _referrals = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final referrals = await _repo.listAffiliateReferrals();
      if (!mounted) return;
      setState(() {
        _referrals = referrals;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_referrals.isEmpty)
            const AdminEmpty(message: 'Nenhuma indicação registrada.')
          else
            for (final referral in _referrals)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Indicado: ${referral['referred_user_id']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${adminDate(referral['created_at'])} • +${referral['points_awarded'] ?? 0} pontos',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      AdminStatusBadge(
                        label: referral['status'] == 'paid' ? 'Pago' : 'Registrado',
                        color: referral['status'] == 'paid'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _WithdrawalsTab extends StatefulWidget {
  const _WithdrawalsTab();

  @override
  State<_WithdrawalsTab> createState() => _WithdrawalsTabState();
}

class _WithdrawalsTabState extends State<_WithdrawalsTab> {
  final _repo = AdminRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _withdrawals = const [];
  Map<String, String> _names = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.listAffiliateWithdrawals(),
        _repo.listProfiles(),
      ]);
      final profiles = results[1] as List<AdminUser>;
      if (!mounted) return;
      setState(() {
        _withdrawals = results[0] as List<Map<String, dynamic>>;
        _names = {for (final profile in profiles) profile.id: profile.displayName};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> withdrawal, String status) async {
    try {
      await _repo.approveWithdrawal(
        withdrawalId: withdrawal['id'] as String,
        status: status,
      );
      if (!mounted) return;
      showAdminSnack(context, 'Saque ${status == 'approved' ? 'aprovado' : 'rejeitado'}.');
      _load();
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao processar o saque.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_withdrawals.isEmpty)
            const AdminEmpty(message: 'Nenhum saque solicitado.')
          else
            for (final withdrawal in _withdrawals)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatCurrency(
                                ((withdrawal['amount_brl'] ?? 0) as num).toDouble(),
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AdminStatusBadge(
                            label: _statusLabel('${withdrawal['status']}'),
                            color: _statusColor('${withdrawal['status']}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Afiliado: ${_names['${withdrawal['affiliate_user_id']}'] ?? withdrawal['affiliate_user_id']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'PIX: ${withdrawal['pix_type'] ?? '-'} • ${withdrawal['pix_key'] ?? '-'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        adminDateTime(withdrawal['created_at']),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      if (withdrawal['status'] == 'pending')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _review(withdrawal, 'rejected'),
                              child: const Text('Rejeitar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _review(withdrawal, 'approved'),
                              child: const Text('Aprovar'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Rejeitado';
      default:
        return 'Pendente';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }
}
