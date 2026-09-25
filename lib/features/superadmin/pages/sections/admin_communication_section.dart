import 'package:flutter/material.dart';

import '../../../../repositories/admin_repository.dart';
import '../../widgets/admin_widgets.dart';

/// Central de comunicação: e-mail e notificações.
class AdminCommunicationSection extends StatefulWidget {
  const AdminCommunicationSection({super.key});

  @override
  State<AdminCommunicationSection> createState() =>
      _AdminCommunicationSectionState();
}

class _AdminCommunicationSectionState extends State<AdminCommunicationSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          tabs: const [
            Tab(text: 'E-mail', icon: Icon(Icons.mail_outline, size: 18)),
            Tab(text: 'Notificação', icon: Icon(Icons.notifications_none, size: 18)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_EmailTab(), _NotificationTab()],
          ),
        ),
      ],
    );
  }
}

class _EmailTab extends StatefulWidget {
  const _EmailTab();

  @override
  State<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<_EmailTab> {
  final _repo = AdminRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _templates = const [];
  List<Map<String, dynamic>> _history = const [];

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
        _repo.listEmailTemplates(),
        _repo.listEmailHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _templates = results[0];
        _history = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os e-mails.';
        _loading = false;
      });
    }
  }

  Future<void> _openTemplate([Map<String, dynamic>? template]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _TemplateDialog(
        title: 'Template de E-mail',
        subjectLabel: 'Assunto',
        bodyLabel: 'Corpo do E-mail',
        template: template,
        onSave: (values) => _repo.upsertEmailTemplate({
          if (template != null) 'id': template['id'],
          ...values,
          if (template == null)
            'key': 'custom_${DateTime.now().millisecondsSinceEpoch}',
          if (template == null) 'is_default': false,
        }),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _send() async {
    final recipients = await _repo.listRecipients();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _SendDialog(
        templates: _templates,
        recipients: recipients,
        titleLabel: 'Assunto',
        bodyLabel: 'Corpo do E-mail',
        onSend: (subject, body, selected) async {
          final history = await _repo.insertEmailHistoryReturning({
            'subject': subject,
            'body': body,
            'recipients_count': selected.length,
            'status': 'Agendado',
            'provider': 'smtp',
            'sent_at': DateTime.now().toIso8601String(),
          });
          final historyId = history?['id'] as String?;
          try {
            await _repo.sendEmail(
              subject: subject,
              body: body,
              recipients: selected,
              historyId: historyId,
            );
            if (historyId != null) {
              await _repo.updateEmailHistory(historyId, {'status': 'Enviado'});
            }
          } catch (_) {
            if (historyId != null) {
              await _repo.updateEmailHistory(historyId, {'status': 'Falhou'});
            }
            rethrow;
          }
        },
      ),
    );
    if (result == true) _load();
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
                child: FilledButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Enviar E-mail'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openTemplate(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Template'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminSectionCard(
            title: 'Templates',
            child: _templates.isEmpty
                ? const AdminEmpty(message: 'Nenhum template cadastrado.')
                : Column(
                    children: [
                      for (final template in _templates)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${template['subject']}'),
                          subtitle: (template['is_default'] == true)
                              ? const Text('Padrão')
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _openTemplate(template),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                              if (template['is_default'] != true)
                                IconButton(
                                  onPressed: () async {
                                    await _repo.deleteEmailTemplate(
                                        template['id'] as String);
                                    _load();
                                  },
                                  icon: Icon(Icons.delete_outline,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.error),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          AdminSectionCard(
            title: 'Histórico',
            child: _history.isEmpty
                ? const AdminEmpty(message: 'Nenhum envio registrado.')
                : Column(
                    children: [
                      for (final item in _history)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${item['subject']}'),
                          subtitle: Text(
                            '${item['status']} • ${adminDateTime(item['sent_at'])} • ${item['recipients_count']} destinatários',
                          ),
                          trailing: IconButton(
                            onPressed: () async {
                              await _repo
                                  .deleteEmailHistory(item['id'] as String);
                              _load();
                            },
                            icon: Icon(Icons.delete_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTab extends StatefulWidget {
  const _NotificationTab();

  @override
  State<_NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<_NotificationTab> {
  final _repo = AdminRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _templates = const [];
  List<Map<String, dynamic>> _history = const [];

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
        _repo.listNotificationTemplates(),
        _repo.listNotificationHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _templates = results[0];
        _history = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as notificações.';
        _loading = false;
      });
    }
  }

  Future<void> _openTemplate([Map<String, dynamic>? template]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _TemplateDialog(
        title: 'Template de Notificação',
        subjectLabel: 'Título',
        bodyLabel: 'Corpo da Notificação',
        template: template,
        onSave: (values) => _repo.upsertNotificationTemplate({
          if (template != null) 'id': template['id'],
          'title': values['subject'],
          'body': values['body'],
          if (template == null)
            'key': 'custom_notification_${DateTime.now().millisecondsSinceEpoch}',
          if (template == null) 'is_default': false,
        }),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _send() async {
    final recipients = await _repo.listRecipients();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _SendDialog(
        templates: _templates,
        recipients: recipients,
        titleLabel: 'Título',
        bodyLabel: 'Corpo da Notificação',
        onSend: (title, body, selected) async {
          final history = await _repo.insertNotificationHistory({
            'title': title,
            'body': body,
            'recipients_count': selected.length,
            'status': 'Agendada',
            'sent_at': DateTime.now().toIso8601String(),
          });
          final historyId = history?['id'] as String?;
          try {
            await _repo.sendNotification(
              title: title,
              body: body,
              recipients: selected,
              historyId: historyId,
            );
            if (historyId != null) {
              await _repo.updateNotificationHistory(
                historyId,
                {'status': 'Enviada'},
              );
            }
          } catch (_) {
            if (historyId != null) {
              await _repo.updateNotificationHistory(
                historyId,
                {'status': 'Falhou'},
              );
            }
            rethrow;
          }
        },
      ),
    );
    if (result == true) _load();
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
                child: FilledButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Enviar Notificação'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openTemplate(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Template'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdminSectionCard(
            title: 'Templates',
            child: _templates.isEmpty
                ? const AdminEmpty(message: 'Nenhum template cadastrado.')
                : Column(
                    children: [
                      for (final template in _templates)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${template['title']}'),
                          subtitle: (template['is_default'] == true)
                              ? const Text('Padrão')
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _openTemplate(template),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                              if (template['is_default'] != true)
                                IconButton(
                                  onPressed: () async {
                                    await _repo.deleteNotificationTemplate(
                                        template['id'] as String);
                                    _load();
                                  },
                                  icon: Icon(Icons.delete_outline,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.error),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          AdminSectionCard(
            title: 'Histórico',
            child: _history.isEmpty
                ? const AdminEmpty(message: 'Nenhum envio registrado.')
                : Column(
                    children: [
                      for (final item in _history)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${item['title']}'),
                          subtitle: Text(
                            '${item['status']} • ${adminDateTime(item['sent_at'])} • ${item['recipients_count']} destinatários',
                          ),
                          trailing: IconButton(
                            onPressed: () async {
                              await _repo.deleteNotificationHistory(
                                  item['id'] as String);
                              _load();
                            },
                            icon: Icon(Icons.delete_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({
    required this.title,
    required this.subjectLabel,
    required this.bodyLabel,
    required this.template,
    required this.onSave,
  });

  final String title;
  final String subjectLabel;
  final String bodyLabel;
  final Map<String, dynamic>? template;
  final Future<void> Function(Map<String, dynamic> values) onSave;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _subjectController = TextEditingController(
        text: '${template?['subject'] ?? template?['title'] ?? ''}');
    _bodyController =
        TextEditingController(text: '${template?['body'] ?? ''}');
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_subjectController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      showAdminSnack(context, 'Preencha todos os campos.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'subject': _subjectController.text.trim(),
        'body': _bodyController.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAdminSnack(context, 'Erro ao salvar.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(labelText: widget.subjectLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 6,
              decoration: InputDecoration(labelText: widget.bodyLabel),
            ),
          ],
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

class _SendDialog extends StatefulWidget {
  const _SendDialog({
    required this.templates,
    required this.recipients,
    required this.titleLabel,
    required this.bodyLabel,
    required this.onSend,
  });

  final List<Map<String, dynamic>> templates;
  final List<Map<String, dynamic>> recipients;
  final String titleLabel;
  final String bodyLabel;
  final Future<void> Function(
    String subject,
    String body,
    List<Map<String, dynamic>> recipients,
  ) onSend;

  @override
  State<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<_SendDialog> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  String _filter = 'all';
  final Set<String> _selectedIds = {};
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredRecipients {
    if (_filter == 'all') return widget.recipients;
    if (_filter == 'custom') {
      return widget.recipients
          .where((item) => _selectedIds.contains('${item['id']}'))
          .toList();
    }
    return widget.recipients
        .where((item) => item['subscription_status'] == _filter)
        .toList();
  }

  Future<void> _send() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      showAdminSnack(context, 'Preencha título e corpo.', error: true);
      return;
    }
    final selected = _filteredRecipients
        .map((item) => {
              'email': item['email'],
              'name': item['name'] ?? item['email'],
              'user_id': item['id'],
            })
        .toList();
    if (selected.isEmpty) {
      showAdminSnack(context, 'Nenhum destinatário selecionado.', error: true);
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.onSend(subject, body, selected);
      if (!mounted) return;
      Navigator.pop(context, true);
      showAdminSnack(context, 'Envio realizado.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAdminSnack(context, 'Erro ao enviar.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Envio'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.templates.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Template'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Nenhum')),
                    for (final template in widget.templates)
                      DropdownMenuItem(
                        value: '${template['id']}',
                        child: Text(
                          '${template['subject'] ?? template['title']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    for (final template in widget.templates) {
                      if ('${template['id']}' == value) {
                        _subjectController.text =
                            '${template['subject'] ?? template['title'] ?? ''}';
                        _bodyController.text = '${template['body'] ?? ''}';
                      }
                    }
                    setState(() {});
                  },
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _filter,
                decoration: const InputDecoration(labelText: 'Destinatários'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Todos')),
                  DropdownMenuItem(value: 'active', child: Text('Ativos')),
                  DropdownMenuItem(value: 'trial', child: Text('Trial')),
                  DropdownMenuItem(value: 'expired', child: Text('Expirados')),
                  DropdownMenuItem(value: 'custom', child: Text('Selecionar usuários')),
                ],
                onChanged: (value) => setState(() => _filter = value ?? 'all'),
              ),
              if (_filter == 'custom') ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: ListView(
                    children: [
                      for (final recipient in widget.recipients)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _selectedIds.contains('${recipient['id']}'),
                          title: Text(
                            '${recipient['name'] ?? recipient['email']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (value) => setState(() {
                            final id = '${recipient['id']}';
                            if (value == true) {
                              _selectedIds.add(id);
                            } else {
                              _selectedIds.remove(id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _subjectController,
                decoration: InputDecoration(labelText: widget.titleLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                maxLines: 5,
                decoration: InputDecoration(labelText: widget.bodyLabel),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}
