import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../repositories/admin_repository.dart';
import '../../widgets/admin_charts.dart';
import '../../widgets/admin_widgets.dart';

/// Visão geral da plataforma: indicadores, pagamentos e cadastros recentes.
class AdminDashboardSection extends StatefulWidget {
  const AdminDashboardSection({super.key});

  @override
  State<AdminDashboardSection> createState() => _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends State<AdminDashboardSection> {
  final _repo = AdminRepository();

  bool _loading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _data = const {};
  List<Map<String, dynamic>> _recentPayments = const [];
  List<Map<String, dynamic>> _recentSignups = const [];
  Map<String, String> _userNames = const {};
  Map<String, String> _planNames = const {};

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
        _repo.fetchDashboardData(),
        _repo.fetchRecentPayments(),
        _repo.fetchRecentSignups(),
        _repo.listProfiles(),
        _repo.listPlans(),
      ]);

      final data = results[0] as Map<String, List<Map<String, dynamic>>>;
      final recentPayments = results[1] as List<Map<String, dynamic>>;
      final recentSignups = results[2] as List<Map<String, dynamic>>;
      final profiles = results[3] as List;
      final plans = results[4] as List;

      final userNames = <String, String>{};
      for (final profile in profiles) {
        userNames[profile.id as String] = profile.displayName as String;
      }
      final planNames = <String, String>{
        for (final plan in plans) plan.id as String: plan.name as String,
      };

      if (!mounted) return;
      setState(() {
        _data = data;
        _recentPayments = recentPayments;
        _recentSignups = recentSignups
            .where((item) => item['role'] != 'superadmin')
            .toList();
        _userNames = userNames;
        _planNames = planNames;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os dados.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();
    if (_error != null) return AdminError(message: _error!, onRetry: _load);

    final stats = _computeStats();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Visão Geral da Plataforma',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar dados',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              AdminStatCard(
                title: 'Faturamento Total',
                value: formatCurrency(stats.totalRevenue),
                subtitle: '${stats.paidCount} pagamentos',
                icon: Icons.attach_money,
                accent: const Color(0xFF10B981),
              ),
              AdminStatCard(
                title: 'Faturamento no Mês',
                value: formatCurrency(stats.monthlyRevenue),
                subtitle: '${stats.monthlyCount} pagamentos',
                icon: Icons.wallet_outlined,
                accent: const Color(0xFF3B82F6),
              ),
              AdminStatCard(
                title: 'Receita Próx. 30 dias',
                value: formatCurrency(stats.next30Revenue),
                subtitle: 'Assinaturas ativas',
                icon: Icons.trending_up,
                accent: const Color(0xFF8B5CF6),
              ),
              AdminStatCard(
                title: 'Ticket Médio',
                value: formatCurrency(stats.avgTicket),
                icon: Icons.receipt_long_outlined,
                accent: const Color(0xFFF59E0B),
              ),
              AdminStatCard(
                title: 'Clientes Ativos',
                value: '${stats.activeClients}',
                icon: Icons.person_outline,
                accent: const Color(0xFF10B981),
              ),
              AdminStatCard(
                title: 'Clientes Inativos',
                value: '${stats.inactiveClients}',
                icon: Icons.person_off_outlined,
                accent: const Color(0xFFEF4444),
              ),
              AdminStatCard(
                title: 'Novos Usuários (30d)',
                value: '${stats.newUsers30d}',
                icon: Icons.person_add_alt_outlined,
                accent: const Color(0xFF3B82F6),
              ),
              AdminStatCard(
                title: 'Total de Usuários',
                value: '${stats.totalUsers}',
                icon: Icons.groups_outlined,
                accent: const Color(0xFF6366F1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminCharts(data: _data),
          const SizedBox(height: 16),
          AdminSectionCard(
            title: 'Pagamentos Recentes',
            child: _recentPayments.isEmpty
                ? const AdminEmpty(message: 'Nenhum pagamento registrado.')
                : Column(
                    children: [
                      for (final payment in _recentPayments)
                        _PaymentTile(
                          payment: payment,
                          userName: _userNames[payment['user_id']] ?? 'Usuário removido',
                          planName: _planNames[payment['plan_id']] ?? 'Plano não identificado',
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          AdminSectionCard(
            title: 'Cadastros Recentes',
            child: _recentSignups.isEmpty
                ? const AdminEmpty(message: 'Nenhum cadastro recente.')
                : Column(
                    children: [
                      for (final user in _recentSignups)
                        _SignupTile(user: user),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  _DashboardStats _computeStats() {
    final profiles = (_data['profiles'] ?? [])
        .where((item) => item['role'] != 'superadmin')
        .toList();
    final payments = _data['payments'] ?? [];
    final plans = _data['plans'] ?? [];
    final subscriptions = _data['subscriptions'] ?? [];

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final in30Days = now.add(const Duration(days: 30));

    final paidPayments = payments
        .where((item) => item['status'] == 'paid')
        .toList();

    double totalRevenue = 0;
    double monthlyRevenue = 0;
    int monthlyCount = 0;
    for (final payment in paidPayments) {
      final amount = ((payment['amount'] ?? 0) as num).toDouble();
      totalRevenue += amount;
      final createdAt = DateTime.tryParse('${payment['created_at']}');
      if (createdAt != null && createdAt.isAfter(monthStart)) {
        monthlyRevenue += amount;
        monthlyCount++;
      }
    }

    final planPrices = <String, double>{
      for (final plan in plans)
        plan['id'] as String: ((plan['price'] ?? 0) as num).toDouble(),
    };

    double next30Revenue = 0;
    final activeSubUserIds = <String>{};
    for (final sub in subscriptions) {
      final status = sub['status'];
      if (status != 'active') continue;
      final periodEnd = DateTime.tryParse('${sub['current_period_end']}');
      if (periodEnd == null || periodEnd.isAfter(now)) {
        activeSubUserIds.add('${sub['user_id']}');
      }
      if (periodEnd != null &&
          periodEnd.isAfter(now) &&
          periodEnd.isBefore(in30Days)) {
        next30Revenue += planPrices['${sub['plan_id']}'] ?? 0;
      }
    }

    var activeClients = 0;
    var newUsers30d = 0;
    for (final profile in profiles) {
      final status = profile['subscription_status'];
      final trialEnds = DateTime.tryParse('${profile['trial_ends_at']}');
      final isTrialActive = status == 'trial' &&
          trialEnds != null &&
          trialEnds.isAfter(now);
      if (activeSubUserIds.contains(profile['id']) || isTrialActive) {
        activeClients++;
      }
      final createdAt = DateTime.tryParse('${profile['created_at']}');
      if (createdAt != null && createdAt.isAfter(thirtyDaysAgo)) {
        newUsers30d++;
      }
    }

    return _DashboardStats(
      totalRevenue: totalRevenue,
      paidCount: paidPayments.length,
      monthlyRevenue: monthlyRevenue,
      monthlyCount: monthlyCount,
      next30Revenue: next30Revenue,
      avgTicket: paidPayments.isEmpty ? 0 : totalRevenue / paidPayments.length,
      activeClients: activeClients,
      inactiveClients: profiles.length - activeClients,
      newUsers30d: newUsers30d,
      totalUsers: profiles.length,
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.userName,
    required this.planName,
  });

  final Map<String, dynamic> payment;
  final String userName;
  final String planName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = '${payment['status']}';
    final color = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '$planName • ${adminDate(payment['created_at'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                adminCurrency(payment['amount']),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              AdminStatusBadge(label: _statusLabel(status), color: color),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
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

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _SignupTile extends StatelessWidget {
  const _SignupTile({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = '${user['subscription_status']}';
    final name = (user['name'] ?? 'Sem nome') as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${user['email']} • ${adminDate(user['created_at'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AdminStatusBadge(
            label: _statusLabel(status),
            color: _statusColor(status),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Ativo';
      case 'trial':
        return 'Trial';
      case 'expired':
        return 'Expirado';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF10B981);
      case 'trial':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.totalRevenue,
    required this.paidCount,
    required this.monthlyRevenue,
    required this.monthlyCount,
    required this.next30Revenue,
    required this.avgTicket,
    required this.activeClients,
    required this.inactiveClients,
    required this.newUsers30d,
    required this.totalUsers,
  });

  final double totalRevenue;
  final int paidCount;
  final double monthlyRevenue;
  final int monthlyCount;
  final double next30Revenue;
  final double avgTicket;
  final int activeClients;
  final int inactiveClients;
  final int newUsers30d;
  final int totalUsers;
}
