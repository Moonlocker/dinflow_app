import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/empty_state.dart';
import '../providers/open_finance_provider.dart';
import 'pluggy_connect_page.dart';

/// Tela "Contas conectadas" do módulo Open Finance.
/// Linguagem simples, sem termos técnicos (item, token, webhook, etc.).
class ConnectedAccountsPage extends StatefulWidget {
  const ConnectedAccountsPage({super.key});

  @override
  State<ConnectedAccountsPage> createState() => _ConnectedAccountsPageState();
}

class _ConnectedAccountsPageState extends State<ConnectedAccountsPage> {
  bool _connecting = false;

  Future<void> _connect({String? itemId}) async {
    final provider = context.read<OpenFinanceProvider>();
    setState(() => _connecting = true);
    try {
      final token = await provider.createConnectToken(itemId: itemId);
      if (!mounted) return;
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PluggyConnectPage(
            connectToken: token,
            itemId: itemId,
          ),
        ),
      );
      if (!mounted) return;
      if (result == null) return; // cancelado
      await provider.sync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Banco conectado com sucesso. Estamos organizando suas movimentações.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar o banco.')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _sync({String? connectionId}) async {
    final provider = context.read<OpenFinanceProvider>();
    try {
      await provider.sync(connectionId: connectionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronizado!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível sincronizar agora.')),
      );
    }
  }

  Future<void> _disconnect(String connectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desconectar banco?'),
        content: const Text(
          'Vamos interromper novas sincronizações. Suas movimentações já '
          'importadas continuam salvas no DinFlow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<OpenFinanceProvider>().disconnect(connectionId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível desconectar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<OpenFinanceProvider>();

    if (!provider.isEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contas conectadas')),
        body: const EmptyState(
          icon: Icons.link_off,
          message: 'Recurso indisponível no momento.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Contas conectadas')),
      body: RefreshIndicator(
        onRefresh: provider.reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              'Deixe o DinFlow importar automaticamente suas movimentações '
              'para você não precisar lançar tudo manualmente.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _connecting ? null : () => _connect(),
              icon: _connecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Conectar banco'),
            ),
            const SizedBox(height: 20),
            if (provider.loading && provider.connections.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (provider.connections.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.account_balance_outlined,
                  message:
                      'Nenhum banco conectado ainda.\nVocê poderá desconectar quando quiser.',
                ),
              )
            else
              ...provider.connections.map(_buildConnection),
          ],
        ),
      ),
    );
  }

  Widget _buildConnection(dynamic connection) {
    final theme = Theme.of(context);
    final provider = context.read<OpenFinanceProvider>();
    final connectionAccounts = provider.accounts
        .where((account) => account.connectionId == connection.id)
        .toList();
    final connectionCards = provider.cards
        .where((card) => card.connectionId == connection.id)
        .toList();
    final needsAttention = connection.needsAttention == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.institutionName ?? 'Banco conectado',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${connection.statusLabel} • ${_lastSyncLabel(connection.lastSyncAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sincronizar',
                  onPressed: () => _sync(connectionId: connection.id),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Desconectar',
                  onPressed: () => _disconnect(connection.id),
                  icon: const Icon(Icons.link_off),
                ),
              ],
            ),
            if (needsAttention) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sua conexão precisa ser atualizada.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _connecting
                          ? null
                          : () => _connect(
                                itemId: connection.externalConnectionId,
                              ),
                      child: const Text('Reconectar banco'),
                    ),
                  ],
                ),
              ),
            ],
            for (final account in connectionAccounts) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.account_balance_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(account.name ?? 'Conta')),
                  Text(
                    formatCurrency(account.balance ?? 0),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            for (final card in connectionCards) ...[
              const SizedBox(height: 16),
              _buildCard(card, provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(dynamic card, OpenFinanceProvider provider) {
    final theme = Theme.of(context);
    final cardBills = provider.bills
        .where((bill) => bill.cardId == card.id)
        .toList();
    final currentBill = cardBills.isNotEmpty ? cardBills.first : null;
    final cardTransactions = provider.transactions
        .where((transaction) => transaction.cardId == card.id)
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.name ?? 'Cartão',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (card.brand != null) Text(card.brand!),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _cardMetric(
                'Fatura atual',
                formatCurrency(currentBill?.totalAmount ?? 0),
              ),
              _cardMetric(
                'Vencimento',
                card.dueDate != null
                    ? formatDateOnly(card.dueDate!.toIso8601String())
                    : '—',
              ),
              _cardMetric('Limite', formatCurrency(card.creditLimit ?? 0)),
              _cardMetric(
                'Disponível',
                formatCurrency(card.availableLimit ?? 0),
              ),
            ],
          ),
          if (cardTransactions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final transaction in cardTransactions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.description ??
                            transaction.merchantName ??
                            'Compra',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      formatCurrency(transaction.amount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _cardMetric(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _lastSyncLabel(DateTime? value) {
    if (value == null) return 'ainda não sincronizado';
    return 'atualizado em ${formatDateOnly(value.toIso8601String())}';
  }
}
