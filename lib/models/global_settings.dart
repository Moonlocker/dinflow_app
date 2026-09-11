/// Configurações globais do app — tabela `public.global_settings` (id = 1).
class GlobalSettings {
  const GlobalSettings({
    this.appName = 'DinFlow',
    this.logoUrl,
    this.logoUrlDark,
    this.faviconUrl,
    this.defaultEducationImage,
    this.trialDays = 15,
    this.trialEnabled = true,
    this.whatsapp,
  });

  final String appName;
  final String? logoUrl;
  final String? logoUrlDark;
  final String? faviconUrl;
  final String? defaultEducationImage;
  final int trialDays;
  final bool trialEnabled;
  final String? whatsapp;

  factory GlobalSettings.fromMap(Map<String, dynamic> map) {
    return GlobalSettings(
      appName: (map['app_name'] ?? 'DinFlow') as String,
      logoUrl: map['logo_url'] as String?,
      logoUrlDark: map['logo_url_dark'] as String?,
      faviconUrl: map['favicon_url'] as String?,
      defaultEducationImage: map['default_education_image'] as String?,
      trialDays: (map['trial_days'] as num?)?.toInt() ?? 15,
      trialEnabled: (map['trial_enabled'] ?? true) as bool,
      whatsapp: map['whatsapp'] as String?,
    );
  }
}
