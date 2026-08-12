import 'package:cross_file/cross_file.dart';

enum ListingCategory { property, motorcycle, bicycle, yacht, worker }

enum ListingMode { rent, sale, both }

class ListingDraft {
  const ListingDraft({
    this.step = 0,
    this.category = ListingCategory.property,
    this.mode = ListingMode.rent,
    this.photos = const [],
    this.title = '',
    this.price = '',
    this.city = 'Tulum',
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
  final String title;
  final String price;
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
        return 3;
      case ListingCategory.motorcycle:
      case ListingCategory.bicycle:
        return 5;
    }
  }

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
    String? title,
    String? price,
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
      title: title ?? this.title,
      price: price ?? this.price,
      city: city ?? this.city,
      country: country ?? this.country,
      neighborhood: neighborhood ?? this.neighborhood,
      adjectives: adjectives ?? this.adjectives,
      sizes: sizes ?? this.sizes,
      propertyType: clearPropertyType ? null : (propertyType ?? this.propertyType),
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
      availability: availability ?? this.availability,
      pricingUnit: pricingUnit ?? this.pricingUnit,
      languages: languages ?? this.languages,
      publishing: publishing ?? this.publishing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
