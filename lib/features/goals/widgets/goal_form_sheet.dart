import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/goal.dart';
import '../../finance/providers/finance_provider.dart';

Future<void> showGoalForm(BuildContext context, {Goal? goal}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => GoalFormSheet(goal: goal),
  );
}

const _goalTypes = <String, String>{
  'savings': 'Economia/Poupança',
  'expense_limit': 'Limite de Gastos',
  'investment': 'Investimento',
  'debt_payment': 'Pagamento de Dívida',
  'category_budget': 'Orçamento por Categoria',
};

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, this.goal});

  final Goal? goal;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();
  final _thresholdController = TextEditingController(text: '90');

  String _type = 'savings';
  String _period = 'monthly';
  String? _categoryId;
  DateTime? _dueDate;
  bool _saving = false;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _titleController.text = goal.title;
      _descriptionController.text = goal.description ?? '';
      _targetController.text = goal.targetAmount.toString();
      _currentController.text = goal.currentAmount.toString();
      _type = goal.type ?? 'savings';
      _period = goal.period ?? 'monthly';
      _categoryId = goal.categoryId;
      _dueDate = goal.dueDate;
      if (goal.alertThreshold != null) {
        _thresholdController.text = goal.alertThreshold!.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final finance = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final isCategoryBudget = _type == 'category_budget';
    final values = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'type': _type,
      'target_amount':
          double.tryParse(_targetController.text.replaceAll(',', '.')) ?? 0,
      'current_amount': isCategoryBudget
          ? 0
          : (double.tryParse(_currentController.text.replaceAll(',', '.')) ??
                0),
      'due_date': _dueDate == null ? null : _dateOnly(_dueDate!),
      'category_id': isCategoryBudget ? _categoryId : null,
      'period': isCategoryBudget ? _period : null,
      'alert_threshold': isCategoryBudget
          ? double.tryParse(_thresholdController.text) ?? 90
          : null,
    };

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await finance.updateGoal(id: widget.goal!.id, values: values);
      } else {
        await finance.addGoal(values);
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Meta atualizada!' : 'Meta adicionada!'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar a meta. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseCategories = context
        .watch<FinanceProvider>()
        .categories
        .where((c) => c.type == 'expense')
        .toList();
    final isCategoryBudget = _type == 'category_budget';
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Editar Meta' : 'Nova Meta Financeira',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título da Meta',
                  hintText: 'Ex: Economizar para viagem',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe um título.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo de Meta'),
                items: [
                  for (final entry in _goalTypes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? 'savings'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _type == 'expense_limit'
                            ? 'Limite (R\$)'
                            : 'Valor Meta (R\$)',
                        hintText: '0,00',
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(
                          (value ?? '').replaceAll(',', '.'),
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Valor inválido.';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (!isCategoryBudget) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _currentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _type == 'expense_limit'
                              ? 'Gasto Atual (R\$)'
                              : 'Valor Atual (R\$)',
                          hintText: '0,00',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (isCategoryBudget) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Categoria de Despesa',
                  ),
                  items: [
                    for (final category in expenseCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Selecione uma categoria.' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _period,
                        decoration: const InputDecoration(labelText: 'Período'),
                        items: const [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Diário'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Semanal'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Mensal'),
                          ),
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Anual'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _period = value ?? 'monthly'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Alerta em (%)',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!isCategoryBudget) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de Vencimento (opcional)',
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _dueDate == null
                              ? 'Selecionar data'
                              : formatDateOnly(_dueDate!.toIso8601String()),
                        ),
                      ],
                    ),
                  ),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing ? 'Atualizar' : 'Criar Meta'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
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

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
