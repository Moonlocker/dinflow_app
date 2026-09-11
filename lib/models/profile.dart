/// Perfil do usuário — tabela `public.profiles`.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    this.name,
    this.whatsapp,
    this.country,
    this.avatarUrl,
    this.role = 'user',
    this.subscriptionStatus = 'trial',
    this.subscriptionEndDate,
    this.trialEndsAt,
    this.twoFactorEnabled = false,
    this.theme = 'light',
    this.locale = 'pt-BR',
  });

  final String id;
  final String email;
  final String? name;
  final String? whatsapp;
  final String? country;
  final String? avatarUrl;
  final String role;
  final String subscriptionStatus;
  final DateTime? subscriptionEndDate;
  final DateTime? trialEndsAt;
  final bool twoFactorEnabled;
  final String theme;
  final String locale;

  bool get isSuperadmin => role == 'superadmin';

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    return email;
  }

  String get firstName {
    final source = displayName.trim();
    if (source.isEmpty) return '';
    return source.split(' ').first;
  }

  bool get isSubscriptionActive {
    if (isSuperadmin) return true;
    if (subscriptionStatus == 'trial') {
      return trialEndsAt != null && trialEndsAt!.isAfter(DateTime.now());
    }
    if (subscriptionStatus == 'active') {
      return subscriptionEndDate == null || subscriptionEndDate!.isAfter(DateTime.now());
    }
    return false;
  }

  int get trialDaysLeft {
    if (trialEndsAt == null || subscriptionStatus != 'trial') return 0;
    final diff = trialEndsAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      email: (map['email'] ?? '') as String,
      name: map['name'] as String?,
      whatsapp: map['whatsapp'] as String?,
      country: map['country'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: (map['role'] ?? 'user') as String,
      subscriptionStatus: (map['subscription_status'] ?? 'trial') as String,
      subscriptionEndDate: _parseDate(map['subscription_end_date']),
      trialEndsAt: _parseDate(map['trial_ends_at']),
      twoFactorEnabled: (map['two_factor_enabled'] ?? false) as bool,
      theme: (map['theme'] ?? 'light') as String,
      locale: (map['locale'] ?? 'pt-BR') as String,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
