import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../repositories/admin_repository.dart';
import '../../../../widgets/app_card.dart';
import '../../widgets/admin_widgets.dart';

/// Gerenciamento de webhooks (recebimento, envio, logs e lembretes).
class AdminWebhooksSection extends StatefulWidget {
  const AdminWebhooksSection({super.key});

  @override
  State<AdminWebhooksSection> createState() => _AdminWebhooksSectionState();
}

class _AdminWebhooksSectionState extends State<AdminWebhooksSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Recebimento'),
            Tab(text: 'Envio'),
            Tab(text: 'Logs'),
            Tab(text: 'Contas Fixas'),
            Tab(text: 'Instruções'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _IncomingTab(),
              _OutgoingTab(),
              _LogsTab(),
              _BillRemindersTab(),
              _InstructionsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstructionsTab extends StatelessWidget {
  const _InstructionsTab();

  static const _actions = [
    ('transaction', 'Criar transação', 'amount, type, description'),
    ('update_transaction', 'Atualizar transação', 'transactionId + campos'),
    ('delete_transaction', 'Excluir transação', 'transactionId'),
    ('goal', 'Criar meta', 'title, targetAmount'),
    ('update_goal', 'Atualizar meta', 'goalId + campos'),
    ('delete_goal', 'Excluir meta', 'goalId'),
    ('notification', 'Enviar notificação', 'title, body'),
    ('create_user', 'Criar usuário', 'email, name'),
    ('subscription', 'Atualizar assinatura', 'status'),
    ('payment', 'Registrar pagamento', 'amount, status'),
    ('category', 'Criar categoria', 'name, type'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receiverUrl =
        '${AppConfig.supabaseUrl}/functions/v1/webhook-receiver';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AdminSectionCard(
          title: 'URL de recebimento (POST)',
          child: SelectableText(receiverUrl),
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          title: 'Ações suportadas',
          child: Column(
            children: [
              for (final action in _actions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          action.$1,
                          style: TextStyle(
                            fontSize: 11,
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
                            Text(action.$2, style: theme.textTheme.bodyMedium),
                            Text(
                              action.$3,
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
          ),
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          title: 'Identificação e segurança',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• Identifique o usuário por e-mail (contém "@"), por '
                'profiles.whatsapp ou por um campo customizado configurado na '
                'aba Recebimento.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                '• Requisições podem ser validadas pelo header '
                'x-webhook-signature com o segredo configurado.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _systemEvents = [
  ('transaction.created', 'Transação criada'),
  ('transaction.updated', 'Transação atualizada'),
  ('transaction.deleted', 'Transação excluída'),
  ('goal.created', 'Meta criada'),
  ('goal.completed', 'Meta concluída'),
  ('goal.updated', 'Meta atualizada'),
  ('goal.deleted', 'Meta excluída'),
  ('bill.reminder.due', 'Lembrete de conta'),
  ('user.registered', 'Usuário registrado'),
  ('subscription.changed', 'Assinatura alterada'),
  ('payment.processed', 'Pagamento processado'),
  ('category.created', 'Categoria criada'),
  ('notification.sent', 'Notificação enviada'),
  ('report.generated', 'Relatório gerado'),
  ('category.budget.exceeded', 'Orçamento excedido'),
  ('trial.expiring', 'Trial expirando'),
  ('alert.custom', 'Alerta customizado'),
];

class _IncomingTab extends StatefulWidget {
  const _IncomingTab();

  @override
  State<_IncomingTab> createState() => _IncomingTabState();
}

class _IncomingTabState extends State<_IncomingTab> {
  final _repo = AdminRepository();
  final _identifierController = TextEditingController();
  final _secretController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  String get _receiverUrl =>
      '${AppConfig.supabaseUrl}/functions/v1/webhook-receiver';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await _repo.fetchWebhookConfig();
      if (config != null) {
        _identifierController.text = '${config['user_identifier'] ?? 'userId'}';
        _secretController.text = '${config['incoming_secret'] ?? ''}';
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
      await _repo.saveWebhookConfig({
        'user_identifier': _identifierController.text.trim(),
        'incoming_secret': _secretController.text.trim(),
      });
      if (!mounted) return;
      showAdminSnack(context, 'Configuração salva.');
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
          title: 'URL de recebimento',
          subtitle: 'Envie eventos para esta URL via POST.',
          trailing: IconButton(
            tooltip: 'Copiar',
            onPressed: () {
              showAdminSnack(context, 'URL: $_receiverUrl');
            },
            icon: const Icon(Icons.copy, size: 18),
          ),
          child: SelectableText(_receiverUrl),
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          title: 'Identificação',
          child: Column(
            children: [
              TextField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: 'Campo de identificação do usuário',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Segredo de validação',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Salvar Configuração'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutgoingTab extends StatefulWidget {
  const _OutgoingTab();

  @override
  State<_OutgoingTab> createState() => _OutgoingTabState();
}

class _OutgoingTabState extends State<_OutgoingTab> {
  final _repo = AdminRepository();
  final _urlController = TextEditingController();
  final _secretController = TextEditingController();
  final Set<String> _enabledEvents = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await _repo.fetchWebhookConfig();
      if (config != null) {
        _urlController.text = '${config['response_url'] ?? ''}';
        _secretController.text = '${config['outgoing_secret'] ?? ''}';
        final events = config['enabled_events'];
        if (events is List) {
          _enabledEvents.addAll(events.map((e) => e.toString()));
        }
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
      await _repo.saveWebhookConfig({
        'response_url': _urlController.text.trim(),
        'outgoing_secret': _secretController.text.trim(),
        'enabled_events': _enabledEvents.toList(),
      });
      if (!mounted) return;
      showAdminSnack(context, 'Configuração salva.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao salvar.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showAdminSnack(context, 'Informe a URL do webhook.', error: true);
      return;
    }
    try {
      await _repo.testWebhookSender(
        url: url,
        secret: _secretController.text.trim(),
      );
      if (!mounted) return;
      showAdminSnack(context, 'Teste enviado.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Falha no teste.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AdminSectionCard(
          title: 'Webhook de saída',
          child: Column(
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL do webhook externo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _secretController,
                decoration: const InputDecoration(labelText: 'Chave secreta'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _test,
                      child: const Text('Testar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          title: 'Eventos habilitados',
          child: Column(
            children: [
              for (final event in _systemEvents)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _enabledEvents.contains(event.$1),
                  title: Text(event.$2),
                  subtitle: Text(event.$1),
                  onChanged: (value) => setState(() {
                    if (value) {
                      _enabledEvents.add(event.$1);
                    } else {
                      _enabledEvents.remove(event.$1);
                    }
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogsTab extends StatefulWidget {
  const _LogsTab();

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  final _repo = AdminRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _logs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await _repo.listWebhookLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
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
          if (_logs.isEmpty)
            const AdminEmpty(message: 'Nenhum log de webhook registrado.')
          else
            for (final log in _logs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            log['direction'] == 'incoming'
                                ? Icons.call_received
                                : Icons.call_made,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${log['event_type'] ?? 'evento'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          AdminStatusBadge(
                            label: '${log['status'] ?? '-'}',
                            color: '${log['status']}'.toLowerCase().contains('success')
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${log['url'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        adminDateTime(log['created_at']),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
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

class _BillRemindersTab extends StatefulWidget {
  const _BillRemindersTab();

  @override
  State<_BillRemindersTab> createState() => _BillRemindersTabState();
}

class _BillRemindersTabState extends State<_BillRemindersTab> {
  final _repo = AdminRepository();
  bool _triggering = false;

  Future<void> _trigger() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final date =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    setState(() => _triggering = true);
    try {
      await _repo.triggerBillReminders(date);
      if (!mounted) return;
      showAdminSnack(context, 'Lembretes de contas disparados.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Falha ao disparar os lembretes.', error: true);
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AdminSectionCard(
          title: 'Lembretes de Contas Fixas',
          subtitle:
              'Dispara o evento bill.reminder.due para contas que vencem amanhã.',
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _triggering ? null : _trigger,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Disparar Agora'),
            ),
          ),
        ),
      ],
    );
  }
}
