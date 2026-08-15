class SeekerRequest {
  const SeekerRequest({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.price,
    this.serviceCategory,
    this.description,
    this.availableFrom,
    this.pricingUnit,
    this.status,
    this.ownerId,
    this.seekerName = 'Anonymous',
    this.seekerAvatar,
    this.timeSlots = const [],
    this.daysAvailable = const [],
    this.minimumBookingHours,
  });

  final String id;
  final String title;
  final String category;
  final String location;
  final double price;
  final String? serviceCategory;
  final String? description;
  final DateTime? availableFrom;
  final String? pricingUnit;
  final String? status;
  final String? ownerId;
  final String seekerName;
  final String? seekerAvatar;
  final List<String> timeSlots;
  final List<String> daysAvailable;
  final int? minimumBookingHours;

  String get initials {
    final parts = seekerName.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }

  String get priceLabel {
    if (price <= 0) return 'Budget TBD';
    final unit = pricingUnit == null || pricingUnit!.isEmpty
        ? ''
        : '/$pricingUnit';
    return '\$${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}$unit';
  }

  factory SeekerRequest.fromJson(
    Map<String, dynamic> json, {
    String? seekerName,
    String? seekerAvatar,
  }) {
    return SeekerRequest(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Service request',
      category:
          (json['category'] as String?) ??
          (json['service_category'] as String?) ??
          'other',
      serviceCategory: json['service_category'] as String?,
      description: json['description'] as String?,
      availableFrom: json['available_from'] != null
          ? DateTime.tryParse(json['available_from'] as String)
          : null,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      pricingUnit: json['pricing_unit'] as String?,
      location:
          (json['location'] as String?) ??
          (json['city'] as String?) ??
          'Location TBD',
      status: json['status'] as String?,
      ownerId: json['owner_id'] as String?,
      seekerName: seekerName ?? 'Anonymous',
      seekerAvatar: seekerAvatar,
      timeSlots: _stringList(json['time_slots_available']),
      daysAvailable: _stringList(json['days_available']),
      minimumBookingHours: (json['minimum_booking_hours'] as num?)?.toInt(),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) {
          if (e is String) return e;
          if (e is Map && e['start'] != null) return e['start'].toString();
          return e.toString();
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
