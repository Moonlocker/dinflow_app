import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

/// Notificações do usuário (tabela `notifications`).
class NotificationsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AppNotification>> fetch(String userId) async {
    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List)
        .map((row) =>
            AppNotification.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<void> markAllAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }
}
