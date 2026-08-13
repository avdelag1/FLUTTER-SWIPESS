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
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final int? durationDays;
  final String? duration;
  final List<String> features;
  final bool isActive;

  factory LegalServicePackage.fromJson(Map<String, dynamic> json) {
    return LegalServicePackage(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      durationDays: json['duration_days'] as int?,
      duration: json['duration'] as String?,
      features: (json['features'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
