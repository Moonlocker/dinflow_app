/// Número de WhatsApp adicional do usuário — tabela `user_whatsapp_numbers`.
class WhatsappNumber {
  const WhatsappNumber({
    required this.id,
    required this.userId,
    required this.whatsapp,
    required this.name,
    this.country = 'BR',
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String whatsapp;
  final String name;
  final String country;
  final bool isActive;

  factory WhatsappNumber.fromMap(Map<String, dynamic> map) {
    return WhatsappNumber(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      whatsapp: (map['whatsapp'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      country: (map['country'] ?? 'BR') as String,
      isActive: (map['is_active'] ?? true) as bool,
    );
  }
}
