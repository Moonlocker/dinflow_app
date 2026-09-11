/// Conteúdo educacional — tabela `public.education_content`.
class EducationContent {
  const EducationContent({
    required this.id,
    required this.title,
    this.description,
    this.type = 'Artigo',
    this.link,
    this.coverImage,
    this.publishedAt,
    this.clicks = 0,
  });

  final String id;
  final String title;
  final String? description;
  final String type; // 'Artigo' | 'Vídeo' | 'Link Externo'
  final String? link;
  final String? coverImage;
  final DateTime? publishedAt;
  final int clicks;

  factory EducationContent.fromMap(Map<String, dynamic> map) {
    return EducationContent(
      id: map['id'] as String,
      title: (map['title'] ?? '') as String,
      description: map['description'] as String?,
      type: (map['type'] ?? 'Artigo') as String,
      link: map['link'] as String?,
      coverImage: map['cover_image'] as String?,
      publishedAt: map['published_at'] == null
          ? null
          : DateTime.tryParse(map['published_at'].toString()),
      clicks: (map['clicks'] as num?)?.toInt() ?? 0,
    );
  }
}
