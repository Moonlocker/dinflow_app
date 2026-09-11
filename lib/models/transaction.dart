/// Transação financeira — tabela `public.transactions`.
class Transaction {
  const Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.date,
    this.description,
    this.categoryId,
    this.authorNumber,
    this.transactionId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final double amount;
  final String type; // 'income' | 'expense'
  final DateTime date;
  final String? description;
  final String? categoryId;
  final String? authorNumber;
  final String? transactionId;
  final DateTime? createdAt;

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: (map['type'] ?? 'expense') as String,
      date: _parseDate(map['date']) ?? DateTime.now(),
      description: map['description'] as String?,
      categoryId: map['category_id'] as String?,
      authorNumber: map['author_number'] as String?,
      transactionId: map['transaction_id'] as String?,
      createdAt: _parseDate(map['created_at']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
