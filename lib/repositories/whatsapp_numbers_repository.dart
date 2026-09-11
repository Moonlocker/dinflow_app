import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/whatsapp_number.dart';

/// Números de WhatsApp adicionais (tabela `user_whatsapp_numbers`).
class WhatsappNumbersRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<WhatsappNumber>> fetch(String userId) async {
    final data = await _client
        .from('user_whatsapp_numbers')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: true);
    return (data as List)
        .map((row) => WhatsappNumber.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required String userId,
    required String name,
    required String country,
    required String whatsapp,
  }) async {
    await _client.from('user_whatsapp_numbers').insert({
      'user_id': userId,
      'name': name,
      'country': country,
      'whatsapp': whatsapp,
      'is_active': true,
    });
  }

  Future<void> remove({required String id, required String userId}) async {
    await _client
        .from('user_whatsapp_numbers')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<int> countTransactions({
    required String userId,
    required String authorNumber,
  }) async {
    final data = await _client
        .from('transactions')
        .select('id')
        .eq('user_id', userId)
        .eq('author_number', authorNumber);
    return (data as List).length;
  }

  Future<void> transferTransactions({
    required String userId,
    required String from,
    required String to,
  }) async {
    await _client
        .from('transactions')
        .update({'author_number': to})
        .eq('user_id', userId)
        .eq('author_number', from);
  }

  Future<void> deleteTransactions({
    required String userId,
    required String authorNumber,
  }) async {
    await _client
        .from('transactions')
        .delete()
        .eq('user_id', userId)
        .eq('author_number', authorNumber);
  }

  /// Limite de números do plano do usuário (1 = apenas o principal).
  Future<int> fetchPlanLimit(String userId) async {
    final subscription = await _client
        .from('subscriptions')
        .select('plan_id')
        .eq('user_id', userId)
        .maybeSingle();
    final planId = subscription?['plan_id'];
    if (planId == null) return 1;
    final plan = await _client
        .from('plans')
        .select('whatsapp_numbers_limit')
        .eq('id', planId)
        .maybeSingle();
    return (plan?['whatsapp_numbers_limit'] as num?)?.toInt() ?? 1;
  }
}
