import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/providers/auth_provider.dart';
import '../models/global_settings.dart';

/// Logo do DinFlow. Usa o logo configurado em `global_settings` quando
/// disponível; caso contrário exibe o fallback de marca (letra + nome).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 40, this.showTextFallback = true});

  final double height;
  final bool showTextFallback;

  @override
  Widget build(BuildContext context) {
    final settings =
        context.select<AuthProvider, GlobalSettings>((auth) => auth.globalSettings);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final logoUrl =
        isDark ? (settings.logoUrlDark ?? settings.logoUrl) : settings.logoUrl;

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Image.network(
        logoUrl,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallback(context, settings.appName),
      );
    }

    if (!showTextFallback) return const SizedBox.shrink();
    return _fallback(context, settings.appName);
  }

  Widget _fallback(BuildContext context, String appName) {
    final theme = Theme.of(context);
    final initial = appName.isNotEmpty ? appName[0].toUpperCase() : 'D';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: height,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(height / 4),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: height * 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          appName,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: height * 0.55,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
