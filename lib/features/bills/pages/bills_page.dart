import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  Future<void> _markAsPaid(Bill bill) async {
    final amountController = TextEditingController(
      text: bill.amount > 0 ? bill.amount.toString() : '',
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar pagamento'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor pago (R\$)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(double.tryParse(amountController.text.replaceAll(',', '.'))),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !mounted) return;

    final addToTransactions = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lançar nas transações?'),
        content: const Text(
          'Deseja registrar este pagamento como uma despesa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    final billsProvider = context.read<BillsProvider>();
    final finance = context.read<FinanceProvider>();
    final authorNumber =
        context.read<AuthorProvider>().effectiveWhatsapp ??
        context.read<AuthProvider>().profile?.whatsapp;

    try {
      await billsProvider.markAsPaid(billId: bill.id, amount: amount);
      if (addToTransactions == true) {
        await finance.addTransaction(
          amount: amount,
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
