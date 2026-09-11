import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';

/// Transações do usuário (tabela `transactions`).
class TransactionsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Transaction>> fetchTransactions(String userId) async {
    final data = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false);
    return (data as List)
        .map((row) => Transaction.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> createTransaction({
    required String userId,
    required double amount,
    required String type,
    required DateTime date,
    String? description,
    String? categoryId,
    String? authorNumber,
  }) async {
    final data = await _client
        .from('transactions')
        .insert({
          'user_id': userId,
          'amount': amount,
          'type': type,
          'date': _dateOnly(date),
          'description': description,
          'category_id': categoryId,
          'author_number': authorNumber,
        })
        .select()
        .single();
    return Transaction.fromMap(data);
  }

  Future<Transaction> updateTransaction({
    required String id,
    required String userId,
    required Map<String, dynamic> values,
  }) async {
    final data = await _client
        .from('transactions')
        .update(values)
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
    return Transaction.fromMap(data);
  }

  Future<void> deleteTransaction({required String id, required String userId}) {
    return _client.from('transactions').delete().eq('id', id).eq('user_id', userId);
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
