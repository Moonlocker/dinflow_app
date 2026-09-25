import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../models/plan.dart';
import '../../../../repositories/admin_repository.dart';
import '../../../../widgets/app_card.dart';
import '../../widgets/admin_widgets.dart';

/// Gerenciamento de planos de assinatura.
class AdminPlansSection extends StatefulWidget {
  const AdminPlansSection({super.key});

  @override
  State<AdminPlansSection> createState() => _AdminPlansSectionState();
}

class _AdminPlansSectionState extends State<AdminPlansSection> {
  final _repo = AdminRepository();
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  List<Plan> _plans = const [];

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
      final plans = await _repo.listPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
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

  Future<void> _syncAll() async {
    setState(() => _syncing = true);
    try {
      await _repo.syncAllPlans();
      if (!mounted) return;
      showAdminSnack(context, 'Planos sincronizados com o Stripe.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Falha ao sincronizar com o Stripe.', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openForm([Plan? plan]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _PlanFormDialog(plan: plan, repo: _repo),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Plan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir plano?'),
        content: Text('O plano "${plan.name}" será removido.'),
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
      await _repo.deletePlan(plan.id);
      try {
        await _repo.syncPlan(plan.id, 'delete');
      } catch (_) {
        // A exclusão local já ocorreu; a sincronização é best-effort.
      }
      if (!mounted) return;
      showAdminSnack(context, 'Plano excluído.');
      _load();
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao excluir o plano.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();
    if (_error != null) return AdminError(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncing ? null : _syncAll,
                  icon: _syncing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: const Text('Sincronizar Planos'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo Plano'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_plans.isEmpty)
            const AdminEmpty(message: 'Nenhum plano cadastrado ainda.')
          else
            for (final plan in _plans)
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
                              plan.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AdminStatusBadge(
                            label: plan.status,
                            color: plan.isActive
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.isFree
                            ? 'Gratuito'
                            : '${formatCurrency(plan.price)} • ${plan.recurrenceLabel}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'WhatsApp: ${plan.allowWhatsappMessages ? 'permitido' : 'bloqueado'} • '
                        'Números: ${plan.whatsappNumbersLimit} • '
                        'Transações/mês: ${plan.maxTransactionsMonthly == 0 ? 'ilimitadas' : plan.maxTransactionsMonthly}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      if (plan.features.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final feature in plan.features)
                              Chip(
                                label: Text(feature),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _openForm(plan),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar'),
                          ),
                          TextButton.icon(
                            onPressed: () => _delete(plan),
                            icon: Icon(Icons.delete_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.error),
                            label: Text(
                              'Excluir',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
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
}

class _PlanFormDialog extends StatefulWidget {
  const _PlanFormDialog({this.plan, required this.repo});

  final Plan? plan;
  final AdminRepository repo;

  @override
  State<_PlanFormDialog> createState() => _PlanFormDialogState();
}

class _PlanFormDialogState extends State<_PlanFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _limitController;
  late final TextEditingController _maxTransactionsController;
  late String _recurrence;
  late String _status;
  late bool _isFree;
  late bool _allowWhatsapp;
  late List<TextEditingController> _featureControllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _nameController = TextEditingController(text: plan?.name ?? '');
    _priceController =
        TextEditingController(text: plan != null ? plan.price.toStringAsFixed(2) : '');
    _limitController = TextEditingController(
        text: plan != null ? plan.whatsappNumbersLimit.toString() : '0');
    _maxTransactionsController = TextEditingController(
        text: plan != null ? plan.maxTransactionsMonthly.toString() : '0');
    _recurrence = plan?.recurrence ?? 'monthly';
    _status = plan?.status ?? 'Ativo';
    _isFree = plan?.isFree ?? false;
    _allowWhatsapp = plan?.allowWhatsappMessages ?? true;
    _featureControllers = [
      for (final feature in plan?.features ?? const <String>[])
        TextEditingController(text: feature),
    ];
    if (_featureControllers.isEmpty) {
      _featureControllers = [TextEditingController()];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _limitController.dispose();
    _maxTransactionsController.dispose();
    for (final controller in _featureControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (name.isEmpty || price == null) {
      showAdminSnack(context, 'Informe nome e preço válidos.', error: true);
      return;
    }

    final features = _featureControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'name': name,
      'price': price,
      'status': _status,
      'recurrence': _recurrence,
      'features': features,
      'whatsapp_numbers_limit': int.tryParse(_limitController.text) ?? 0,
      'is_free': _isFree,
      'allow_whatsapp_messages': _allowWhatsapp,
      'max_transactions_monthly':
          int.tryParse(_maxTransactionsController.text) ?? 0,
    };

    setState(() => _saving = true);
    try {
      if (widget.plan != null) {
        await widget.repo.updatePlan(widget.plan!.id, payload);
        if (!_isFree) {
          try {
            await widget.repo.syncPlan(widget.plan!.id, 'upsert');
          } catch (_) {}
        }
      } else {
        final id = await widget.repo.createPlan(payload);
        // Plano gratuito não vai para o Stripe (não tem checkout).
        if (!_isFree) {
          try {
            await widget.repo.syncPlan(id, 'upsert');
          } catch (_) {}
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAdminSnack(context, 'Erro ao salvar o plano.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.plan == null ? 'Novo Plano' : 'Editar Plano'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome do plano'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Preço (R\$)',
                  prefixText: 'R\$ ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _recurrence,
                decoration: const InputDecoration(labelText: 'Recorrência'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Mensal')),
                  DropdownMenuItem(value: 'quarterly', child: Text('Trimestral')),
                  DropdownMenuItem(value: 'semiannually', child: Text('Semestral')),
                  DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                ],
                onChanged: (value) =>
                    setState(() => _recurrence = value ?? 'monthly'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Números WhatsApp permitidos (1 = só o principal)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxTransactionsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Limite de transações por mês (0 = ilimitado)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Ativo', child: Text('Ativo')),
                  DropdownMenuItem(value: 'Inativo', child: Text('Inativo')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'Ativo'),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isFree,
                onChanged: (value) => setState(() => _isFree = value),
                title: const Text('Plano gratuito'),
                subtitle: const Text(
                  'Usado como padrão quando o usuário não tem assinatura ativa',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowWhatsapp,
                onChanged: (value) => setState(() => _allowWhatsapp = value),
                title: const Text('Permitir WhatsApp'),
                subtitle: const Text('Lançamentos pela integração de WhatsApp'),
              ),
              const SizedBox(height: 8),
              Text(
                'Funcionalidades',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _featureControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _featureControllers[i],
                          decoration: InputDecoration(
                            hintText: 'Funcionalidade ${i + 1}',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _featureControllers.removeAt(i).dispose();
                        }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(
                  () => _featureControllers.add(TextEditingController()),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar funcionalidade'),
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
