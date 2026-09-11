import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/page_visibility.dart';
import '../../../repositories/page_visibility_repository.dart';

/// Mantém a configuração de visibilidade/ordem das páginas definida pelo
/// superadmin no webapp, aplicando-a à navegação do aplicativo.
class PageVisibilityProvider extends ChangeNotifier {
  PageVisibilityProvider({PageVisibilityRepository? repository})
      : _repository = repository ?? PageVisibilityRepository();

  final PageVisibilityRepository _repository;

  PageVisibilitySettings _settings = PageVisibilitySettings.defaults();
  bool _loading = false;
  bool _loaded = false;
  RealtimeChannel? _channel;

  PageVisibilitySettings get settings => _settings;
  bool get loading => _loading;
  bool get loaded => _loaded;

  bool desktopVisible(String key) => _settings.desktopVisible(key);

  bool mobileVisible(String key) => _settings.mobileVisible(key);

  bool visibleAnywhere(String key) => _settings.visibleAnywhere(key);

  List<String> orderedMobileKeys() => _settings.orderedMobileKeys();

  List<String> orderedDesktopKeys() => _settings.orderedDesktopKeys();

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;

    _loading = true;
    notifyListeners();

    try {
      final settings = await _repository.fetch();
      if (settings != null) _settings = settings;
      _loaded = true;
    } catch (_) {
      // Mantém os valores padrão caso a leitura falhe.
    } finally {
      _loading = false;
      notifyListeners();
    }

    _subscribeRealtime();
  }

  Future<void> save(PageVisibilitySettings settings) async {
    _settings = settings;
    notifyListeners();
    await _repository.save(settings);
  }

  Future<void> setDesktopVisible(String key, bool value) async {
    final desktop = Map<String, bool>.from(_settings.desktop)..[key] = value;
    await save(_settings.copyWith(desktop: desktop));
  }

  Future<void> setMobileVisible(String key, bool value) async {
    final mobile = Map<String, bool>.from(_settings.mobile)..[key] = value;
    await save(_settings.copyWith(mobile: mobile));
  }

  Future<void> setOrder(List<String> keys) async {
    final order = <String, int>{};
    for (var i = 0; i < keys.length; i++) {
      order[keys[i]] = i;
    }
    await save(_settings.copyWith(order: order));
  }

  void _subscribeRealtime() {
    if (_channel != null) return;
    _channel = Supabase.instance.client
        .channel('page-visibility-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'page_visibility_settings',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              _settings = PageVisibilitySettings.fromMap(record);
              _loaded = true;
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
