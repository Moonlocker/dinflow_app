import 'package:flutter/material.dart';

/// Categoria financeira — tabela `public.categories`.
class Category {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.color,
    this.icon,
    this.isDefault = false,
  });

  final String id;
  final String userId;
  final String name;
  final String type; // 'income' | 'expense'
  final String? color;
  final String? icon;
  final bool isDefault;

  Color get parsedColor {
    final raw = color;
    if (raw == null || raw.isEmpty) return Colors.grey;
    final hex = raw.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return Colors.grey;
    return Color(0xFF000000 | value);
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: (map['name'] ?? '') as String,
      type: (map['type'] ?? 'expense') as String,
      color: map['color'] as String?,
      icon: map['icon'] as String?,
      isDefault: (map['is_default'] ?? false) as bool,
    );
  }
}
