import 'package:flutter/foundation.dart';

import '../../../repositories/whatsapp_numbers_repository.dart';

/// Autor (número de WhatsApp) usado para atribuir/filtrar lançamentos.
class AuthorOption {
  const AuthorOption({
    required this.name,
    required this.whatsapp,
    required this.isMain,
  });

  final String name;
  final String whatsapp;
  final bool isMain;
}

/// Gerencia os autores disponíveis (número principal + extras) e a seleção.
class AuthorProvider extends ChangeNotifier {
  AuthorProvider({WhatsappNumbersRepository? repository})
      : _repository = repository ?? WhatsappNumbersRepository();

  final WhatsappNumbersRepository _repository;

  List<AuthorOption> _authors = const [];
  AuthorOption? _selected;
  bool _loading = false;

  List<AuthorOption> get authors => _authors;
  AuthorOption? get selected => _selected;
  bool get loading => _loading;
  bool get hasMultiple => _authors.length > 1;

  /// Número a ser atribuído aos lançamentos (selecionado ou principal).
  String? get effectiveWhatsapp =>
      _selected?.whatsapp ??
      (_authors.isNotEmpty ? _authors.first.whatsapp : null);

  Future<void> load({
    required String userId,
    String? mainWhatsapp,
    String? mainName,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final extras = await _repository.fetch(userId);
      final authors = <AuthorOption>[
        if (mainWhatsapp != null && mainWhatsapp.isNotEmpty)
          AuthorOption(
            name: (mainName != null && mainName.trim().isNotEmpty)
                ? mainName.trim()
                : 'Principal',
            whatsapp: mainWhatsapp,
            isMain: true,
          ),
        for (final extra in extras)
          AuthorOption(name: extra.name, whatsapp: extra.whatsapp, isMain: false),
      ];
      _authors = authors;
      // Mantém a seleção se ainda existir; caso contrário volta para "Todos".
      if (_selected != null) {
        final match = authors.where((a) => a.whatsapp == _selected!.whatsapp);
        _selected = match.isEmpty ? null : match.first;
      }
    } catch (_) {
      // Mantém o estado atual.
    }
    _loading = false;
    notifyListeners();
  }

  void select(AuthorOption? author) {
    _selected = author;
    notifyListeners();
  }
}
