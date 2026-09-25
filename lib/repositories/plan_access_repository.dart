import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan_access.dart';

/// Resolve os acessos do usuário a partir do plano (pago ou gratuito).
class PlanAccessRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const _columns =
      'id, name, is_free, allow_whatsapp_messages, whatsapp_numbers_limit, max_transactions_monthly';

  /// Acesso efetivo do usuário.
  ///
  /// * Assinatura ativa com plano vinculado → usa esse plano (pago ou grátis).
  /// * Assinatura ativa sem plano (ex.: trial) → `null` (sem restrições).
  /// * Assinatura inativa → plano gratuito (`is_free = true` e ativo) como
  ///   fallback; `null` se não houver plano gratuito configurado (nesse caso o
  ///   app mantém o comportamento antigo de exigir assinatura ativa).
  Future<PlanAccess?> fetchEffectiveAccess(
    String userId, {
    required bool subscriptionActive,
  }) async {
    if (subscriptionActive) {
      final subscription = await _client
          .from('subscriptions')
          .select('plan_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final planId = subscription?['plan_id'] as String?;
      if (planId == null) return null;
      final plan = await _client
          .from('plans')
          .select(_columns)
          .eq('id', planId)
          .maybeSingle();
      return plan == null
          ? null
          : PlanAccess.fromMap(Map<String, dynamic>.from(plan));
    }

    final free = await _client
        .from('plans')
        .select(_columns)
        .eq('is_free', true)
        .eq('status', 'Ativo')
        .limit(1)
        .maybeSingle();
    if (free == null) return null;
    return PlanAccess.fromMap(Map<String, dynamic>.from(free));
  }
}
