import 'package:flutter/foundation.dart' show ChangeNotifier;

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
  }
}
