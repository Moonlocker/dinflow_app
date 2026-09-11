import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/app_card.dart';

/// Gráficos do painel administrativo (faturamento, clientes, planos e status).
class AdminCharts extends StatefulWidget {
  const AdminCharts({super.key, required this.data});

  final Map<String, List<Map<String, dynamic>>> data;

  @override
  State<AdminCharts> createState() => _AdminChartsState();
}

class _AdminChartsState extends State<AdminCharts> {
  int _months = 6;

  static const _monthNames = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  List<Map<String, dynamic>> get _payments => widget.data['payments'] ?? const [];
  List<Map<String, dynamic>> get _profiles => widget.data['profiles'] ?? const [];
  List<Map<String, dynamic>> get _plans => widget.data['plans'] ?? const [];
  List<Map<String, dynamic>> get _subscriptions =>
      widget.data['subscriptions'] ?? const [];

  List<DateTime> get _monthWindow {
    final now = DateTime.now();
    return [
      for (var i = _months - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Evolução',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 6, label: Text('6m')),
                  ButtonSegment(value: 12, label: Text('12m')),
                ],
                selected: {_months},
                onSelectionChanged: (value) =>
                    setState(() => _months = value.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _chartTitle(theme, 'Faturamento por mês'),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: _revenueBarChart(theme)),
          const SizedBox(height: 24),
          _chartTitle(theme, 'Clientes ativos por mês'),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: _clientsLineChart(theme)),
          const SizedBox(height: 24),
          _chartTitle(theme, 'Faturamento por plano'),
          const SizedBox(height: 8),
          _planDonut(theme),
          const SizedBox(height: 24),
          _chartTitle(theme, 'Distribuição de assinaturas'),
          const SizedBox(height: 8),
          _subscriptionDonut(theme),
        ],
      ),
    );
  }

  Widget _chartTitle(ThemeData theme, String text) => Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      );

  // ------------------------------------------------------------- Faturamento
  List<double> get _monthlyRevenue {
    final window = _monthWindow;
    return [
      for (final month in window)
        _payments
            .where((p) =>
                p['status'] == 'paid' && _sameMonth(p['created_at'], month))
            .fold(0.0, (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble()),
    ];
  }

  Widget _revenueBarChart(ThemeData theme) {
    final values = _monthlyRevenue;
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    return BarChart(
      BarChartData(
        maxY: safeMax,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: _bottomTitles(theme),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              formatCurrency(rod.toY),
              TextStyle(color: theme.colorScheme.onInverseSurface, fontSize: 11),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: theme.colorScheme.primary,
                  width: 10,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Clientes
  List<int> get _monthlyClients {
    final window = _monthWindow;
    return [
      for (final month in window)
        _profiles.where((profile) {
          if (profile['role'] == 'superadmin') return false;
          final createdAt = _parse(profile['created_at']);
          if (createdAt == null || createdAt.isAfter(_endOfMonth(month))) {
            return false;
          }
          final status = profile['subscription_status'];
          if (status == 'active') return true;
          if (status == 'trial') {
            final trialEnds = _parse(profile['trial_ends_at']);
            return trialEnds != null && !trialEnds.isBefore(month);
          }
          return false;
        }).length,
    ];
  }

  Widget _clientsLineChart(ThemeData theme) {
    final values = _monthlyClients;
    final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: safeMax,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: _bottomTitles(theme),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i].toDouble()),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Donuts
  Widget _planDonut(ThemeData theme) {
    final byPlan = <String, double>{};
    for (final payment in _payments) {
      if (payment['status'] != 'paid') continue;
      final planId = '${payment['plan_id']}';
      byPlan[planId] = (byPlan[planId] ?? 0) +
          ((payment['amount'] ?? 0) as num).toDouble();
    }
    final names = <String, String>{
      for (final plan in _plans) '${plan['id']}': '${plan['name']}',
    };

    final entries = byPlan.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return _empty(theme, 'Sem faturamento por plano.');
    }

    final colors = _palette(theme, entries.length);
    return _donutWithLegend(
      theme,
      sections: [
        for (var i = 0; i < entries.length; i++)
          _DonutSection(
            value: entries[i].value,
            color: colors[i],
            label: names[entries[i].key] ?? 'Plano',
          ),
      ],
    );
  }

  Widget _subscriptionDonut(ThemeData theme) {
    final labels = {
      'active': 'Ativo',
      'trial': 'Trial',
      'canceled': 'Cancelado',
      'past_due': 'Inadimplente',
      'expired': 'Expirado',
    };
    final counts = <String, int>{};
    for (final sub in _subscriptions) {
      final status = '${sub['status']}';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return _empty(theme, 'Sem assinaturas registradas.');
    }

    final colors = _palette(theme, entries.length);
    return _donutWithLegend(
      theme,
      sections: [
        for (var i = 0; i < entries.length; i++)
          _DonutSection(
            value: entries[i].value.toDouble(),
            color: colors[i],
            label: labels[entries[i].key] ?? entries[i].key,
          ),
      ],
    );
  }

  Widget _donutWithLegend(
    ThemeData theme, {
    required List<_DonutSection> sections,
  }) {
    final total = sections.fold<double>(0, (sum, s) => sum + s.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (final section in sections)
                  PieChartSectionData(
                    value: section.value,
                    color: section.color,
                    radius: 24,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: section.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          section.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        total > 0
                            ? '${(section.value / total * 100).toStringAsFixed(0)}%'
                            : '0%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(ThemeData theme, String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );

  FlTitlesData _bottomTitles(ThemeData theme) {
    final window = _monthWindow;
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= window.length) {
              return const SizedBox.shrink();
            }
            if (_months == 12 && index.isOdd) return const SizedBox.shrink();
            final month = window[index];
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _monthNames[month.month - 1],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Color> _palette(ThemeData theme, int count) {
    const base = [
      Color(0xFF1ABC9C),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF10B981),
      Color(0xFFEC4899),
      Color(0xFF6366F1),
    ];
    return [for (var i = 0; i < count; i++) base[i % base.length]];
  }

  bool _sameMonth(dynamic value, DateTime month) {
    final date = _parse(value);
    return date != null && date.year == month.year && date.month == month.month;
  }

  DateTime _endOfMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  DateTime? _parse(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class _DonutSection {
  const _DonutSection({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}
