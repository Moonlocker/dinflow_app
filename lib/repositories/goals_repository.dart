import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/goal.dart';

/// Metas do usuário (tabela `goals`).
class GoalsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Goal>> fetchGoals(String userId) async {
    final data = await _client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => Goal.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Goal> createGoal(String userId, Map<String, dynamic> values) async {
    final data = await _client
        .from('goals')
        .insert({...values, 'user_id': userId})
        .select()
        .single();
    return Goal.fromMap(data);
  }

  Future<Goal> updateGoal({
    required String id,
    required String userId,
    required Map<String, dynamic> values,
  }) async {
    final data = await _client
        .from('goals')
        .update(values)
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
    return Goal.fromMap(data);
  }

  Future<void> deleteGoal({required String id, required String userId}) {
    return _client.from('goals').delete().eq('id', id).eq('user_id', userId);
  }
}
