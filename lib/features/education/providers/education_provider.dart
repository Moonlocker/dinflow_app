import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/realtime/realtime_utils.dart';
import '../../../models/education_content.dart';
import '../../../repositories/education_repository.dart';

/// Conteúdos educacionais ativos.
class EducationProvider extends ChangeNotifier {
  EducationProvider({EducationRepository? repository})
      : _repository = repository ?? EducationRepository();

  final EducationRepository _repository;

  List<EducationContent> _items = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  RealtimeChannel? _channel;
  Timer? _debounce;

  List<EducationContent> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _repository.fetchEducationContent();
      _loaded = true;
    } catch (_) {
      _error = 'Não foi possível carregar os conteúdos. Tente novamente.';
    }

    _loading = false;
    notifyListeners();
    _subscribe();
  }

  /// Registra o clique do usuário em um conteúdo (best-effort).
  Future<void> registerClick(EducationContent item, String? userId) async {
    try {
      await _repository.registerClick(contentId: item.id, userId: userId);
    } catch (_) {
      // Não bloqueia a abertura do conteúdo se o registro falhar.
    }
  }

  void _subscribe() {
    if (_channel != null) return;
    _channel = Supabase.instance.client
        .channel(realtimeChannelName('education-content'))
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'education_content',
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      load(force: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
