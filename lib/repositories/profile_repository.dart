import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/subscription.dart';

/// Perfil e assinatura do usuário (tabelas `profiles` e `subscriptions`).
class ProfileRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Profile?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<Subscription?> fetchLatestSubscription(String userId) async {
    final data = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return Subscription.fromMap(data);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> values) {
    return _client.from('profiles').update(values).eq('id', userId);
  }

  /// Fallback quando a RPC `create_profile_for_user` falha.
  Future<void> insertProfile({
    required String userId,
    required String email,
    required String name,
    required bool trialEnabled,
    required int trialDays,
  }) {
    final trialEndsAt = trialEnabled
        ? DateTime.now().add(Duration(days: trialDays)).toIso8601String()
        : DateTime.now().toIso8601String();
    return _client.from('profiles').insert({
      'id': userId,
      'email': email,
      'name': name,
      'subscription_status': trialEnabled ? 'trial' : 'inactive',
      'trial_ends_at': trialEndsAt,
    });
  }
}
