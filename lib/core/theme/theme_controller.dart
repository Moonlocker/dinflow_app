import 'package:flutter/material.dart';

/// Controla o tema claro/escuro do app.
///
/// O app inicia no tema escuro (identidade visual premium do mobile);
/// o usuário ainda pode alternar pelo ícone no cabeçalho.
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void toggle() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
