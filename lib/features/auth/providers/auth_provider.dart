import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/global_settings.dart';
import '../../../models/profile.dart';
import '../../../models/subscription.dart';
import '../../../repositories/auth_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../../repositories/settings_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Estado global de sessão, perfil, assinatura e configurações globais.
///
/// Espelha o `SimpleAuthContext` do webapp, porém simplificado para o app.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthRepository? authRepository,
    ProfileRepository? profileRepository,
    SettingsRepository? settingsRepository,
  })  : _auth = authRepository ?? AuthRepository(),
        _profiles = profileRepository ?? ProfileRepository(),
        _settings = settingsRepository ?? SettingsRepository();

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final SettingsRepository _settings;

  StreamSubscription<AuthState>? _authSubscription;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  Profile? _profile;
  Subscription? _subscription;
  GlobalSettings _globalSettings = const GlobalSettings();
  bool _busy = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  Profile? get profile => _profile;
  Subscription? get subscription => _subscription;
  GlobalSettings get globalSettings => _globalSettings;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isInitializing => _status == AuthStatus.unknown;

  String get displayName => _profile?.displayName ?? _user?.email ?? 'Usuário';

  Future<void> init() async {
    await _loadGlobalSettings();

    final session = _auth.currentSession;
    _user = session?.user;
    if (_user != null) {
      await _loadProfileAndSubscription(_user!.id);
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
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
      _user = session.user;
      _status = AuthStatus.authenticated;
      notifyListeners();
    });
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

  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    _profile = null;
    _subscription = null;
    _status = AuthStatus.unauthenticated;
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
