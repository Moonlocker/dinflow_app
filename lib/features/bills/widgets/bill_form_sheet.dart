import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/bill.dart';
import '../../finance/providers/finance_provider.dart';
import '../providers/bills_provider.dart';

Future<void> showBillForm(BuildContext context, {Bill? bill}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BillFormSheet(bill: bill),
  );
}

class BillFormSheet extends StatefulWidget {
  const BillFormSheet({super.key, this.bill});

  final Bill? bill;

  @override
  State<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends State<BillFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDayController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _categoryId;
  bool _saving = false;

  bool get _isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    if (bill != null) {
      _nameController.text = bill.name;
      _amountController.text = bill.amount.toString();
      _dueDayController.text = bill.dueDay.toString();
      _descriptionController.text = bill.description ?? '';
      _categoryId = bill.categoryId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dueDayController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final values = <String, dynamic>{
      'name': _nameController.text.trim(),
      'amount': double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0,
      'due_day': int.tryParse(_dueDayController.text) ?? 1,
      'category_id': _categoryId,
      'description': _descriptionController.text.trim(),
    };

    final provider = context.read<BillsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await provider.updateBill(id: widget.bill!.id, values: values);
      } else {
        await provider.addBill(values);
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Conta atualizada!' : 'Conta adicionada!')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Erro ao salvar a conta. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseCategories =
        context.watch<FinanceProvider>().categories.where((c) => c.type == 'expense').toList();

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
                _isEditing ? 'Editar Conta' : 'Adicionar Nova Conta',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome da Conta *',
                  hintText: 'Ex: Conta de Luz',
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Informe o nome.' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor Estimado',
                        hintText: '0,00',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _dueDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dia do Vencimento *',
                        hintText: 'Ex: 15',
                      ),
                      validator: (value) {
                        final day = int.tryParse(value ?? '');
                        if (day == null || day < 1 || day > 31) return 'Dia de 1 a 31.';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria *'),
                items: [
                  for (final category in expenseCategories)
                    DropdownMenuItem(value: category.id, child: Text(category.name)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'Selecione uma categoria.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observações'),
              ),
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
                          : Text(_isEditing ? 'Atualizar Conta' : 'Adicionar Conta'),
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
}
