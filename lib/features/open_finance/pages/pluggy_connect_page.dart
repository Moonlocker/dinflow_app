import 'package:flutter/material.dart';
import 'package:flutter_pluggy_connect/flutter_pluggy_connect.dart';

import '../../../core/config/app_config.dart';

/// Abre o Pluggy Connect (fluxo oficial). Nunca coletamos credenciais
/// bancárias: o widget da Pluggy cuida de login/MFA com segurança.
///
/// Retorna via `Navigator.pop` o `itemId` quando a conexão é concluída,
/// ou `null` se o usuário fechar sem concluir.
class PluggyConnectPage extends StatelessWidget {
  const PluggyConnectPage({super.key, required this.connectToken, this.itemId});

  final String connectToken;
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar banco')),
      body: PluggyConnect(
        connectToken: connectToken,
        includeSandbox: AppConfig.openFinanceSandbox,
        updateItem: itemId,
        onSuccess: (data) {
          final resolved = _extractItemId(data);
          Navigator.of(context).pop(resolved);
        },
        onError: (error) {
          final message = error is Map
              ? (error['message']?.toString() ?? 'Não foi possível conectar.')
              : 'Não foi possível conectar.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
        onClose: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  String? _extractItemId(dynamic data) {
    if (data is Map) {
      final item = data['item'];
      if (item is Map && item['id'] != null) return item['id'].toString();
      if (data['id'] != null) return data['id'].toString();
    }
    return null;
  }
}
