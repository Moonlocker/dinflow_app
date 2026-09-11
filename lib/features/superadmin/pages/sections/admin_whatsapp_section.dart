import 'package:flutter/material.dart';

import '../../../../repositories/admin_repository.dart';
import '../../../../widgets/app_card.dart';
import '../../../../widgets/empty_state.dart';
import '../../widgets/admin_widgets.dart';

/// Central de conversas do WhatsApp (agrupadas por número).
class AdminWhatsAppSection extends StatefulWidget {
  const AdminWhatsAppSection({super.key});

  @override
  State<AdminWhatsAppSection> createState() => _AdminWhatsAppSectionState();
}

class _AdminWhatsAppSectionState extends State<AdminWhatsAppSection> {
  final _repo = AdminRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _messages = const [];
  Map<String, String> _names = const {};
  Map<String, String> _userIds = const {};

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
        _repo.listWhatsAppMessages(),
        _repo.listWhatsAppContacts(),
      ]);
      final messages = results[0];
      final contacts = results[1];
      final names = <String, String>{};
      final userIds = <String, String>{};
      for (final contact in contacts) {
        final whatsapp = contact['whatsapp'];
        if (whatsapp != null) {
          final key = _normalize('$whatsapp');
          names[key] = '${contact['name'] ?? contact['email']}';
          userIds[key] = '${contact['id']}';
        }
      }
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _names = names;
        _userIds = userIds;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as conversas.';
        _loading = false;
      });
    }
  }

  String _normalize(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('55')) {
      return '${digits.substring(0, 4)}${digits.substring(5)}';
    }
    return digits;
  }

  List<_Conversation> get _conversations {
    final map = <String, _Conversation>{};
    for (final message in _messages) {
      final key = _normalize('${message['whatsapp']}');
      final existing = map[key];
      final timestamp = DateTime.tryParse('${message['timestamp']}');
      if (existing == null) {
        map[key] = _Conversation(
          number: '${message['whatsapp']}',
          key: key,
          name: _names[key],
          userId: _userIds[key],
          lastMessage: '${message['content'] ?? ''}',
          lastTimestamp: timestamp,
        );
      } else if (timestamp != null &&
          (existing.lastTimestamp == null ||
              timestamp.isAfter(existing.lastTimestamp!))) {
        existing.lastMessage = '${message['content'] ?? ''}';
        existing.lastTimestamp = timestamp;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => (b.lastTimestamp ?? DateTime(2000))
          .compareTo(a.lastTimestamp ?? DateTime(2000)));
    return list;
  }

  Future<void> _openChat(_Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChatPage(
          conversation: conversation,
          repo: _repo,
          normalize: _normalize,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();
    if (_error != null) return AdminError(message: _error!, onRetry: _load);

    final conversations = _conversations;

    return RefreshIndicator(
      onRefresh: _load,
      child: conversations.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.chat_bubble_outline,
                  message: 'Nenhuma conversa registrada.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => _openChat(conversation),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                          child: const Icon(Icons.person_outline, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conversation.name ?? conversation.number,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                conversation.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Excluir conversa',
                          onPressed: () async {
                            await _repo
                                .deleteWhatsAppChat(conversation.number);
                            _load();
                          },
                          icon: Icon(Icons.delete_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Conversation {
  _Conversation({
    required this.number,
    required this.key,
    this.name,
    this.userId,
    required this.lastMessage,
    this.lastTimestamp,
  });

  final String number;
  final String key;
  final String? name;
  final String? userId;
  String lastMessage;
  DateTime? lastTimestamp;
}

class _ChatPage extends StatefulWidget {
  const _ChatPage({
    required this.conversation,
    required this.repo,
    required this.normalize,
  });

  final _Conversation conversation;
  final AdminRepository repo;
  final String Function(String) normalize;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _messages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await widget.repo.listWhatsAppMessages();
      final filtered = all
          .where((message) =>
              widget.normalize('${message['whatsapp']}') == widget.conversation.key)
          .toList()
        ..sort((a, b) => '${a['timestamp']}'.compareTo('${b['timestamp']}'));
      if (!mounted) return;
      setState(() {
        _messages = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.repo.sendWhatsAppMessage(
        to: widget.conversation.number,
        message: text,
      );
      _controller.clear();
      await _load();
      if (!mounted) return;
      showAdminSnack(context, 'Mensagem enviada.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Falha ao enviar a mensagem.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editUser() async {
    final userId = widget.conversation.userId;
    if (userId == null) return;
    final nameController = TextEditingController(text: widget.conversation.name ?? '');
    final emailController = TextEditingController();
    final whatsappController =
        TextEditingController(text: widget.conversation.number);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar usuário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: whatsappController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repo.updateUserContact(
        userId: userId,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        whatsapp: whatsappController.text.trim(),
      );
      if (!mounted) return;
      showAdminSnack(context, 'Usuário atualizado.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao atualizar o usuário.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.name ?? widget.conversation.number),
        actions: [
          if (widget.conversation.userId != null)
            IconButton(
              tooltip: 'Editar usuário',
              onPressed: _editUser,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('Nenhuma mensagem.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final outgoing = message['direction'] == 'outgoing';
                          return Align(
                            alignment: outgoing
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              constraints: const BoxConstraints(maxWidth: 280),
                              decoration: BoxDecoration(
                                color: outgoing
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${message['content'] ?? ''}',
                                    style: TextStyle(
                                      color: outgoing
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    adminDateTime(message['timestamp']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: outgoing
                                          ? theme.colorScheme.onPrimary
                                              .withValues(alpha: 0.8)
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Digite uma mensagem...',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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
