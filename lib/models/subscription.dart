/// Assinatura do usuário — tabela `public.subscriptions`.
class Subscription {
  const Subscription({
    required this.id,
    required this.userId,
    required this.status,
    this.planId,
    this.startedAt,
    this.currentPeriodEnd,
    this.gateway,
  });

  final String id;
  final String userId;
  final String status;
  final String? planId;
  final DateTime? startedAt;
  final DateTime? currentPeriodEnd;
  final String? gateway;

  bool get isActive {
    if (status != 'active') return false;
    if (currentPeriodEnd == null) return true;
    return currentPeriodEnd!.isAfter(DateTime.now());
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      status: (map['status'] ?? 'trial') as String,
      planId: map['plan_id'] as String?,
      startedAt: _parseDate(map['started_at']),
      currentPeriodEnd: _parseDate(map['current_period_end']),
      gateway: map['gateway'] as String?,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
