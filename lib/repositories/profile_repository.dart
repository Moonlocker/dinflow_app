import 'dart:typed_data';

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

  /// Envia o avatar para o bucket `avatars` e devolve a URL pública.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$extension',
            upsert: true,
          ),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
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
