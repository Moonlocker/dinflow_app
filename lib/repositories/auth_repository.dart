import 'package:supabase_flutter/supabase_flutter.dart';

/// Acesso à autenticação do Supabase (mesmo projeto usado pelo webapp).
class AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Dispara o e-mail de recuperação pela Edge Function do DinFlow.
  Future<void> sendPasswordResetEmail(String email) {
    return _client.functions.invoke(
      'send-password-reset-email',
      body: {'email': email},
    );
  }

  /// Cria o perfil do usuário via RPC `create_profile_for_user` (mesma função
  /// usada pelo webapp). Lança em caso de erro para o chamador decidir o fallback.
  Future<void> createProfileForUser({
    required String userId,
    required String email,
    required String name,
    required int trialDays,
  }) {
    return _client.rpc('create_profile_for_user', params: {
      'p_user_id': userId,
      'p_email': email,
      'p_name': name,
      'p_trial_days': trialDays,
    });
  }
}
