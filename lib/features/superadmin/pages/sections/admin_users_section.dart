import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/admin_user.dart';
import '../../../../models/plan.dart';
import '../../../../repositories/admin_repository.dart';
import '../../../../repositories/profile_repository.dart';
import '../../../../widgets/app_card.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../impersonation/providers/impersonation_provider.dart';
import '../../widgets/admin_widgets.dart';

/// Gerenciamento de usuários do painel administrativo.
class AdminUsersSection extends StatefulWidget {
  const AdminUsersSection({super.key});

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  final _repo = AdminRepository();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<AdminUser> _users = const [];
  List<Plan> _plans = const [];
  Map<String, Map<String, dynamic>> _subscriptions = const {};
  String _statusFilter = 'all';
  String _query = '';
  final Set<String> _selected = {};
  int _transactionsCount = 0;
  int _goalsCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.listUsersWithStatus(),
        _repo.listPlans(),
        _repo.listSubscriptions(),
        _repo.countRows('transactions'),
        _repo.countRows('goals'),
      ]);
      final users = results[0] as List<AdminUser>;
      final plans = (results[1] as List<Plan>)
          .where((plan) => plan.isActive)
          .toList();
      final subs = <String, Map<String, dynamic>>{
        for (final sub in results[2] as List<Map<String, dynamic>>)
          '${sub['user_id']}': sub,
      };
      if (!mounted) return;
      setState(() {
        _users = users;
        _plans = plans;
        _subscriptions = subs;
        _transactionsCount = results[3] as int;
        _goalsCount = results[4] as int;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os usuários.';
        _loading = false;
      });
    }
  }

  List<AdminUser> get _filtered {
    final query = _query.trim().toLowerCase();
    return _users.where((user) {
      if (_statusFilter != 'all' && user.effectiveStatus != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return user.displayName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _deleteUser(AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir usuário?'),
        content: Text(
          'Todos os dados de ${user.displayName} serão removidos permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.adminDeleteUser(user.id);
      if (!mounted) return;
      setState(() => _users = _users.where((u) => u.id != user.id).toList());
      showAdminSnack(context, 'Usuário excluído.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao excluir o usuário.', error: true);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir usuários selecionados?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selected.length} usuário(s) e todos os seus dados serão '
              'removidos permanentemente.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Sua senha'),
            ),
          ],
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
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyPassword(passwordController.text);
    if (!ok) {
      if (!mounted) return;
      showAdminSnack(context, 'Senha incorreta.', error: true);
      return;
    }

    final ids = Set<String>.from(_selected);
    var success = 0;
    var failed = 0;
    for (final id in ids) {
      try {
        await _repo.adminDeleteUser(id);
        success++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _users = _users.where((u) => !ids.contains(u.id)).toList();
      _selected.clear();
    });
    showAdminSnack(
      context,
      '$success usuário(s) excluído(s)${failed > 0 ? ' • $failed falha(s)' : ''}.',
      error: failed > 0,
    );
  }

  Future<void> _editUser(AdminUser user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _UserEditDialog(
        user: user,
        plans: _plans,
        subscription: _subscriptions[user.id],
        repo: _repo,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _impersonate(AdminUser user) async {
    try {
      final profile = await ProfileRepository().fetchProfile(user.id);
      if (!mounted) return;
      if (profile == null) {
        showAdminSnack(context, 'Não foi possível carregar o usuário.',
            error: true);
        return;
      }
      context.read<ImpersonationProvider>().start(profile);
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao acessar como o usuário.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();
    if (_error != null) return AdminError(message: _error!, onRetry: _load);

    final users = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: AdminStatCard(
                  title: 'Transações',
                  value: '$_transactionsCount',
                  icon: Icons.receipt_long_outlined,
                  accent: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminStatCard(
                  title: 'Metas',
                  value: '$_goalsCount',
                  icon: Icons.flag_outlined,
                  accent: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Buscar por nome ou email...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('all', 'Todos', _users.length),
              _filterChip(
                'active',
                'Ativos',
                _users.where((u) => u.effectiveStatus == 'active').length,
              ),
              _filterChip(
                'trial',
                'Trial',
                _users.where((u) => u.effectiveStatus == 'trial').length,
              ),
              _filterChip(
                'expired',
                'Expirados',
                _users.where((u) => u.effectiveStatus == 'expired').length,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: users.isNotEmpty &&
                    users.every((u) => _selected.contains(u.id)),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selected.addAll(users.map((u) => u.id));
                  } else {
                    _selected.clear();
                  }
                }),
              ),
              const Text('Selecionar todos'),
              const Spacer(),
              if (_selected.isNotEmpty)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text('Excluir (${_selected.length})'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (users.isEmpty)
            const AdminEmpty(message: 'Nenhum usuário encontrado.')
          else
            for (final user in users)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _UserTile(
                  user: user,
                  selected: _selected.contains(user.id),
                  onToggleSelect: () => setState(() {
                    if (!_selected.add(user.id)) _selected.remove(user.id);
                  }),
                  onEdit: () => _editUser(user),
                  onDelete: () => _deleteUser(user),
                  onImpersonate: () => _impersonate(user),
                ),
              ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, int count) {
    return FilterChip(
      selected: _statusFilter == value,
      label: Text('$label ($count)'),
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.selected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onImpersonate,
  });

  final AdminUser user;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onImpersonate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = user.effectiveStatus;
    final color = _statusColor(status);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (_) => onToggleSelect(),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : 'U',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                AdminStatusBadge(label: _statusLabel(status), color: color),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Acessar como',
            onPressed: onImpersonate,
            icon: const Icon(Icons.visibility_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Excluir',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline,
                size: 20, color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Ativo';
      case 'trial':
        return 'Trial';
      case 'expired':
        return 'Expirado';
      case 'canceled':
        return 'Cancelado';
      case 'past_due':
        return 'Inadimplente';
      default:
        return status;
    }
  }

  static Color _statusColor(String status) {
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

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({
    required this.user,
    required this.plans,
    required this.subscription,
    required this.repo,
  });

  final AdminUser user;
  final List<Plan> plans;
  final Map<String, dynamic>? subscription;
  final AdminRepository repo;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late String _subscriptionStatus;
  String? _planId;
  late String _gateway;
  DateTime? _trialEndsAt;
  DateTime? _periodEnd;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name ?? '');
    _emailController = TextEditingController(text: widget.user.email);
    _subscriptionStatus = widget.user.subscriptionStatus;
    _planId = widget.subscription?['plan_id'] as String?;
    _gateway = (widget.subscription?['gateway'] as String?) ?? 'manual';
    _trialEndsAt = widget.user.trialEndsAt;
    _periodEnd = widget.subscription?['current_period_end'] != null
        ? DateTime.tryParse('${widget.subscription!['current_period_end']}')
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool trial) async {
    final initial = (trial ? _trialEndsAt : _periodEnd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (trial) {
        _trialEndsAt = picked;
      } else {
        _periodEnd = picked;
      }
    });
  }

  DateTime? _computedPeriodEnd() {
    if (_periodEnd != null) return _periodEnd;
    if (_planId == null) return null;
    Plan? plan;
    for (final item in widget.plans) {
      if (item.id == _planId) {
        plan = item;
        break;
      }
    }
    if (plan == null) return null;
    final now = DateTime.now();
    switch (plan.recurrence) {
      case 'yearly':
        return DateTime(now.year + 1, now.month, now.day);
      case 'semiannually':
        return DateTime(now.year, now.month + 6, now.day);
      case 'quarterly':
        return DateTime(now.year, now.month + 3, now.day);
      default:
        return DateTime(now.year, now.month + 1, now.day);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      showAdminSnack(context, 'Informe nome e email.', error: true);
      return;
    }
    if (_subscriptionStatus == 'trial' && _trialEndsAt == null) {
      showAdminSnack(context, 'Informe a data de expiração do trial.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repo.adminUpdateProfile(
        userId: widget.user.id,
        name: name,
        email: email,
        subscriptionStatus: _subscriptionStatus,
        trialEndsAt: _trialEndsAt,
      );

      if (_planId != null) {
        await widget.repo.adminUpsertSubscription(
          userId: widget.user.id,
          planId: _planId,
          status: _subscriptionStatus == 'trial' ? 'trial' : 'active',
          currentPeriodEnd: _computedPeriodEnd(),
          gateway: _gateway,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAdminSnack(context, 'Erro ao salvar as alterações.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar ${widget.user.displayName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _subscriptionStatus,
                decoration: const InputDecoration(labelText: 'Status da assinatura'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Ativo')),
                  DropdownMenuItem(value: 'trial', child: Text('Trial')),
                  DropdownMenuItem(value: 'expired', child: Text('Expirado')),
                  DropdownMenuItem(value: 'canceled', child: Text('Cancelado')),
                  DropdownMenuItem(value: 'past_due', child: Text('Pagamento pendente')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inativo')),
                ],
                onChanged: (value) =>
                    setState(() => _subscriptionStatus = value ?? 'active'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _planId,
                decoration: const InputDecoration(labelText: 'Plano'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem plano')),
                  for (final plan in widget.plans)
                    DropdownMenuItem(
                      value: plan.id,
                      child: Text('${plan.name} • ${plan.recurrenceLabel}'),
                    ),
                ],
                onChanged: (value) => setState(() => _planId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gateway,
                decoration: const InputDecoration(labelText: 'Gateway'),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Manual/Gratuito')),
                  DropdownMenuItem(value: 'stripe', child: Text('Stripe')),
                  DropdownMenuItem(value: 'mercadopago', child: Text('Mercado Pago')),
                ],
                onChanged: (value) => setState(() => _gateway = value ?? 'manual'),
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Expiração do trial',
                value: _trialEndsAt,
                onTap: () => _pickDate(true),
              ),
              const SizedBox(height: 8),
              _DateField(
                label: 'Expiração do plano',
                value: _periodEnd,
                onTap: () => _pickDate(false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null
                    ? 'Não definida'
                    : '${value!.day.toString().padLeft(2, '0')}/'
                        '${value!.month.toString().padLeft(2, '0')}/${value!.year}',
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}
