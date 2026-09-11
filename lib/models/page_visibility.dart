import '../core/navigation/app_pages.dart';

/// Configuração de visibilidade e ordem das páginas — tabela
/// `public.page_visibility_settings` (id = 1).
///
/// Espelha o hook `usePageVisibility` do webapp: cada página tem um flag de
/// exibição no desktop e no mobile, além de uma posição no menu.
class PageVisibilitySettings {
  const PageVisibilitySettings({
    required this.desktop,
    required this.mobile,
    required this.order,
  });

  final Map<String, bool> desktop;
  final Map<String, bool> mobile;
  final Map<String, int> order;

  /// Valores padrão: todas as páginas visíveis na ordem original.
  factory PageVisibilitySettings.defaults() {
    final keys = kAppPageKeys;
    return PageVisibilitySettings(
      desktop: {for (final key in keys) key: true},
      mobile: {for (final key in keys) key: true},
      order: {for (var i = 0; i < keys.length; i++) keys[i]: i},
    );
  }

  bool desktopVisible(String key) => desktop[key] ?? true;

  bool mobileVisible(String key) => mobile[key] ?? true;

  /// A página é considerada disponível se estiver visível em pelo menos
  /// uma plataforma (mesma regra do `PageVisibilityGuard` do webapp).
  bool visibleAnywhere(String key) => desktopVisible(key) || mobileVisible(key);

  int orderOf(String key) => order[key] ?? 99;

  List<String> orderedMobileKeys() => _ordered((key) => mobileVisible(key));

  List<String> orderedDesktopKeys() => _ordered((key) => desktopVisible(key));

  List<String> _ordered(bool Function(String) isVisible) {
    final keys = kAppPageKeys.where(isVisible).toList()
      ..sort((a, b) => orderOf(a).compareTo(orderOf(b)));
    return keys;
  }

  PageVisibilitySettings copyWith({
    Map<String, bool>? desktop,
    Map<String, bool>? mobile,
    Map<String, int>? order,
  }) {
    return PageVisibilitySettings(
      desktop: desktop ?? this.desktop,
      mobile: mobile ?? this.mobile,
      order: order ?? this.order,
    );
  }

  factory PageVisibilitySettings.fromMap(Map<String, dynamic> map) {
    final desktop = <String, bool>{};
    final mobile = <String, bool>{};
    final order = <String, int>{};

    for (var i = 0; i < kAppPageKeys.length; i++) {
      final key = kAppPageKeys[i];
      desktop[key] = (map[key] ?? true) as bool;
      mobile[key] = (map['${key}_mobile'] ?? true) as bool;
      order[key] = (map['${key}_order'] as num?)?.toInt() ?? i;
    }

    return PageVisibilitySettings(
      desktop: desktop,
      mobile: mobile,
      order: order,
    );
  }

  /// Payload completo para upsert (o webapp também grava a linha inteira).
  Map<String, dynamic> toMap() {
    final payload = <String, dynamic>{'id': 1};
    for (final key in kAppPageKeys) {
      payload[key] = desktopVisible(key);
      payload['${key}_mobile'] = mobileVisible(key);
      payload['${key}_order'] = orderOf(key);
    }
    return payload;
  }
}
