import 'package:local_auth/local_auth.dart';

/// Abstração sobre `local_auth` para o desbloqueio biométrico do DinFlow.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Informa se o dispositivo possui biometria disponível e configurada.
  Future<bool> isSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return canCheck && deviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Solicita a autenticação biométrica (fingerprint / Face ID).
  Future<bool> authenticate({
    String reason = 'Desbloqueie o DinFlow com sua biometria',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}