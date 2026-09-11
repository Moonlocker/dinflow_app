import 'package:flutter/material.dart';

/// Tokens semânticos de cor do DinFlow.
///
/// Espelham os CSS variables de `dinflow/src/index.css` e
/// `dinflow/tailwind.config.js` para preservar a identidade visual do webapp.
class AppColors {
  const AppColors._();

  // Marca
  static const Color primary = Color(0xFF1ABC9C);
  static const Color primaryLight = Color(0xFF28E2BC);
  static const Color primaryDark = Color(0xFF149077);

  // Semânticas (iguais em ambos os temas)
  static const Color success = Color(0xFF1ABC9C);
  static const Color warning = Color(0xFFF97415);
  static const Color danger = Color(0xFFD03232);
  static const Color income = Color(0xFF10B981);
  static const Color expense = Color(0xFFEF4444);
  static const Color balance = Color(0xFF3B82F6);

  // Cores auxiliares usadas nos gráficos / cards do dashboard
  static const Color emerald = Color(0xFF10B981);
  static const Color red = Color(0xFFEF4444);
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color orange = Color(0xFFF97316);
  static const Color amber = Color(0xFFF59E0B);

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: primaryLight,
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFFF4F5F6),
    onSecondary: Color(0xFF22262A),
    secondaryContainer: Color(0xFFF4F5F6),
    onSecondaryContainer: Color(0xFF22262A),
    tertiary: primary,
    onTertiary: Colors.white,
    error: danger,
    onError: Colors.white,
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF22262A),
    surfaceContainerHighest: Color(0xFFF4F5F6),
    onSurfaceVariant: Color(0xFF66737F),
    outline: Color(0xFFE3E6E8),
    outlineVariant: Color(0xFFE3E6E8),
    shadow: Color(0x1A000000),
    scrim: Color(0x80000000),
    inverseSurface: Color(0xFF22262A),
    onInverseSurface: Color(0xFFF9FAFB),
    inversePrimary: primaryLight,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: primaryDark,
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF2D3339),
    onSecondary: Color(0xFFF9FAFB),
    secondaryContainer: Color(0xFF2D3339),
    onSecondaryContainer: Color(0xFFF9FAFB),
    tertiary: primary,
    onTertiary: Colors.white,
    error: danger,
    onError: Colors.white,
    surface: Color(0xFF22262A),
    onSurface: Color(0xFFF9FAFB),
    surfaceContainerHighest: Color(0xFF2D3339),
    onSurfaceVariant: Color(0xFF9CA3AF),
    outline: Color(0xFF2D3339),
    outlineVariant: Color(0xFF2D3339),
    shadow: Color(0x33000000),
    scrim: Color(0x80000000),
    inverseSurface: Color(0xFFF9FAFB),
    onInverseSurface: Color(0xFF22262A),
    inversePrimary: primaryDark,
  );

  // Fundo das telas (o `background` do web é distinto do `card`)
  static const Color lightBackground = Color(0xFFF3F5F7);
  static const Color darkBackground = Color(0xFF111417);
}
