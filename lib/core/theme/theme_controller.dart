import 'package:flutter/material.dart';

/// Controla o tema claro/escuro do app.
///
/// O webapp inicia no tema claro (`ThemeContext` usa `light` como padrão).
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void toggle() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
