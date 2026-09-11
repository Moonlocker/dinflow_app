import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/page_visibility.dart';

/// Acesso à tabela `page_visibility_settings` (id = 1).
class PageVisibilityRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<PageVisibilitySettings?> fetch() async {
    final data = await _client
        .from('page_visibility_settings')
        .select()
        .eq('id', 1)
        .maybeSingle();
    if (data == null) return null;
    return PageVisibilitySettings.fromMap(data);
  }

  Future<void> save(PageVisibilitySettings settings) async {
    await _client
        .from('page_visibility_settings')
        .upsert({'id': 1, ...settings.toMap()});
  }
}
