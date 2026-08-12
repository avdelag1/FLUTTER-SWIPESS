class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    this.alertsEnabled = false,
    this.filters = const {},
    this.createdAt,
  });

  final String id;
  final String name;
  final bool alertsEnabled;
  final Map<String, dynamic> filters;
  final DateTime? createdAt;

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    final filters = json['filters'];
    return SavedSearch(
      id: json['id']?.toString() ?? '',
      name: (json['search_name'] as String?) ??
          (json['name'] as String?) ??
          'Saved search',
      alertsEnabled: json['alerts_enabled'] == true,
      filters: filters is Map
          ? Map<String, dynamic>.from(filters)
          : const {},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  String get summary {
    final parts = <String>[];
    final city = filters['city'];
    final category = filters['category'] ?? filters['property_type'];
    final min = filters['min_price'];
    final max = filters['max_price'];
    if (city != null && city.toString().isNotEmpty) parts.add('$city');
    if (category != null && category.toString().isNotEmpty) parts.add('$category');
    if (min != null || max != null) {
      parts.add('\$${min ?? 0}–\$${max ?? '∞'}');
    }
    return parts.isEmpty ? 'No filters' : parts.join(' · ');
  }
}
