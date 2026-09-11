/// Meta financeira — tabela `public.goals`.
class Goal {
  const Goal({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.type,
    this.currentAmount = 0,
    required this.targetAmount,
    this.dueDate,
    this.categoryId,
    this.period,
    this.alertThreshold,
    this.completed = false,
    this.status,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? type;
  final double currentAmount;
  final double targetAmount;
  final DateTime? dueDate;
  final String? categoryId;
  final String? period;
  final double? alertThreshold;
  final bool completed;
  final String? status;

  bool get isCompleted {
    if (type == 'category_budget') return false;
    if (completed || status == 'completed') return true;
    return targetAmount > 0 && currentAmount >= targetAmount;
  }

  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0, 1).toDouble();
  }

  bool get isOverdue {
    if (isCompleted || dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: (map['title'] ?? '') as String,
      description: map['description'] as String?,
      type: map['type'] as String?,
      currentAmount: (map['current_amount'] as num?)?.toDouble() ?? 0,
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0,
      dueDate: _parseDate(map['due_date']),
      categoryId: map['category_id'] as String?,
      period: map['period'] as String?,
      alertThreshold: (map['alert_threshold'] as num?)?.toDouble(),
      completed: (map['completed'] ?? false) as bool,
      status: map['status'] as String?,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
