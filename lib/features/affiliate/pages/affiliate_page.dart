import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/formatters.dart';
import '../../../repositories/affiliate_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../impersonation/providers/impersonation_provider.dart';

/// Programa "Indique e Ganhe" (afiliação) do usuário.
class AffiliatePage extends StatefulWidget {
  const AffiliatePage({super.key});

  @override
  State<AffiliatePage> createState() => _AffiliatePageState();
}

class _AffiliatePageState extends State<AffiliatePage> {
  final _repo = AffiliateRepository();
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _config;
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _referrals = const [];
  List<Map<String, dynamic>> _earnings = const [];
  List<Map<String, dynamic>> _withdrawals = const [];

  String? _activeUserId() =>
      context.read<ImpersonationProvider>().impersonatedUserId ??
      context.read<AuthProvider>().user?.id;

  String? get _affiliateCode =>
      context.read<ImpersonationProvider>().impersonatedProfile?.affiliateCode ??
      context.read<AuthProvider>().profile?.affiliateCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = _activeUserId();
    try {
      final config = await _repo.fetchConfig();
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _config = config;
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        _repo.fetchStats(userId),
        _repo.fetchReferrals(),
        _repo.fetchEarnings(userId),
        _repo.fetchWithdrawals(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _config = config;
        _stats = results[0] as Map<String, dynamic>;
        _referrals = results[1] as List<Map<String, dynamic>>;
        _earnings = results[2] as List<Map<String, dynamic>>;
        _withdrawals = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _affiliateLink =>
      '${AppConfig.webAppUrl}/register?ref=${_affiliateCode ?? ''}';

  Future<void> _persistCode(String code) async {
    final userId = _activeUserId();
    if (userId == null) return;
    final repo = ProfileRepository();
    await repo.updateProfile(userId, {'affiliate_code': code});
    final updated = await repo.fetchProfile(userId);
    if (!mounted) return;
    if (updated != null) {
      final impersonation = context.read<ImpersonationProvider>();
      if (impersonation.isImpersonating) {
        impersonation.start(updated);
      } else {
        await context.read<AuthProvider>().refresh();
      }
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _generate({required bool regenerate}) async {
    if (regenerate) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gerar novo código?'),
          content: const Text(
            'O código atual não funcionará mais e você perderá indicações de links já compartilhados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Gerar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _saving = true);
    try {
      await _persistCode(_generateCode());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de afiliado atualizado!')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao gerar o código.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _affiliateLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado!')),
    );
  }

  Future<void> _shareLink() async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'DinFlow - Gestão Financeira',
        text:
            'Conheça o DinFlow! Use meu link de indicação e organize suas finanças: $_affiliateLink',
      ),
    );
  }

  Future<void> _requestWithdrawal() async {
    final pointsController = TextEditingController();
    var pixType = 'email';
    final pixKeyController = TextEditingController();
    final minPoints = (_config?['min_points_withdrawal'] ?? 0) as num;
    final available = (_stats['available_points'] ?? 0) as num;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Solicitar Saque via PIX'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Disponível: $available pontos • Mínimo: $minPoints',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pontos a sacar'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: pixType,
                  decoration: const InputDecoration(labelText: 'Tipo de chave PIX'),
                  items: const [
                    DropdownMenuItem(value: 'email', child: Text('E-mail')),
                    DropdownMenuItem(value: 'phone', child: Text('Telefone')),
                    DropdownMenuItem(value: 'cpf', child: Text('CPF')),
                    DropdownMenuItem(value: 'random', child: Text('Chave Aleatória')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => pixType = value ?? 'email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pixKeyController,
                  decoration: const InputDecoration(labelText: 'Chave PIX'),
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
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final points = int.tryParse(pointsController.text.trim()) ?? 0;
    if (points <= 0 || points < minPoints || points > available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor de pontos inválido.')),
      );
      return;
    }
    if (pixKeyController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a chave PIX.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.requestWithdrawal(
        points: points,
        pixKey: pixKeyController.text.trim(),
        pixType: pixType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação enviada! Será processada em breve.')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao solicitar o saque.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = _config?['enabled'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Indique e Ganhe')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !enabled
              ? const EmptyState(
                  icon: Icons.card_giftcard_outlined,
                  message:
                      'O sistema de indicações não está ativo no momento.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _linkCard(theme),
                      const SizedBox(height: 16),
                      _statsGrid(theme),
                      if (((_stats['available_points'] ?? 0) as num) > 0) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _requestWithdrawal,
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('Solicitar Saque via PIX'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _referralsCard(theme),
                      if (_earnings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _earningsCard(theme),
                      ],
                      if (_withdrawals.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _withdrawalsCard(theme),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _linkCard(ThemeData theme) {
    final code = _affiliateCode;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu Link de Afiliado',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (code == null || code.isEmpty)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _generate(regenerate: false),
                icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                label: const Text('Gerar Meu Código'),
              ),
            )
          else ...[
            SelectableText('Código: $code'),
            const SizedBox(height: 6),
            SelectableText(
              _affiliateLink,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _shareLink,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Compartilhar'),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _saving ? null : () => _generate(regenerate: true),
              child: const Text('Gerar novo código'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsGrid(ThemeData theme) {
    final cards = [
      ('Total Indicados', '${_stats['total_referrals'] ?? 0}', Icons.people_outline, const Color(0xFF3B82F6)),
      ('Pagos', '${_stats['paid_referrals'] ?? 0}', Icons.check_circle_outline, const Color(0xFF10B981)),
      ('Pendentes', '${_stats['pending_referrals'] ?? 0}', Icons.schedule, const Color(0xFFF59E0B)),
      ('Pontos Disponíveis', '${_stats['available_points'] ?? 0}', Icons.monetization_on_outlined, const Color(0xFF8B5CF6)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        for (final card in cards)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(card.$3, size: 20, color: card.$4),
                const SizedBox(height: 6),
                Text(
                  card.$2,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  card.$1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _referralsCard(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seus Indicados',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_referrals.isEmpty)
            const EmptyState(
              icon: Icons.people_outline,
              message: 'Nenhuma indicação ainda. Compartilhe seu link!',
            )
          else
            for (final referral in _referrals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${referral['user_name'] ?? 'Usuário'}',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${referral['user_email'] ?? ''} • ${formatDateOnly(referral['created_at']?.toString())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      referral['status'] == 'paid' ? 'Pago' : 'Registrado',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: referral['status'] == 'paid'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _earningsCard(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Histórico de Pontos',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final earning in _earnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${earning['description'] ?? 'Pontos de indicação'}'),
                  ),
                  Text(
                    '${((earning['points'] ?? 0) as num) > 0 ? '+' : ''}${earning['points'] ?? 0}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ((earning['points'] ?? 0) as num) > 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _withdrawalsCard(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Histórico de Saques',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final withdrawal in _withdrawals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCurrency(
                            ((withdrawal['amount_brl'] ?? 0) as num).toDouble(),
                          ),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${withdrawal['points_redeemed'] ?? 0} pontos • ${formatDateOnly(withdrawal['created_at']?.toString())}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _withdrawalStatus('${withdrawal['status']}'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _withdrawalStatus(String status) {
    switch (status) {
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Rejeitado';
      case 'paid':
        return 'Pago';
      default:
        return 'Pendente';
    }
  }
}
