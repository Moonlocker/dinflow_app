import 'package:supabase_flutter/supabase_flutter.dart';

/// Ações sensíveis sobre os dados da conta do usuário.
class AccountRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Remove transações, pagamentos de contas e metas do usuário.
  Future<void> resetFinancialData(String userId) async {
    await Future.wait([
      _client.from('transactions').delete().eq('user_id', userId),
      _client.from('bill_payments').delete().eq('user_id', userId),
      _client.from('goals').delete().eq('user_id', userId),
    ]);
  }

  /// Remove todos os dados do usuário (mantém a conta de autenticação).
  Future<void> deleteAllData(String userId) async {
    await Future.wait([
      _client.from('transactions').delete().eq('user_id', userId),
      _client.from('goals').delete().eq('user_id', userId),
      _client.from('categories').delete().eq('user_id', userId),
      _client.from('bill_reminders').delete().eq('user_id', userId),
      _client.from('bill_payments').delete().eq('user_id', userId),
      _client.from('notifications').delete().eq('user_id', userId),
      _client.from('subscriptions').delete().eq('user_id', userId),
      _client.from('user_whatsapp_numbers').delete().eq('user_id', userId),
    ]);
  }
}
