import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

/// Categorias do usuário (tabela `categories`).
///
/// Se o usuário ainda não tiver nenhuma, replica o comportamento do webapp
/// (`useCategoriesData`): semeia as categorias padrão na primeira consulta.
class CategoriesRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const List<Map<String, dynamic>> _defaultCategories = [
    {'name': 'Salário', 'type': 'income', 'color': '#10b981', 'is_default': true},
    {'name': 'Freelance', 'type': 'income', 'color': '#059669', 'is_default': true},
    {'name': 'Investimentos', 'type': 'income', 'color': '#047857', 'is_default': true},
    {'name': 'Outros', 'type': 'income', 'color': '#6ee7b7', 'is_default': true},
    {'name': 'Alimentação', 'type': 'expense', 'color': '#ef4444', 'is_default': true},
    {'name': 'Transporte', 'type': 'expense', 'color': '#dc2626', 'is_default': true},
    {'name': 'Lazer', 'type': 'expense', 'color': '#b91c1c', 'is_default': true},
    {'name': 'Saúde', 'type': 'expense', 'color': '#991b1b', 'is_default': true},
    {'name': 'Educação', 'type': 'expense', 'color': '#7f1d1d', 'is_default': true},
    {'name': 'Casa', 'type': 'expense', 'color': '#f59e0b', 'is_default': true},
    {'name': 'Outros', 'type': 'expense', 'color': '#6b7280', 'is_default': true},
  ];

  Future<List<Category>> fetchCategories(String userId) async {
    final data = await _client
        .from('categories')
        .select()
        .eq('user_id', userId)
        .order('name', ascending: true);

    final list = data as List;
    if (list.isEmpty) {
      final payload = _defaultCategories
          .map((category) => {...category, 'user_id': userId})
          .toList();
      final inserted =
          await _client.from('categories').insert(payload).select();
      return (inserted as List)
          .map((row) => Category.fromMap(row as Map<String, dynamic>))
          .toList();
    }

    return list
        .map((row) => Category.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Category> createCategory(String userId, Map<String, dynamic> values) async {
    final data = await _client
        .from('categories')
        .insert({...values, 'user_id': userId, 'is_default': false})
        .select()
        .single();
    return Category.fromMap(data);
  }

  Future<Category> updateCategory({
    required String id,
    required String userId,
    required Map<String, dynamic> values,
  }) async {
    final data = await _client
        .from('categories')
        .update(values)
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
    return Category.fromMap(data);
  }

  /// Exclui a categoria movendo as transações para a categoria "Outros"
  /// do mesmo tipo, igual ao webapp.
  Future<void> deleteCategory({
    required String id,
    required String userId,
    required List<Category> categories,
  }) async {
    Category? target;
    for (final category in categories) {
      if (category.id == id) {
        target = category;
        break;
      }
    }
    if (target == null) return;

    Category? fallback;
    for (final category in categories) {
      if (category.type == target.type && category.name.toLowerCase() == 'outros') {
        fallback = category;
        break;
      }
    }

    if (fallback != null) {
      await _client
          .from('transactions')
          .update({'category_id': fallback.id})
          .eq('category_id', id)
          .eq('user_id', userId);
    }

    await _client.from('categories').delete().eq('id', id).eq('user_id', userId);
  }
}
