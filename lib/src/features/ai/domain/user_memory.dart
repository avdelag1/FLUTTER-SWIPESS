enum MemoryCategory { contact, preference, note, fact }

class UserMemory {
  const UserMemory({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.content,
    this.tags = const [],
    this.source = 'manual',
    this.createdAt,
  });

  final String id;
  final String userId;
  final MemoryCategory category;
  final String title;
  final String content;
  final List<String> tags;
  final String source;
  final DateTime? createdAt;

  factory UserMemory.fromJson(Map<String, dynamic> json) {
    return UserMemory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: _parseCategory(json['category'] as String?),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] is List)
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : const [],
      source: json['source'] as String? ?? 'manual',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static MemoryCategory _parseCategory(String? raw) {
    switch (raw) {
      case 'contact':
        return MemoryCategory.contact;
      case 'preference':
        return MemoryCategory.preference;
      case 'note':
        return MemoryCategory.note;
      default:
        return MemoryCategory.fact;
    }
  }

  String get categoryValue => category.name;
}

extension MemoryCategoryX on MemoryCategory {
  String get label {
    switch (this) {
      case MemoryCategory.contact:
        return 'Contact';
      case MemoryCategory.preference:
        return 'Preference';
      case MemoryCategory.note:
        return 'Note';
      case MemoryCategory.fact:
        return 'Fact';
    }
  }
}
