import 'package:flutter/material.dart';

import '../../../../models/admin_user.dart';
import '../../../../repositories/admin_repository.dart';
import '../../../../widgets/app_card.dart';
import '../../widgets/admin_widgets.dart';

/// Gerenciamento do conteúdo educacional.
class AdminEducationSection extends StatefulWidget {
  const AdminEducationSection({super.key});

  @override
  State<AdminEducationSection> createState() => _AdminEducationSectionState();
}

class _AdminEducationSectionState extends State<AdminEducationSection> {
  final _repo = AdminRepository();
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  String _statusFilter = 'all';
  String _query = '';
  DateTimeRange? _range;

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

  List<Map<String, dynamic>> get _filtered {
    final query = _query.trim().toLowerCase();
    return _items.where((item) {
      if (_statusFilter != 'all' && '${item['status']}' != _statusFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final title = '${item['title']}'.toLowerCase();
        final description = '${item['description']}'.toLowerCase();
        if (!title.contains(query) && !description.contains(query)) return false;
      }
      if (_range != null) {
        final published = DateTime.tryParse('${item['published_at']}');
        if (published == null) return false;
        final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59);
        if (published.isBefore(_range!.start) || published.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.listEducationContent();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o conteúdo.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EducationFormDialog(item: item, repo: _repo),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conteúdo?'),
        content: Text('"${item['title']}" será removido.'),
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
      await _repo.deleteEducationContent(item['id'] as String);
      if (!mounted) return;
      showAdminSnack(context, 'Conteúdo excluído.');
      _load();
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao excluir.', error: true);
    }
  }

  Future<void> _showClicks(Map<String, dynamic> item) async {
    try {
      final results = await Future.wait([
        _repo.listEducationClicks(item['id'] as String),
        _repo.listProfiles(),
      ]);
      final clicks = (results[0] as List).cast<Map<String, dynamic>>();
      final profiles = results[1] as List<AdminUser>;
      final names = {for (final profile in profiles) profile.id: profile.displayName};
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cliques • ${item['title']}'),
          content: SizedBox(
            width: 420,
            child: clicks.isEmpty
                ? const AdminEmpty(message: 'Nenhum clique registrado.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final click in clicks)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.touch_app_outlined),
                          title: Text(
                            names[click['user_id']] ?? 'Anônimo',
                          ),
                          subtitle: Text(adminDateTime(click['clicked_at'])),
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
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao carregar os cliques.', error: true);
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
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Conteúdo'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Buscar por título ou descrição...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                selected: _statusFilter == 'all',
                label: const Text('Todos'),
                onSelected: (_) => setState(() => _statusFilter = 'all'),
              ),
              FilterChip(
                selected: _statusFilter == 'Ativo',
                label: const Text('Ativos'),
                onSelected: (_) => setState(() => _statusFilter = 'Ativo'),
              ),
              FilterChip(
                selected: _statusFilter == 'Inativo',
                label: const Text('Inativos'),
                onSelected: (_) => setState(() => _statusFilter = 'Inativo'),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _range == null
                      ? 'Período'
                      : '${_range!.start.day}/${_range!.start.month} - ${_range!.end.day}/${_range!.end.month}',
                ),
                onPressed: _pickRange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_filtered.isEmpty)
            const AdminEmpty(message: 'Nenhum conteúdo encontrado.')
          else
            for (final item in _filtered)
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
                              '${item['title']}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AdminStatusBadge(
                            label: '${item['status'] ?? 'Ativo'}',
                            color: item['status'] == 'Ativo'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['type']} • ${adminDate(item['published_at'])} • ${item['clicks'] ?? 0} cliques',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _showClicks(item),
                            child: const Text('Cliques'),
                          ),
                          TextButton.icon(
                            onPressed: () => _openForm(item),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar'),
                          ),
                          TextButton.icon(
                            onPressed: () => _delete(item),
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

class _EducationFormDialog extends StatefulWidget {
  const _EducationFormDialog({this.item, required this.repo});

  final Map<String, dynamic>? item;
  final AdminRepository repo;

  @override
  State<_EducationFormDialog> createState() => _EducationFormDialogState();
}

class _EducationFormDialogState extends State<_EducationFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkController;
  late final TextEditingController _coverController;
  late String _type;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: '${item?['title'] ?? ''}');
    _descriptionController =
        TextEditingController(text: '${item?['description'] ?? ''}');
    _linkController = TextEditingController(text: '${item?['link'] ?? ''}');
    _coverController =
        TextEditingController(text: '${item?['cover_image'] ?? ''}');
    _type = '${item?['type'] ?? 'Artigo'}';
    _status = '${item?['status'] ?? 'Ativo'}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final link = _linkController.text.trim();
    if (title.isEmpty || description.isEmpty || link.isEmpty) {
      showAdminSnack(context, 'Preencha título, descrição e link.', error: true);
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme) {
      showAdminSnack(context, 'Informe um link válido.', error: true);
      return;
    }

    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'type': _type,
      'status': _status,
      'link': link,
      'cover_image': _coverController.text.trim(),
    };

    setState(() => _saving = true);
    try {
      if (widget.item != null) {
        await widget.repo
            .updateEducationContent(widget.item!['id'] as String, payload);
      } else {
        await widget.repo.createEducationContent(payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAdminSnack(context, 'Erro ao salvar o conteúdo.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Novo Conteúdo' : 'Editar Conteúdo'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'Artigo', child: Text('Artigo')),
                  DropdownMenuItem(value: 'Vídeo', child: Text('Vídeo')),
                  DropdownMenuItem(
                      value: 'Link Externo', child: Text('Link Externo')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'Artigo'),
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
              const SizedBox(height: 12),
              TextField(
                controller: _linkController,
                decoration: const InputDecoration(labelText: 'Link/URL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _coverController,
                decoration:
                    const InputDecoration(labelText: 'URL da imagem de capa'),
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
