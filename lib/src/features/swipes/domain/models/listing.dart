/// Domain model for a listing in the Swipess ecosystem.
///
/// Maps directly to the Supabase `listings` table, using only the fields
/// fetched by the swipe card feed query (SWIPE_CARD_FIELDS).
class Listing {
  final String id;
  final String? ownerId;
  final String? title;
  final String? description;
  final String? category; // property, motorcycle, bicycle, yacht, worker
  final String? listingType; // rent, sale
  final String? propertyType; // apartment, villa, studio
  final double? price;
  final double? previousPrice;
  final String? pricingUnit;
  final String? currency;
  final String? city;
  final String? neighborhood;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? bedrooms;
  final int? beds;
  final double? bathrooms;
  final double? baths;
  final double? squareFootage;
  final bool? furnished;
  final bool? petFriendly;
  final List<String> amenities;
  final List<String> images;
  final String? videoUrl;
  final String? status;
  final bool? isActive;
  final int? likes;
  final int? views;
  /// Cap `has_verified_documents` — drives the violet Verified pill on swipe.
  final bool hasVerifiedDocuments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Vehicle fields
  final String? vehicleBrand;
  final String? vehicleModel;
  final int? year;
  final int? mileage;
  // Worker fields
  final String? serviceCategory;
  final int? experienceYears;
  final String? experienceLevel;

  const Listing({
    required this.id,
    this.ownerId,
    this.title,
    this.description,
    this.category,
    this.listingType,
    this.propertyType,
    this.price,
    this.previousPrice,
    this.pricingUnit,
    this.currency,
    this.city,
    this.neighborhood,
    this.location,
    this.latitude,
    this.longitude,
    this.bedrooms,
    this.beds,
    this.bathrooms,
    this.baths,
    this.squareFootage,
    this.furnished,
    this.petFriendly,
    this.amenities = const [],
    this.images = const [],
    this.videoUrl,
    this.status,
    this.isActive,
    this.likes,
    this.views,
    this.hasVerifiedDocuments = false,
    this.createdAt,
    this.updatedAt,
    this.vehicleBrand,
    this.vehicleModel,
    this.year,
    this.mileage,
    this.serviceCategory,
    this.experienceYears,
    this.experienceLevel,
  });

  /// Parse from Supabase JSON row.
  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      listingType: json['listing_type'] as String?,
      propertyType: json['property_type'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      previousPrice: (json['previous_price'] as num?)?.toDouble(),
      pricingUnit: json['pricing_unit'] as String?,
      currency: json['currency'] as String? ?? 'USD',
      city: json['city'] as String?,
      neighborhood: json['neighborhood'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      bedrooms: json['bedrooms'] as int?,
      beds: json['beds'] as int?,
      bathrooms: (json['bathrooms'] as num?)?.toDouble(),
      baths: (json['baths'] as num?)?.toDouble(),
      squareFootage: (json['square_footage'] as num?)?.toDouble(),
      furnished: json['furnished'] as bool?,
      petFriendly: json['pet_friendly'] as bool?,
      amenities: _parseStringList(json['amenities']),
      images: _parseStringList(json['images']),
      videoUrl: json['video_url'] as String?,
      status: json['status'] as String?,
      isActive: json['is_active'] as bool?,
      likes: json['likes'] as int?,
      views: json['views'] as int?,
      hasVerifiedDocuments: json['has_verified_documents'] == true ||
          json['background_check_verified'] == true ||
          json['insurance_verified'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      year: json['year'] as int?,
      mileage: json['mileage'] as int?,
      serviceCategory: json['service_category'] as String?,
      experienceYears: json['experience_years'] as int?,
      experienceLevel: json['experience_level'] as String?,
    );
  }

  /// Primary image URL for the swipe card.
  String? get primaryImage => images.isNotEmpty ? images.first : null;

  /// Formatted price display.
  String get formattedPrice {
    if (price == null) return 'Price TBD';
    final sym = currency == 'USD' ? '\$' : currency ?? '\$';
    final p = price!.toStringAsFixed(price! % 1 == 0 ? 0 : 2);
    final unit = pricingUnit != null ? '/$pricingUnit' : '';
    return '$sym$p$unit';
  }

  /// Formatted location display.
  String get formattedLocation {
    final parts = [neighborhood, city].where((s) => s != null && s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(', ') : 'Location TBD';
  }

  /// Build a short tagline for the card (e.g. "2 bed · 1 bath · 850 sqft").
  List<String> get quickTags {
    final tags = <String>[];
    if (beds != null && beds! > 0) tags.add('$beds bed');
    if (baths != null && baths! > 0) tags.add('${baths!.toStringAsFixed(baths! % 1 == 0 ? 0 : 1)} bath');
    if (squareFootage != null && squareFootage! > 0) tags.add('${squareFootage!.toStringAsFixed(0)} sqft');
    if (furnished == true) tags.add('Furnished');
    if (petFriendly == true) tags.add('Pet Friendly');
    return tags;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}
