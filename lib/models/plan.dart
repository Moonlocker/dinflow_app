/// Plano de assinatura — tabela `public.plans`.
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.recurrence,
    this.status = 'Ativo',
    this.features = const [],
    this.whatsappNumbersLimit = 1,
    this.stripeProductId,
  });

  final String id;
  final String name;
  final double price;
  final String recurrence;
  final String status;
  final List<String> features;
  final int whatsappNumbersLimit;
  final String? stripeProductId;

  bool get isActive => status == 'Ativo';

  String get recurrenceLabel {
    switch (recurrence) {
      case 'monthly':
        return 'Mensal';
      case 'quarterly':
        return 'Trimestral';
      case 'semiannually':
        return 'Semestral';
      case 'yearly':
        return 'Anual';
      default:
        return recurrence;
    }
  }

  factory Plan.fromMap(Map<String, dynamic> map) {
    final rawFeatures = map['features'];
    return Plan(
      id: map['id'] as String,
      name: (map['name'] ?? '') as String,
      price: ((map['price'] ?? 0) as num).toDouble(),
      recurrence: (map['recurrence'] ?? 'monthly') as String,
      status: (map['status'] ?? 'Ativo') as String,
      features: rawFeatures is List
          ? rawFeatures.map((item) => item.toString()).toList()
          : const [],
      whatsappNumbersLimit:
          ((map['whatsapp_numbers_limit'] ?? 1) as num).toInt(),
      stripeProductId: map['stripe_product_id'] as String?,
    );
  }
}
