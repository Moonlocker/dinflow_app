import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/global_settings.dart';

/// Configurações globais/branding (tabela `global_settings`, id = 1).
class SettingsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<GlobalSettings?> fetchGlobalSettings() async {
    final data =
        await _client.from('global_settings').select().eq('id', 1).maybeSingle();
    if (data == null) return null;
    return GlobalSettings.fromMap(data);
  }
}
