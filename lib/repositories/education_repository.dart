import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/education_content.dart';

/// Conteúdos educacionais ativos (tabela `education_content`).
class EducationRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<EducationContent>> fetchEducationContent() async {
    final data = await _client
        .from('education_content')
        .select()
        .eq('status', 'Ativo')
        .order('published_at', ascending: false);
    return (data as List)
        .map((row) => EducationContent.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Registra um clique no conteúdo (tabela `education_clicks`).
  Future<void> registerClick({
    required String contentId,
    String? userId,
  }) async {
    await _client.from('education_clicks').insert({
      'education_content_id': contentId,
      'user_id': ?userId,
    });
  }
}
