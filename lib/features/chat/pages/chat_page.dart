import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/category.dart';
import '../../../widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../authors/providers/author_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../utils/transaction_parser.dart';

/// Assistente de lançamentos por texto (porta o ChatModal do webapp).
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  ParsedTransaction? _pending;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) context.read<FinanceProvider>().load(userId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _process() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _processing = true);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final categories = context.read<FinanceProvider>().categories;
      final parsed = parseTransactionInput(text, categories);
      setState(() => _processing = false);
      if (parsed.amount == null || parsed.description.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não entendi o lançamento. Inclua um valor e uma descrição.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _pending = parsed;
        _controller.clear();
      });
    });
  }

  Future<void> _confirm() async {
    final pending = _pending;
    if (pending == null || pending.amount == null) return;
    final finance = context.read<FinanceProvider>();
    final authorNumber = context.read<AuthorProvider>().effectiveWhatsapp ??
        context.read<AuthProvider>().profile?.whatsapp;
    try {
      await finance.addTransaction(
        amount: pending.amount!,
        type: pending.type,
        date: pending.date,
        description: pending.description,
        categoryId: pending.categoryId,
        authorNumber: authorNumber,
      );
      if (!mounted) return;
      setState(() => _pending = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento adicionado!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível adicionar o lançamento.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = context.watch<FinanceProvider>();
    final pending = _pending;

    return Scaffold(
      appBar: AppBar(title: const Text('Assistente')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(Icons.smart_toy_outlined,
                            size: 48, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          'Digite um lançamento',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ex: "Gastei 50 reais no almoço ontem"',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _ConfirmationCard(
                    pending: pending,
                    categories: finance.categories,
                    onTypeChanged: (type) => setState(() {
                      final fallback = _fallbackCategory(finance.categories, type);
                      _pending = pending.copyWith(
                        type: type,
                        categoryId: fallback?.id,
                      );
                    }),
                    onCategoryChanged: (category) => setState(() {
                      _pending = pending.copyWith(
                        type: category.type,
                        categoryId: category.id,
                      );
                    }),
                    onConfirm: _confirm,
                    onCancel: () => setState(() => _pending = null),
                  ),
              ],
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
                        hintText: 'Digite seu lançamento...',
                      ),
                      onSubmitted: (_) => _process(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _processing ? null : _process,
                    icon: _processing
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

  Category? _fallbackCategory(List<Category> categories, String type) {
    for (final category in categories) {
      if (category.type == type && category.name.toLowerCase() == 'outros') {
        return category;
      }
    }
    return null;
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.pending,
    required this.categories,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  final ParsedTransaction pending;
  final List<Category> categories;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<Category> onCategoryChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = categories.where((c) => c.type == pending.type).toList();
    final isIncome = pending.type == 'income';
    final color = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirmar Lançamento',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text('Descrição: ${pending.description}'),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Valor: '),
                TextSpan(
                  text: '${isIncome ? '+' : '-'} ${formatCurrency(pending.amount)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Data: ${formatDateOnly(pending.date.toIso8601String())}'),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Saída')),
              ButtonSegment(value: 'income', label: Text('Entrada')),
            ],
            selected: {pending.type},
            onSelectionChanged: (selection) => onTypeChanged(selection.first),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: filtered.any((c) => c.id == pending.categoryId)
                ? pending.categoryId
                : null,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              for (final category in filtered)
                DropdownMenuItem(value: category.id, child: Text(category.name)),
            ],
            onChanged: (value) {
              for (final category in filtered) {
                if (category.id == value) {
                  onCategoryChanged(category);
                  break;
                }
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onConfirm, child: const Text('Confirmar')),
            ],
          ),
        ],
      ),
    );
  }
}
