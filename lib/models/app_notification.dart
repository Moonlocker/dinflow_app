/// Notificação do usuário — tabela `public.notifications`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? body;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: (map['title'] ?? '') as String,
      body: map['body'] as String?,
      readAt: _parseDate(map['read_at']),
      createdAt: _parseDate(map['created_at']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
