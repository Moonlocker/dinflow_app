import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/bill.dart';
import '../../../widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../authors/providers/author_provider.dart';
import '../../dashboard/widgets/month_navigator.dart';
import '../../finance/providers/finance_provider.dart';
import '../providers/bills_provider.dart';
import '../widgets/bill_card.dart';
import '../widgets/bill_form_sheet.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    context.read<BillsProvider>().load(userId);
    context.read<FinanceProvider>().load(userId);
  }

  ({String label, Color color}) _dueBadge(Bill bill) {
    final bills = context.read<BillsProvider>();
    final now = DateTime.now();
    final reference = bills.currentDate;
    final dueDate = DateTime(reference.year, reference.month, bill.dueDay);
    final isCurrentMonth =
        now.year == reference.year && now.month == reference.month;
    final days = dueDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    if (!isCurrentMonth) {
      return (label: '${days.abs()} dias', color: Colors.blueGrey);
    }
    if (days < 0) return (label: 'Vencida', color: const Color(0xFFEF4444));
    if (days == 0) return (label: 'Hoje', color: const Color(0xFFEF4444));
    if (days == 1) return (label: 'Amanhã', color: const Color(0xFFF97415));
    if (days <= 7) return (label: '$days dias', color: const Color(0xFFF59E0B));
    return (label: '$days dias', color: Colors.blueGrey);
  }

  bool _isOverdue(Bill bill) {
    final reference = context.read<BillsProvider>().currentDate;
    final now = DateTime.now();
    final isCurrentMonth =
        now.year == reference.year && now.month == reference.month;
    if (!isCurrentMonth) return false;
    final dueDate = DateTime(reference.year, reference.month, bill.dueDay);
    final today = DateTime(now.year, now.month, now.day);
    return dueDate.isBefore(today);
  }

  Future<void> _openBillLink(Bill bill) => launchBillLink(context, bill.link);

  Future<void> _markAsPaid(Bill bill) async {
    final result = await showModalBottomSheet<({double amount, bool addToTransactions})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PaymentSheet(bill: bill),
    );

    if (result == null || !mounted) return;

    final billsProvider = context.read<BillsProvider>();
    final finance = context.read<FinanceProvider>();
    final authorNumber =
        context.read<AuthorProvider>().effectiveWhatsapp ??
        context.read<AuthProvider>().profile?.whatsapp;

    try {
      await billsProvider.markAsPaid(
        billId: bill.id,
        amount: result.amount,
      );
      if (result.addToTransactions) {
        await finance.addTransaction(
          amount: result.amount,
          type: 'expense',
          date: DateTime.now(),
          description:
              '${bill.name} - ${formatMonthYear(billsProvider.currentDate)}',
          categoryId: bill.categoryId,
          authorNumber: authorNumber,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Conta marcada como paga!')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao marcar a conta como paga.')),
      );
    }
  }

  Future<void> _unmarkAsPaid(Bill bill) async {
    try {
      await context.read<BillsProvider>().unmarkAsPaid(bill.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pagamento desfeito.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao desfazer o pagamento.')),
      );
    }
  }

  Future<void> _confirmDelete(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: Text('A conta "${bill.name}" será removida.'),
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
      await context.read<BillsProvider>().deleteBill(bill.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Conta excluída!')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao excluir a conta.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bills = context.watch<BillsProvider>();
    final finance = context.watch<FinanceProvider>();

    if (bills.loading && bills.bills.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-bill',
        onPressed: () => showBillForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova Conta'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Contas Fixas',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Gerencie suas contas mensais e não perca vencimentos',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          MonthNavigator(
            date: bills.currentDate,
            onPrevious: bills.previousMonth,
            onNext: bills.nextMonth,
          ),
          const SizedBox(height: 16),
          if (bills.bills.isEmpty)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nenhuma conta cadastrada.')),
              ),
            )
          else
            for (final bill in bills.bills) ...[
              Builder(
                builder: (context) {
                  final badge = _dueBadge(bill);
                  final category = finance.categoryById(bill.categoryId);
                  final isPaid = bills.isPaid(bill.id);
                  return BillCard(
                    bill: bill,
                    category: category,
                    isPaid: isPaid,
                    isOverdue: !isPaid && _isOverdue(bill),
                    dueLabel: badge.label,
                    dueColor: badge.color,
                    paidAmount: bills.paymentFor(bill.id)?.amount,
                    onPay: () => _markAsPaid(bill),
                    onUnpay: () => _unmarkAsPaid(bill),
                    onOpenLink: () => _openBillLink(bill),
                    onEdit: () => showBillForm(context, bill: bill),
                    onDelete: () => _confirmDelete(bill),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

/// Abre o link de pagamento cadastrado na conta (quando existir).
Future<void> launchBillLink(BuildContext context, String? link) async {
  final trimmed = link?.trim() ?? '';
  if (trimmed.isEmpty) return;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link da conta.')),
    );
  }
}

/// Bottom sheet para registrar o pagamento e, opcionalmente, lançar a despesa.
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.bill});

  final Bill bill;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _amountController;
  bool _addToTransactions = true;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.bill.amount > 0
          ? widget.bill.amount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool get _hasLink =>
      widget.bill.link != null && widget.bill.link!.trim().isNotEmpty;

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }
    Navigator.of(context).pop(
      (amount: amount, addToTransactions: _addToTransactions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar pagamento',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.bill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.titleMedium,
            decoration: const InputDecoration(
              labelText: 'Valor pago',
              prefixText: r'R$ ',
              hintText: '0,00',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _addToTransactions,
            onChanged: (value) => setState(() => _addToTransactions = value),
            title: const Text('Lançar nas transações'),
            subtitle: const Text('Registrar como despesa'),
          ),
          if (_hasLink) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => launchBillLink(context, widget.bill.link),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir link da conta'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
