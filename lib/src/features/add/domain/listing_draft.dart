import 'package:cross_file/cross_file.dart';

enum ListingCategory { property, motorcycle, bicycle, yacht, worker }

enum ListingMode { rent, sale, both }

class ListingDraft {
  const ListingDraft({
    this.step = 0,
    this.category = ListingCategory.property,
    this.mode = ListingMode.rent,
    this.photos = const [],
    this.video,
    this.legalDocuments = const [],
    this.title = '',
    this.description = '',
    this.price = '',
    this.currency = 'USD',
    this.city = '',
    this.country = 'Mexico',
    this.neighborhood = '',
    this.adjectives = const [],
    this.sizes = const [],
    this.propertyType,
    this.beds,
    this.baths,
    this.vibe = const [],
    this.amenities = const [],
    this.included = const [],
    this.rules = const [],
    this.furnished = false,
    this.petFriendly = false,
    this.rentalDuration,
    this.brand,
    this.model,
    this.year = '',
    this.mileage = '',
    this.engineCc = '',
    this.vehicleType,
    this.condition,
    this.features = const [],
    this.vehicleIncluded = const [],
    this.frameSize,
    this.lengthM = '',
    this.berths = '',
    this.maxPassengers = '',
    this.serviceCategory,
    this.traits = const [],
    this.skills = const [],
    this.availability = const [],
    this.pricingUnit,
    this.languages = const [],
    this.publishing = false,
    this.error,
  });

  final int step;
  final ListingCategory category;
  final ListingMode mode;
  final List<XFile> photos;

  /// Optional Cap 10s loop video for the swipe card.
  final XFile? video;

  /// Optional private legal docs for owner/listing verification.
  /// Properties, yachts and motorcycles can attach these during publish.
  /// Public users only ever see the resulting verified badge after approval.
  final List<XFile> legalDocuments;
  final String title;

  /// Freeform Airbnb-style description (chips still auto-fill if empty).
  final String description;
  final String price;
  final String currency;
  final String city;
  final String country;
  final String neighborhood;
  final List<String> adjectives;
  final List<String> sizes;
  final String? propertyType;
  final String? beds;
  final String? baths;
  final List<String> vibe;
  final List<String> amenities;
  final List<String> included;
  final List<String> rules;
  final bool furnished;
  final bool petFriendly;
  final String? rentalDuration;
  final String? brand;
  final String? model;
  final String year;
  final String mileage;
  final String engineCc;
  final String? vehicleType;
  final String? condition;
  final List<String> features;
  final List<String> vehicleIncluded;
  final String? frameSize;
  final String lengthM;
  final String berths;
  final String maxPassengers;
  final String? serviceCategory;
  final List<String> traits;

  /// Cap SERVICE_SUBSPECIALTIES skills for the selected service.
  final List<String> skills;
  final List<String> availability;
  final String? pricingUnit;
  final List<String> languages;
  final bool publishing;
  final String? error;

  int get maxPhotos {
    switch (category) {
      case ListingCategory.property:
        return 30;
      case ListingCategory.yacht:
        return 12;
      case ListingCategory.worker:
        return 8;
      case ListingCategory.motorcycle:
      case ListingCategory.bicycle:
        return 5;
    }
  }

  bool get requiresLegalDocuments {
    switch (category) {
      case ListingCategory.property:
      case ListingCategory.yacht:
      case ListingCategory.motorcycle:
        return true;
      case ListingCategory.bicycle:
      case ListingCategory.worker:
        return false;
    }
  }

  int get maxLegalDocuments => 6;

  String get categoryValue => category.name;

  String get modeValue {
    switch (mode) {
      case ListingMode.rent:
        return 'rent';
      case ListingMode.sale:
        return 'sale';
      case ListingMode.both:
        return 'both';
    }
  }

  ListingDraft copyWith({
    int? step,
    ListingCategory? category,
    ListingMode? mode,
    List<XFile>? photos,
    XFile? video,
    bool clearVideo = false,
    List<XFile>? legalDocuments,
    String? title,
    String? description,
    String? price,
    String? currency,
    String? city,
    String? country,
    String? neighborhood,
    List<String>? adjectives,
    List<String>? sizes,
    String? propertyType,
    bool clearPropertyType = false,
    String? beds,
    String? baths,
    List<String>? vibe,
    List<String>? amenities,
    List<String>? included,
    List<String>? rules,
    bool? furnished,
    bool? petFriendly,
    String? rentalDuration,
    String? brand,
    String? model,
    String? year,
    String? mileage,
    String? engineCc,
    String? vehicleType,
    String? condition,
    List<String>? features,
    List<String>? vehicleIncluded,
    String? frameSize,
    String? lengthM,
    String? berths,
    String? maxPassengers,
    String? serviceCategory,
    List<String>? traits,
    List<String>? skills,
    List<String>? availability,
    String? pricingUnit,
    List<String>? languages,
    bool? publishing,
    String? error,
    bool clearError = false,
  }) {
    return ListingDraft(
      step: step ?? this.step,
      category: category ?? this.category,
      mode: mode ?? this.mode,
      photos: photos ?? this.photos,
      video: clearVideo ? null : (video ?? this.video),
      legalDocuments: legalDocuments ?? this.legalDocuments,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      city: city ?? this.city,
      country: country ?? this.country,
      neighborhood: neighborhood ?? this.neighborhood,
      adjectives: adjectives ?? this.adjectives,
      sizes: sizes ?? this.sizes,
      propertyType: clearPropertyType
          ? null
          : (propertyType ?? this.propertyType),
      beds: beds ?? this.beds,
      baths: baths ?? this.baths,
      vibe: vibe ?? this.vibe,
      amenities: amenities ?? this.amenities,
      included: included ?? this.included,
      rules: rules ?? this.rules,
      furnished: furnished ?? this.furnished,
      petFriendly: petFriendly ?? this.petFriendly,
      rentalDuration: rentalDuration ?? this.rentalDuration,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      mileage: mileage ?? this.mileage,
      engineCc: engineCc ?? this.engineCc,
      vehicleType: vehicleType ?? this.vehicleType,
      condition: condition ?? this.condition,
      features: features ?? this.features,
      vehicleIncluded: vehicleIncluded ?? this.vehicleIncluded,
      frameSize: frameSize ?? this.frameSize,
      lengthM: lengthM ?? this.lengthM,
      berths: berths ?? this.berths,
      maxPassengers: maxPassengers ?? this.maxPassengers,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      traits: traits ?? this.traits,
      skills: skills ?? this.skills,
      availability: availability ?? this.availability,
      pricingUnit: pricingUnit ?? this.pricingUnit,
      languages: languages ?? this.languages,
      publishing: publishing ?? this.publishing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
