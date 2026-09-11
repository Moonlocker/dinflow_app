import 'package:flutter/material.dart';

/// Mapeamento das chaves de ícone de categoria usadas no webapp para ícones
/// equivalentes do Material, garantindo que a mesma chave (`home`, `food`,
/// `salary`, ...) continue sendo gravada no banco.
const Map<String, IconData> categoryIconMap = {
  'home': Icons.home_outlined,
  'car': Icons.directions_car_outlined,
  'gas': Icons.local_gas_station_outlined,
  'bus': Icons.directions_bus_outlined,
  'taxi': Icons.local_taxi_outlined,
  'food': Icons.restaurant_outlined,
  'coffee': Icons.local_cafe_outlined,
  'shopping': Icons.shopping_cart_outlined,
  'bag': Icons.shopping_bag_outlined,
  'clothes': Icons.checkroom_outlined,
  'education': Icons.school_outlined,
  'book': Icons.menu_book_outlined,
  'entertainment': Icons.sports_esports_outlined,
  'music': Icons.music_note_outlined,
  'travel': Icons.flight_outlined,
  'health': Icons.medical_services_outlined,
  'fitness': Icons.fitness_center_outlined,
  'phone': Icons.phone_outlined,
  'wifi': Icons.wifi_outlined,
  'electricity': Icons.bolt_outlined,
  'water': Icons.water_drop_outlined,
  'savings': Icons.savings_outlined,
  'money': Icons.payments_outlined,
  'credit': Icons.credit_card_outlined,
  'investment': Icons.trending_up,
  'salary': Icons.work_outline,
  'income': Icons.attach_money,
  'gift': Icons.card_giftcard_outlined,
  'heart': Icons.favorite_border,
  'tools': Icons.build_outlined,
};

const List<String> categoryIconKeys = [
  'home',
  'car',
  'gas',
  'bus',
  'taxi',
  'food',
  'coffee',
  'shopping',
  'bag',
  'clothes',
  'education',
  'book',
  'entertainment',
  'music',
  'travel',
  'health',
  'fitness',
  'phone',
  'wifi',
  'electricity',
  'water',
  'savings',
  'money',
  'credit',
  'investment',
  'salary',
  'income',
  'gift',
  'heart',
  'tools',
];

IconData categoryIconFor(String? key) {
  if (key == null) return Icons.home_outlined;
  return categoryIconMap[key] ?? Icons.home_outlined;
}

/// Paleta de cores oferecida no cadastro de categorias.
const List<String> categoryColorPalette = [
  '#1ABC9C',
  '#10B981',
  '#3B82F6',
  '#8B5CF6',
  '#F59E0B',
  '#EF4444',
  '#EC4899',
  '#14B8A6',
  '#6366F1',
  '#F97316',
  '#84CC16',
  '#6B7280',
];

Color colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF6B7280);
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return const Color(0xFF6B7280);
  return Color(parsed);
}
