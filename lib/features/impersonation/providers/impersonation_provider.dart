import 'package:flutter/foundation.dart';

import '../../../models/profile.dart';

/// Permite que o superadmin navegue no app como outro usuário.
class ImpersonationProvider extends ChangeNotifier {
  Profile? _impersonated;

  bool get isImpersonating => _impersonated != null;
  Profile? get impersonatedProfile => _impersonated;
  String? get impersonatedUserId => _impersonated?.id;

  void start(Profile profile) {
    _impersonated = profile;
    notifyListeners();
  }

  void stop() {
    if (_impersonated == null) return;
    _impersonated = null;
    notifyListeners();
  }
}
