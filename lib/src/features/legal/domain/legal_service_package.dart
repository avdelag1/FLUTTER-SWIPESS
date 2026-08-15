class LegalServicePackage {
  const LegalServicePackage({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.durationDays,
    this.duration,
    this.features = const [],
    this.isActive = true,
    this.description,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final int? durationDays;
  final String? duration;
  final List<String> features;
  final bool isActive;
  final String? description;

  factory LegalServicePackage.fromJson(Map<String, dynamic> json) {
    return LegalServicePackage(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      durationDays: json['duration_days'] as int?,
      duration: json['duration'] as String?,
      features:
          (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String?,
    );
  }
}
