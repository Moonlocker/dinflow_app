/// Usuário listado no painel de administração.
///
/// Vem da RPC `admin_list_profiles_with_status` (tabela `public.profiles`).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    this.name,
    this.role = 'user',
    this.subscriptionStatus = 'trial',
    this.realStatus,
    this.trialEndsAt,
    this.subscriptionEndDate,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? name;
  final String role;
  final String subscriptionStatus;
  final String? realStatus;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionEndDate;
  final DateTime? createdAt;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : email;

  /// Status efetivo (considera expiração de trial/assinatura).
  String get effectiveStatus => realStatus ?? subscriptionStatus;

  bool get isSuperadmin => role == 'superadmin';

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      id: map['id'] as String,
      email: (map['email'] ?? '') as String,
      name: map['name'] as String?,
      role: (map['role'] ?? 'user') as String,
      subscriptionStatus: (map['subscription_status'] ?? 'trial') as String,
      realStatus: map['real_status'] as String?,
      trialEndsAt: _parseDate(map['trial_ends_at']),
      subscriptionEndDate: _parseDate(map['subscription_end_date']),
      createdAt: _parseDate(map['created_at']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
