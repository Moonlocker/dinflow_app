import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bill.dart';

/// Pagamentos de contas por mês (tabela `bill_payments`).
class PaymentsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<BillPayment>> fetchPayments(String userId, String monthYear) async {
    final data = await _client
        .from('bill_payments')
        .select()
        .eq('user_id', userId)
        .eq('month_year', monthYear)
        .order('paid_at', ascending: false);
    return (data as List)
        .map((row) => BillPayment.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<BillPayment> markAsPaid({
    required String userId,
    required String billId,
    required String monthYear,
    required double amount,
  }) async {
    final data = await _client
        .from('bill_payments')
        .insert({
          'bill_reminder_id': billId,
          'user_id': userId,
          'month_year': monthYear,
          'amount': amount,
          'paid_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return BillPayment.fromMap(data);
  }

  Future<void> unmarkPayment({required String id, required String userId}) {
    return _client.from('bill_payments').delete().eq('id', id).eq('user_id', userId);
  }
}
