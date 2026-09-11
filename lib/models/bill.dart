/// Conta fixa mensal — tabela `public.bill_reminders`.
class Bill {
  const Bill({
    required this.id,
    required this.userId,
    required this.name,
    this.amount = 0,
    required this.dueDay,
    this.categoryId,
    this.description,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String name;
  final double amount;
  final int dueDay;
  final String? categoryId;
  final String? description;
  final bool isActive;

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: (map['name'] ?? '') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      dueDay: (map['due_day'] as num?)?.toInt() ?? 1,
      categoryId: map['category_id'] as String?,
      description: map['description'] as String?,
      isActive: (map['is_active'] ?? true) as bool,
    );
  }
}

/// Pagamento de conta em um mês — tabela `public.bill_payments`.
class BillPayment {
  const BillPayment({
    required this.id,
    required this.billReminderId,
    required this.userId,
    required this.monthYear,
    required this.amount,
    this.paidAt,
  });

  final String id;
  final String billReminderId;
  final String userId;
  final String monthYear;
  final double amount;
  final DateTime? paidAt;

  factory BillPayment.fromMap(Map<String, dynamic> map) {
    return BillPayment(
      id: map['id'] as String,
      billReminderId: (map['bill_reminder_id'] ?? '') as String,
      userId: (map['user_id'] ?? '') as String,
      monthYear: (map['month_year'] ?? '') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paidAt: map['paid_at'] == null ? null : DateTime.tryParse(map['paid_at'].toString()),
    );
  }
}
