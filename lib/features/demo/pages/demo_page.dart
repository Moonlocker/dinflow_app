import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/app_card.dart';
import '../../auth/pages/register_page.dart';

/// Tela de demonstração (dados fictícios) acessível antes do cadastro.
class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoTransaction {
  const _DemoTransaction(
    this.description,
    this.amount,
    this.type,
    this.date,
    this.category,
  );
  final String description;
  final double amount;
  final String type;
  final DateTime date;
  final String category;
}

class _DemoGoal {
  const _DemoGoal(this.title, this.current, this.target);
  final String title;
  final double current;
  final double target;

  double get progress =>
      target <= 0 ? 0 : (current / target).clamp(0, 1).toDouble();
}

class _DemoPageState extends State<DemoPage> {
  late final List<_DemoTransaction> _transactions;
  late final List<_DemoGoal> _goals;

  static const _bills = [
    ('Aluguel', 1200.0, 5),
    ('Energia Elétrica', 150.0, 10),
    ('Internet', 99.90, 15),
    ('Plano de Saúde', 450.0, 20),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _transactions = [
      _DemoTransaction(
        'Salário',
        5000,
        'income',
        now.subtract(const Duration(days: 15)),
        'Salário',
      ),
      _DemoTransaction('Freelance', 800, 'income', now, 'Freelance'),
      _DemoTransaction(
        'Supermercado',
        280,
        'expense',
        now.subtract(const Duration(days: 10)),
        'Alimentação',
      ),
      _DemoTransaction(
        'Uber',
        35,
        'expense',
        now.subtract(const Duration(days: 8)),
        'Transporte',
      ),
      _DemoTransaction(
        'Netflix',
        29.90,
        'expense',
        now.subtract(const Duration(days: 7)),
        'Lazer',
      ),
      _DemoTransaction(
        'Academia',
        89,
        'expense',
        now.subtract(const Duration(days: 5)),
        'Saúde',
      ),
      _DemoTransaction(
        'Restaurante',
        120,
        'expense',
        now.subtract(const Duration(days: 3)),
        'Alimentação',
      ),
      _DemoTransaction(
        'Gasolina',
        200,
        'expense',
        now.subtract(const Duration(days: 2)),
        'Transporte',
      ),
    ];
    _goals = const [
      _DemoGoal('Reserva de Emergência', 3500, 10000),
      _DemoGoal('Viagem', 1200, 5000),
      _DemoGoal('Carro Novo', 8500, 30000),
    ];
  }

  double get _income => _transactions
      .where((t) => t.type == 'income')
      .fold(0, (s, t) => s + t.amount);
  double get _expense => _transactions
      .where((t) => t.type == 'expense')
      .fold(0, (s, t) => s + t.amount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Demonstração')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Você está no modo demonstração com dados fictícios.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Olá, Demo!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Veja como o DinFlow organiza suas finanças.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    theme,
                    'Receitas',
                    _income,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stat(
                    theme,
                    'Despesas',
                    _expense,
                    const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _stat(
              theme,
              'Saldo',
              _income - _expense,
              const Color(0xFF3B82F6),
              wide: true,
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entradas x Saídas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: _income,
                                color: const Color(0xFF10B981),
                                width: 24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: _expense,
                                color: const Color(0xFFEF4444),
                                width: 24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transações recentes',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final transaction in _transactions.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(
                            transaction.type == 'income'
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 18,
                            color: transaction.type == 'income'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(transaction.description),
                                Text(
                                  '${transaction.category} • ${formatDateOnly(transaction.date.toIso8601String())}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${transaction.type == 'income' ? '+' : '-'}${formatCurrency(transaction.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: transaction.type == 'income'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Metas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final goal in _goals) ...[
                    Row(
                      children: [
                        Expanded(child: Text(goal.title)),
                        Text('${(goal.progress * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contas fixas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final bill in _bills)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(bill.$1)),
                          Text(
                            'Dia ${bill.$3} • ${formatCurrency(bill.$2)}',
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              ),
              child: const Text('Criar conta grátis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    ThemeData theme,
    String label,
    double value,
    Color color, {
    bool wide = false,
  }) {
    return AppCard(
      color: color.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.16 : 0.08,
      ),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(value),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (wide) const SizedBox.shrink(),
        ],
      ),
    );
  }
}
