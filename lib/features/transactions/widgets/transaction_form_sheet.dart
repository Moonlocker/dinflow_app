import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/category.dart';
import '../../../models/transaction.dart';
import '../../auth/providers/auth_provider.dart';
import '../../authors/providers/author_provider.dart';
import '../../finance/providers/finance_provider.dart';

Future<void> showTransactionForm(BuildContext context, {Transaction? transaction}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TransactionFormSheet(transaction: transaction),
  );
}

class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet({super.key, this.transaction});

  final Transaction? transaction;

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'expense';
  DateTime _date = DateTime.now();
  String? _categoryId;
  bool _isRecurring = false;
  int _installments = 2;
  bool _saving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    if (transaction != null) {
      _type = transaction.type;
      _date = transaction.date;
      _categoryId = transaction.categoryId;
      _amountController.text = transaction.amount.toString();
      _descriptionController.text = transaction.description ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final finance = context.read<FinanceProvider>();
    final authorNumber = context.read<AuthorProvider>().effectiveWhatsapp ??
        context.read<AuthProvider>().profile?.whatsapp;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await finance.updateTransaction(
          id: widget.transaction!.id,
          amount: amount,
          type: _type,
          date: _date,
          description: _descriptionController.text.trim(),
          categoryId: _categoryId,
        );
      } else {
        await finance.addTransaction(
          amount: amount,
          type: _type,
          date: _date,
          description: _descriptionController.text.trim(),
          categoryId: _categoryId,
          authorNumber: authorNumber,
          installments: _isRecurring ? _installments : 1,
        );
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Transação atualizada!' : 'Transação adicionada!')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Erro ao salvar a transação. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.watch<FinanceProvider>().categories;
    final available = categories.where((category) => category.type == _type).toList();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Editar Transação' : 'Nova Transação',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _TypeToggle(
                value: _type,
                onChanged: (value) => setState(() {
                  _type = value;
                  final current = _categoryById(categories, _categoryId);
                  if (current == null || current.type != value) {
                    _categoryId = null;
                  }
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (R\$)', hintText: '0,00'),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Informe um valor válido.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex: Almoço no restaurante',
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Informe uma descrição.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('category-$_type'),
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final category in available)
                    DropdownMenuItem(
                      value: category.id,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: category.parsedColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'Selecione uma categoria.' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data'),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(formatDateOnly(_date.toIso8601String())),
                    ],
                  ),
                ),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isRecurring,
                  onChanged: (value) => setState(() {
                    _isRecurring = value;
                    _installments = value ? 2 : 1;
                  }),
                  title: const Text('Parcelamento'),
                  subtitle: const Text('Dividir esta transação em parcelas mensais'),
                ),
                if (_isRecurring)
                  DropdownButtonFormField<int>(
                    initialValue: _installments,
                    decoration: const InputDecoration(labelText: 'Número de parcelas'),
                    items: [
                      for (var i = 2; i <= 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('${i}x de ${formatCurrency(amount / i)}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _installments = value ?? 2),
                  ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? 'Atualizar' : 'Adicionar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Category? _categoryById(List<Category> categories, String? id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _segment(context, 'Entrada', 'income', const Color(0xFF10B981)),
          _segment(context, 'Saída', 'expense', const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, String segmentValue, Color color) {
    final selected = value == segmentValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(segmentValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
