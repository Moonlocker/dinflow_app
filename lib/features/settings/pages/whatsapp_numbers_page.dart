import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/whatsapp_number.dart';
import '../../../repositories/whatsapp_numbers_repository.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../impersonation/providers/impersonation_provider.dart';

/// Gerenciamento dos números de WhatsApp adicionais do usuário.
class WhatsappNumbersPage extends StatefulWidget {
  const WhatsappNumbersPage({super.key});

  @override
  State<WhatsappNumbersPage> createState() => _WhatsappNumbersPageState();
}

class _WhatsappNumbersPageState extends State<WhatsappNumbersPage> {
  final _repo = WhatsappNumbersRepository();
  bool _loading = true;
  List<WhatsappNumber> _numbers = const [];
  int _limit = 1;

  static const _countries = {
    'BR': '+55',
    'US': '+1',
    'PT': '+351',
    'ES': '+34',
    'AR': '+54',
    'MX': '+52',
    'CA': '+1',
    'FR': '+33',
    'DE': '+49',
    'IT': '+39',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _activeUserId() =>
      context.read<ImpersonationProvider>().impersonatedUserId ??
      context.read<AuthProvider>().user?.id;

  String? _activeWhatsapp() =>
      context.read<ImpersonationProvider>().impersonatedProfile?.whatsapp ??
      context.read<AuthProvider>().profile?.whatsapp;

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = _activeUserId();
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _repo.fetch(userId),
        _repo.fetchPlanLimit(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _numbers = results[0] as List<WhatsappNumber>;
        _limit = results[1] as int;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get _canAdd => _numbers.length < (_limit - 1);

  Future<void> _add() async {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    var country = 'BR';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo número'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome/Descrição'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: country,
                decoration: const InputDecoration(labelText: 'País'),
                items: [
                  for (final entry in _countries.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text('${entry.key} (${entry.value})'),
                    ),
                ],
                onChanged: (value) =>
                    setDialogState(() => country = value ?? 'BR'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Número'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final digits = numberController.text.replaceAll(RegExp(r'\D'), '');
                if (name.isEmpty || digits.isEmpty) return;
                final userId = _activeUserId();
                if (userId == null) return;
                final full = '${_countries[country]}$digits';
                await _repo.add(
                  userId: userId,
                  name: name,
                  country: country,
                  whatsapp: full,
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(WhatsappNumber number) async {
    final userId = _activeUserId();
    if (userId == null) return;

    int count = 0;
    try {
      count = await _repo.countTransactions(
        userId: userId,
        authorNumber: number.whatsapp,
      );
    } catch (_) {}
    if (!mounted) return;

    if (count == 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir número?'),
          content: Text('"${number.name}" será removido.'),
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
      await _repo.remove(id: number.id, userId: userId);
      _load();
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transações vinculadas'),
        content: Text(
          'Existem $count transações com este número. O que deseja fazer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text(
              'Excluir transações',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'transfer'),
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (!mounted) return;

    final mainWhatsapp = _activeWhatsapp();
    if (choice == 'transfer' && (mainWhatsapp == null || mainWhatsapp.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número principal não configurado.')),
      );
      return;
    }

    try {
      if (choice == 'transfer') {
        await _repo.transferTransactions(
          userId: userId,
          from: number.whatsapp,
          to: mainWhatsapp!,
        );
      } else {
        await _repo.deleteTransactions(
          userId: userId,
          authorNumber: number.whatsapp,
        );
      }
      await _repo.remove(id: number.id, userId: userId);
      if (!mounted) return;
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número removido.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao remover o número.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mainWhatsapp = _activeWhatsapp();

    return Scaffold(
      appBar: AppBar(title: const Text('Números de WhatsApp')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _canAdd ? _add : null,
        backgroundColor: _canAdd ? null : theme.disabledColor,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Número principal',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              mainWhatsapp ?? 'Não configurado',
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
                const SizedBox(height: 8),
                Text(
                  'Você pode ter ${_limit - 1} número(s) adicional(is) no seu plano.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (_numbers.isEmpty)
                  const EmptyState(
                    icon: Icons.phone_android,
                    message: 'Nenhum número adicional cadastrado.',
                  )
                else
                  for (final number in _numbers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Row(
                          children: [
                            const Icon(Icons.phone_android),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    number.name,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    number.whatsapp,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _delete(number),
                              icon: Icon(Icons.delete_outline,
                                  color: theme.colorScheme.error),
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
