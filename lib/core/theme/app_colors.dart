import 'package:flutter/material.dart';

/// Tokens semânticos de cor do DinFlow.
///
/// A versão mobile usa uma identidade premium focada no tema escuro:
/// fundo quase preto, cartões em cinza-escuro e destaque em verde-menta.
class AppColors {
  const AppColors._();

  // Marca
  static const Color primary = Color(0xFF1ABC9C);
  static const Color primaryLight = Color(0xFF28E2BC);
  static const Color primaryDark = Color(0xFF149077);

  // Destaque do tema escuro: verde-menta (#8BE0C4) dos designs de referência.
  static const Color mint = Color(0xFF8BE0C4);
  static const Color mintDark = Color(0xFF1C3A30);
  static const Color onMint = Color(0xFF0C1B15);

  // Semânticas (iguais em ambos os temas)
  static const Color success = Color(0xFF1ABC9C);
  static const Color warning = Color(0xFFF59E0B);
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
    primary: mint,
    onPrimary: onMint,
    primaryContainer: mintDark,
    onPrimaryContainer: mint,
    secondary: Color(0xFF1D1F23),
    onSecondary: Color(0xFFF2F5F4),
    secondaryContainer: Color(0xFF23262B),
    onSecondaryContainer: Color(0xFFF2F5F4),
    tertiary: mint,
    onTertiary: onMint,
    error: Color(0xFFFF6B60),
    onError: Color(0xFF3A0D0A),
    surface: Color(0xFF1D1F23),
    onSurface: Color(0xFFF2F5F4),
    surfaceContainerHighest: Color(0xFF23262B),
    onSurfaceVariant: Color(0xFF9AA6A0),
    outline: Color(0xFF2A2E33),
    outlineVariant: Color(0xFF24282D),
    shadow: Color(0x40000000),
    scrim: Color(0x80000000),
    inverseSurface: Color(0xFFF2F5F4),
    onInverseSurface: Color(0xFF111315),
    inversePrimary: mintDark,
  );

  // Fundo das telas (o `background` do web é distinto do `card`)
  static const Color lightBackground = Color(0xFFF3F5F7);
  static const Color darkBackground = Color(0xFF111315);
}