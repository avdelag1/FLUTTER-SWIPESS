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
    this.videoAudioEnabled = true,
    this.backgroundMusic,
    this.backgroundMusicPreset,
    this.backgroundMusicName,
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

  /// Optional short loop video for the swipe card.
  final XFile? video;

  /// Whether the video's own recorded audio should play when deck sound is on.
  final bool videoAudioEnabled;

  /// Optional user-uploaded soundtrack before it is uploaded to Storage.
  final XFile? backgroundMusic;

  /// Optional built-in original Swipess soundtrack id.
  final String? backgroundMusicPreset;

  /// Human-friendly selected soundtrack/file name.
  final String? backgroundMusicName;

  bool get hasBackgroundMusic =>
      backgroundMusic != null ||
      (backgroundMusicPreset != null &&
          backgroundMusicPreset!.trim().isNotEmpty);

  /// Private proof used for listing verification.
  /// Any category may submit ownership, authorization, business or professional proof.
  /// Public users only see the
  /// resulting verified badge after an admin approves the submission.
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

  /// Every listing type can optionally submit private proof for review.
  bool get supportsLegalVerification => true;

  int get maxLegalDocuments => 6;

  String get verificationTitle {
    switch (category) {
      case ListingCategory.property:
        return 'Build trust with renters & buyers';
      case ListingCategory.yacht:
        return 'Show clients who they are booking with';
      case ListingCategory.motorcycle:
        return 'Add extra trust to this vehicle';
      case ListingCategory.bicycle:
        return 'Add extra trust to this bicycle';
      case ListingCategory.worker:
        return 'Stand out as a serious professional';
    }
  }

  String get verificationBody {
    switch (category) {
      case ListingCategory.property:
        return 'Owners, brokers and authorized representatives are all welcome. If you can show ownership or authorization, send it privately for review. Approved listings receive a blue check and stronger visibility, helping clients understand who they are dealing with and connect more directly.';
      case ListingCategory.yacht:
        return 'Owners, brokers and authorized operators are all welcome. You can privately show ownership, registration or authorization for review. Approved listings receive a blue check and stronger visibility, helping clients book with more confidence.';
      case ListingCategory.motorcycle:
        return 'Anyone can list, but owners or authorized sellers/renters can privately submit registration or ownership proof. Approved listings receive a blue check and stronger visibility so clients can deal with more confidence.';
      case ListingCategory.bicycle:
        return 'Anyone can list. If you have purchase, ownership or business proof, you can send it privately for review. Approved listings receive a blue check and stronger visibility, adding trust for buyers and renters.';
      case ListingCategory.worker:
        return 'Independent professionals, teams and businesses are all welcome. Share credentials, registration, certification or other professional proof privately. Approved profiles receive a blue check and stronger visibility, helping serious clients find you faster.';
    }
  }

  String get verificationProofHint {
    switch (category) {
      case ListingCategory.property:
        return 'Ownership, title, management agreement or authorization';
      case ListingCategory.yacht:
        return 'Registration, ownership or operating authorization';
      case ListingCategory.motorcycle:
        return 'Registration, ownership or authorized dealer/rental proof';
      case ListingCategory.bicycle:
        return 'Purchase, ownership, shop or rental-business proof';
      case ListingCategory.worker:
        return 'License, certification, business registration or professional ID';
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
    XFile? video,
    bool clearVideo = false,
    bool? videoAudioEnabled,
    XFile? backgroundMusic,
    bool clearBackgroundMusic = false,
    String? backgroundMusicPreset,
    bool clearBackgroundMusicPreset = false,
    String? backgroundMusicName,
    bool clearBackgroundMusicName = false,
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
      videoAudioEnabled: videoAudioEnabled ?? this.videoAudioEnabled,
      backgroundMusic: clearBackgroundMusic
          ? null
          : (backgroundMusic ?? this.backgroundMusic),
      backgroundMusicPreset: clearBackgroundMusicPreset
          ? null
          : (backgroundMusicPreset ?? this.backgroundMusicPreset),
      backgroundMusicName: clearBackgroundMusicName
          ? null
          : (backgroundMusicName ?? this.backgroundMusicName),
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
