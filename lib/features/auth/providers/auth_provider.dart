import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/biometric_service.dart';
import '../../../models/global_settings.dart';
import '../../../models/profile.dart';
import '../../../models/subscription.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../../repositories/settings_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Chave local onde o usuário opta pelo desbloqueio biométrico.
const String _biometricPrefKey = 'dinflow_biometric_enabled';

/// Estado global de sessão, perfil, assinatura e configurações globais.
///
/// Espelha o `SimpleAuthContext` do webapp, porém simplificado para o app.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthRepository? authRepository,
    ProfileRepository? profileRepository,
    SettingsRepository? settingsRepository,
    BiometricService? biometricService,
  })  : _auth = authRepository ?? AuthRepository(),
        _profiles = profileRepository ?? ProfileRepository(),
        _settings = settingsRepository ?? SettingsRepository(),
        _biometrics = biometricService ?? BiometricService();

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final SettingsRepository _settings;
  final BiometricService _biometrics;

  StreamSubscription<AuthState>? _authSubscription;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  Profile? _profile;
  Subscription? _subscription;
  GlobalSettings _globalSettings = const GlobalSettings();
  bool _busy = false;
  String? _errorMessage;
  bool _biometricEnabled = false;
  bool _biometricPending = false;

  AuthStatus get status => _status;
  User? get user => _user;
  Profile? get profile => _profile;
  Subscription? get subscription => _subscription;
  GlobalSettings get globalSettings => _globalSettings;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isInitializing => _status == AuthStatus.unknown;

  /// Se o usuário ativou o desbloqueio biométrico neste dispositivo.
  bool get biometricEnabled => _biometricEnabled;

  /// Se uma sessão restaurada ainda aguarda a confirmação biométrica.
  bool get biometricPending => _biometricPending;

  String get displayName => _profile?.displayName ?? _user?.email ?? 'Usuário';

  Future<void> init() async {
    await _loadGlobalSettings();
    await _loadBiometricPreference();

    final session = _auth.currentSession;
    _user = session?.user;
    if (_user != null) {
      await _loadProfileAndSubscription(_user!.id);
      _status = AuthStatus.authenticated;
      // Sessão restaurada no cold start: exige biometria quando habilitada.
      _biometricPending = _biometricEnabled;
    } else {
      _status = AuthStatus.unauthenticated;
      _biometricPending = false;
    }
    notifyListeners();

    _authSubscription = _auth.onAuthStateChange.listen((state) async {
      final session = state.session;
      if (session == null) {
        _user = null;
        _profile = null;
        _subscription = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      final isNewUser = _user?.id != session.user.id;
      _user = session.user;
      if (isNewUser || _profile == null) {
        await _ensureProfile(session.user);
        await _loadProfileAndSubscription(session.user.id);
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
    });
  }

  /// Login social (Google/Apple) via navegador e deep link.
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.signInWithOAuth(
        provider,
        redirectTo: AppConfig.oauthRedirectUrl,
      );
      _busy = false;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Não foi possível iniciar o login social.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _user = response.user;
      if (_user != null) {
        await _ensureProfile(_user!);
        await _loadProfileAndSubscription(_user!.id);
      }
      _status = AuthStatus.authenticated;
      _busy = false;
      notifyListeners();
      return true;
    } on AuthException catch (error) {
      _errorMessage = _translateAuthError(error.message);
      _busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Ocorreu um erro inesperado. Tente novamente.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? whatsapp,
    String? country,
  }) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        metadata: {
          'name': name,
          if (whatsapp != null && whatsapp.isNotEmpty) 'whatsapp': whatsapp,
          if (country != null && country.isNotEmpty) 'country': country,
        },
      );
      _user = response.user;
      if (_user != null) {
        await _ensureProfile(_user!);
        if (response.session != null) {
          await _loadProfileAndSubscription(_user!.id);
          _status = AuthStatus.authenticated;
        }
      }
      _busy = false;
      notifyListeners();
      return true;
    } on AuthException catch (error) {
      _errorMessage = _translateAuthError(error.message);
      _busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Não foi possível criar a conta. Tente novamente.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.sendPasswordResetEmail(email.trim());
      _busy = false;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Não foi possível enviar o email. Verifique o endereço.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Reautentica o usuário (usado para confirmar ações sensíveis).
  Future<bool> verifyPassword(String password) async {
    final email = _user?.email;
    if (email == null) return false;
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.updatePassword(newPassword);
      _busy = false;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Não foi possível alterar a senha. Tente novamente.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> values) async {
    final current = _user;
    if (current == null) return;
    await _profiles.updateProfile(current.id, values);
    await refresh();
  }

  /// Envia um novo avatar e atualiza o perfil do usuário.
  Future<void> uploadAvatar({
    required Uint8List bytes,
    required String extension,
  }) async {
    final current = _user;
    if (current == null) return;
    final url = await _profiles.uploadAvatar(
      userId: current.id,
      bytes: bytes,
      extension: extension,
    );
    await _profiles.updateProfile(current.id, {'avatar_url': url});
    await refresh();
  }

  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    _profile = null;
    _subscription = null;
    _status = AuthStatus.unauthenticated;
    _biometricPending = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_user == null) return;
    await _loadProfileAndSubscription(_user!.id);
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Habilita a exigência de biometria ao reabrir o app com sessão salva.
  ///
  /// Retorna `false` se o dispositivo não oferecer biometria disponível.
  Future<bool> enableBiometric() async {
    final supported = await _biometrics.isSupported();
    if (!supported) return false;
    _biometricEnabled = true;
    await _saveBiometricPreference(true);
    notifyListeners();
    return true;
  }

  Future<void> disableBiometric() async {
    _biometricEnabled = false;
    _biometricPending = false;
    await _saveBiometricPreference(false);
    notifyListeners();
  }

  /// Solicita a autenticação biométrica e libera o app quando confirmada.
  Future<bool> unlockBiometric() async {
    final ok = await _biometrics.authenticate();
    if (ok) {
      _biometricPending = false;
      notifyListeners();
    }
    return ok;
  }

  Future<void> _loadBiometricPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _biometricEnabled = prefs.getBool(_biometricPrefKey) ?? false;
    } catch (_) {
      _biometricEnabled = false;
    }
  }

  Future<void> _saveBiometricPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPrefKey, value);
  }

  Future<void> _loadGlobalSettings() async {
    try {
      final settings = await _settings.fetchGlobalSettings();
      if (settings != null) _globalSettings = settings;
    } catch (_) {
      // Mantém os valores padrão caso a leitura falhe.
    }
  }

  Future<void> _loadProfileAndSubscription(String userId) async {
    try {
      final results = await Future.wait([
        _profiles.fetchProfile(userId),
        _profiles.fetchLatestSubscription(userId),
      ]);
      _profile = results[0] as Profile?;
      _subscription = results[1] as Subscription?;
    } catch (_) {
      _profile = null;
      _subscription = null;
    }
  }

  Future<void> _ensureProfile(User user) async {
    final existing = await _profiles.fetchProfile(user.id);
    if (existing != null) return;

    final name = (user.userMetadata?['name'] as String?) ??
        (user.userMetadata?['full_name'] as String?) ??
        user.email ??
        'Usuário';
    final trialDays = _globalSettings.trialEnabled ? _globalSettings.trialDays : 0;

    try {
      await _auth.createProfileForUser(
        userId: user.id,
        email: user.email ?? '',
        name: name,
        trialDays: trialDays,
      );
    } catch (_) {
      try {
        await _profiles.insertProfile(
          userId: user.id,
          email: user.email ?? '',
          name: name,
          trialEnabled: _globalSettings.trialEnabled,
          trialDays: _globalSettings.trialDays,
        );
      } catch (_) {
        // Sem perfil criado; a próxima leitura tenta novamente.
      }
    }
  }

  String _translateAuthError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'Email ou senha inválidos.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirme seu email antes de entrar.';
    }
    if (normalized.contains('too many requests')) {
      return 'Muitas tentativas. Aguarde alguns instantes.';
    }
    return message;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
