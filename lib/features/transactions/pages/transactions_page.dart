import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/category.dart';
import '../../../models/transaction.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../authors/providers/author_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../widgets/transaction_form_sheet.dart';

class _Filters {
  const _Filters({
    this.type = 'all',
    this.categoryId,
    this.authorNumber,
    this.from,
    this.to,
  });

  final String type;
  final String? categoryId;
  final String? authorNumber;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      type == 'all' &&
      categoryId == null &&
      authorNumber == null &&
      from == null &&
      to == null;
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  static const int _perPage = 10;

  final _searchController = TextEditingController();
  _Filters _filters = const _Filters();
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) context.read<FinanceProvider>().load(userId);
  }

  List<Transaction> _filtered(FinanceProvider finance) {
    final term = _searchController.text.trim().toLowerCase();
    return finance.transactions.where((transaction) {
      final description = (transaction.description ?? '').toLowerCase();
      if (term.isNotEmpty && !description.contains(term)) return false;
      if (_filters.type != 'all' && transaction.type != _filters.type) {
        return false;
      }
      if (_filters.categoryId != null &&
          transaction.categoryId != _filters.categoryId) {
        return false;
      }
      if (_filters.authorNumber != null &&
          transaction.authorNumber != _filters.authorNumber) {
        return false;
      }
      if (_filters.from != null && transaction.date.isBefore(_filters.from!)) {
        return false;
      }
      if (_filters.to != null && transaction.date.isAfter(_filters.to!)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _authorName(String whatsapp) {
    final authors = context.read<AuthorProvider>().authors;
    for (final author in authors) {
      if (author.whatsapp == whatsapp) return author.name;
    }
    return whatsapp;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionFiltersSheet(
        initial: _filters,
        categories: context.read<FinanceProvider>().categories,
        authors: context.read<AuthorProvider>().authors,
      ),
    );
    if (result != null) {
      setState(() {
        _filters = result;
        _page = 1;
      });
    }
  }

  Future<void> _confirmDelete(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Transação?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<FinanceProvider>().deleteTransaction(transaction.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Transação excluída!')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao excluir a transação.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = context.watch<FinanceProvider>();

    if (finance.loading && !finance.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered(finance);
    final totalPages = (filtered.length / _perPage).ceil();
    final currentPage = _page.clamp(1, totalPages == 0 ? 1 : totalPages);
    final pageItems = filtered
        .skip((currentPage - 1) * _perPage)
        .take(_perPage)
        .toList();

    final totalIncome = filtered
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = filtered
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-transaction',
        onPressed: () => showTransactionForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Transações',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Gerencie suas entradas e saídas financeiras',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  title: 'Entradas',
                  value: formatCurrency(totalIncome),
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  title: 'Saídas',
                  value: formatCurrency(totalExpense),
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MiniStat(
            title: 'Saldo do período',
            value: formatCurrency(totalIncome - totalExpense),
            color: (totalIncome - totalExpense) >= 0
                ? const Color(0xFF3B82F6)
                : const Color(0xFFF97316),
            wide: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() => _page = 1),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por descrição...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _openFilters,
                icon: Badge(
                  isLabelVisible: !_filters.isEmpty,
                  child: const Icon(Icons.filter_list),
                ),
              ),
            ],
          ),
          if (!_filters.isEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_filters.type != 'all')
                  _FilterChip(
                    label: _filters.type == 'income' ? 'Entrada' : 'Saída',
                    onRemove: () => setState(() {
                      _filters = _Filters(
                        categoryId: _filters.categoryId,
                        authorNumber: _filters.authorNumber,
                        from: _filters.from,
                        to: _filters.to,
                      );
                      _page = 1;
                    }),
                  ),
                if (_filters.categoryId != null)
                  _FilterChip(
                    label:
                        finance.categoryById(_filters.categoryId)?.name ??
                        'Categoria',
                    onRemove: () => setState(() {
                      _filters = _Filters(
                        type: _filters.type,
                        authorNumber: _filters.authorNumber,
                        from: _filters.from,
                        to: _filters.to,
                      );
                      _page = 1;
                    }),
                  ),
                if (_filters.authorNumber != null)
                  _FilterChip(
                    label: _authorName(_filters.authorNumber!),
                    onRemove: () => setState(() {
                      _filters = _Filters(
                        type: _filters.type,
                        categoryId: _filters.categoryId,
                        from: _filters.from,
                        to: _filters.to,
                      );
                      _page = 1;
                    }),
                  ),
                if (_filters.from != null || _filters.to != null)
                  _FilterChip(
                    label:
                        '${_filters.from != null ? formatDateOnly(_filters.from!.toIso8601String()) : '...'} - ${_filters.to != null ? formatDateOnly(_filters.to!.toIso8601String()) : '...'}',
                    onRemove: () => setState(() {
                      _filters = _Filters(
                        type: _filters.type,
                        categoryId: _filters.categoryId,
                        authorNumber: _filters.authorNumber,
                      );
                      _page = 1;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (pageItems.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.receipt_long,
                message: 'Nenhuma transação encontrada.',
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (var i = 0; i < pageItems.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _TransactionRow(
                      transaction: pageItems[i],
                      categoryName:
                          finance.categoryById(pageItems[i].categoryId)?.name ??
                          'N/A',
                      categoryColor: finance
                          .categoryById(pageItems[i].categoryId)
                          ?.parsedColor,
                      onEdit: () => showTransactionForm(
                        context,
                        transaction: pageItems[i],
                      ),
                      onDelete: () => _confirmDelete(pageItems[i]),
                    ),
                  ],
                ],
              ),
            ),
          if (totalPages > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: currentPage > 1
                      ? () => setState(() => _page = currentPage - 1)
                      : null,
                  child: const Text('Anterior'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Página $currentPage de $totalPages'),
                ),
                OutlinedButton(
                  onPressed: currentPage < totalPages
                      ? () => setState(() => _page = currentPage + 1)
                      : null,
                  child: const Text('Próxima'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.title,
    required this.value,
    required this.color,
    this.wide = false,
  });

  final String title;
  final String value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: color.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.16 : 0.08,
      ),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (wide) const SizedBox(height: 0),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.categoryName,
    required this.categoryColor,
    required this.onEdit,
    required this.onDelete,
  });

  final Transaction transaction;
  final String categoryName;
  final Color? categoryColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = transaction.isIncome
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final color = categoryColor ?? accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
              transaction.isIncome ? Icons.trending_up : Icons.trending_down,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? 'Sem descrição',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$categoryName • ${formatDateOnly(transaction.date.toIso8601String())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatCurrency(transaction.amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Excluir'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionFiltersSheet extends StatefulWidget {
  const _TransactionFiltersSheet({
    required this.initial,
    required this.categories,
    required this.authors,
  });

  final _Filters initial;
  final List<Category> categories;
  final List<AuthorOption> authors;

  @override
  State<_TransactionFiltersSheet> createState() =>
      _TransactionFiltersSheetState();
}

class _TransactionFiltersSheetState extends State<_TransactionFiltersSheet> {
  late String _type = widget.initial.type;
  late String? _categoryId = widget.initial.categoryId;
  late String? _authorNumber = widget.initial.authorNumber;
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtros',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Tipo'),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Todos')),
              ButtonSegment(value: 'income', label: Text('Entrada')),
              ButtonSegment(value: 'expense', label: Text('Saída')),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              for (final category in widget.categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          if (widget.authors.length > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _authorNumber,
              decoration: const InputDecoration(labelText: 'Autor'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final author in widget.authors)
                  DropdownMenuItem(
                    value: author.whatsapp,
                    child: Text(
                      author.isMain
                          ? '${author.name} (principal)'
                          : author.name,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _authorNumber = value),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              _from != null || _to != null
                  ? '${_from != null ? formatDateOnly(_from!.toIso8601String()) : '...'} - ${_to != null ? formatDateOnly(_to!.toIso8601String()) : '...'}'
                  : 'Selecionar período',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _Filters(
                      type: _type,
                      categoryId: _categoryId,
                      authorNumber: _authorNumber,
                      from: _from,
                      to: _to,
                    ),
                  ),
                  child: const Text('Aplicar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(const _Filters()),
                  child: const Text('Limpar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
