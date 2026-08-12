class LocalIntelPost {
  const LocalIntelPost({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.neighborhood,
    this.imageUrl,
    this.sourceUrl,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String content;
  final String category;
  final String? neighborhood;
  final String? imageUrl;
  final String? sourceUrl;
  final DateTime? publishedAt;

  factory LocalIntelPost.fromJson(Map<String, dynamic> json) {
    return LocalIntelPost(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Update',
      content: (json['content'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'general',
      neighborhood: json['neighborhood'] as String?,
      imageUrl: json['image_url'] as String?,
      sourceUrl: json['source_url'] as String?,
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    );
  }
}
