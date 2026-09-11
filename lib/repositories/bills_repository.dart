import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bill.dart';

/// Contas fixas do usuário (tabela `bill_reminders`).
class BillsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Bill>> fetchBills(String userId) async {
    final data = await _client
        .from('bill_reminders')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('due_day', ascending: true);
    return (data as List)
        .map((row) => Bill.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Bill> createBill(String userId, Map<String, dynamic> values) async {
    final data = await _client
        .from('bill_reminders')
        .insert({...values, 'user_id': userId})
        .select()
        .single();
    return Bill.fromMap(data);
  }

  Future<Bill> updateBill({
    required String id,
    required String userId,
    required Map<String, dynamic> values,
  }) async {
    final data = await _client
        .from('bill_reminders')
        .update(values)
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
    return Bill.fromMap(data);
  }

  Future<void> deleteBill({required String id, required String userId}) {
    return _client.from('bill_reminders').delete().eq('id', id).eq('user_id', userId);
  }
}
