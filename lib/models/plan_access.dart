/// Acessos efetivos do usuário conforme o plano ativo.
///
/// Resolvido a partir do plano da assinatura (quando ativa) ou do plano
/// gratuito (`plans.is_free`) usado como fallback.
class PlanAccess {
  const PlanAccess({
    this.planId,
    this.planName,
    this.isFree = false,
    this.allowWhatsappMessages = true,
    this.whatsappNumbersLimit = 1,
    this.maxTransactionsMonthly = 0,
  });

  final String? planId;
  final String? planName;
  final bool isFree;
  final bool allowWhatsappMessages;

  /// Limite de números (principal + extras). `1` = apenas o principal.
  final int whatsappNumbersLimit;

  /// Limite de transações por mês. `0` significa ilimitado.
  final int maxTransactionsMonthly;

  bool get hasMonthlyTransactionLimit => maxTransactionsMonthly > 0;

  factory PlanAccess.fromMap(Map<String, dynamic> map) {
    return PlanAccess(
      planId: map['id'] as String?,
      planName: map['name'] as String?,
      isFree: (map['is_free'] ?? false) as bool,
      allowWhatsappMessages: (map['allow_whatsapp_messages'] ?? true) as bool,
      whatsappNumbersLimit:
          ((map['whatsapp_numbers_limit'] ?? 1) as num).toInt(),
      maxTransactionsMonthly:
          ((map['max_transactions_monthly'] ?? 0) as num).toInt(),
    );
  }
}
