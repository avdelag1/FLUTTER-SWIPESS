import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/constants/listing_locations.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/my_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';

/// Edit-form state for Cap UnifiedListingForm (editingProperty path).
class EditListingState {
  const EditListingState({
    required this.listingId,
    required this.category,
    this.title = '',
    this.description = '',
    this.price = '',
    this.city = '',
    this.neighborhood = '',
    this.beds,
    this.baths,
    this.propertyType,
    this.brand,
    this.model,
    this.year = '',
    this.mileage = '',
    this.serviceCategory,
    this.furnished = false,
    this.petFriendly = false,
    this.amenities = const [],
    this.existingImages = const [],
    this.newPhotos = const [],
    this.saving = false,
    this.error,
  });

  final String listingId;
  final String category;
  final String title;
  final String description;
  final String price;
  final String city;
  final String neighborhood;
  final String? beds;
  final String? baths;
  final String? propertyType;
  final String? brand;
  final String? model;
  final String year;
  final String mileage;
  final String? serviceCategory;
  final bool furnished;
  final bool petFriendly;
  final List<String> amenities;
  final List<String> existingImages;
  final List<XFile> newPhotos;
  final bool saving;
  final String? error;

  bool get isProperty => category == 'property';
  bool get isWorker => category == 'worker';
  bool get isVehicle =>
      category == 'motorcycle' || category == 'bicycle' || category == 'yacht';

  int get maxPhotos {
    switch (category) {
      case 'property':
        return 30;
      case 'yacht':
        return 12;
      case 'worker':
        return 8;
      default:
        return 5;
    }
  }

  int get photoCount => existingImages.length + newPhotos.length;

  EditListingState copyWith({
    String? title,
    String? description,
    String? price,
    String? city,
    String? neighborhood,
    String? beds,
    String? baths,
    String? propertyType,
    bool clearPropertyType = false,
    String? brand,
    String? model,
    String? year,
    String? mileage,
    String? serviceCategory,
    bool? furnished,
    bool? petFriendly,
    List<String>? amenities,
    List<String>? existingImages,
    List<XFile>? newPhotos,
    bool? saving,
    String? error,
    bool clearError = false,
  }) {
    return EditListingState(
      listingId: listingId,
      category: category,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      city: city ?? this.city,
      neighborhood: neighborhood ?? this.neighborhood,
      beds: beds ?? this.beds,
      baths: baths ?? this.baths,
      propertyType: clearPropertyType
          ? null
          : (propertyType ?? this.propertyType),
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      mileage: mileage ?? this.mileage,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      furnished: furnished ?? this.furnished,
      petFriendly: petFriendly ?? this.petFriendly,
      amenities: amenities ?? this.amenities,
      existingImages: existingImages ?? this.existingImages,
      newPhotos: newPhotos ?? this.newPhotos,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory EditListingState.fromListing(Listing listing) {
    final beds = listing.beds;
    String? bedsLabel;
    if (beds != null) {
      if (beds == 0) {
        bedsLabel = 'Studio';
      } else if (beds >= 6) {
        bedsLabel = '6+';
      } else {
        bedsLabel = '$beds';
      }
    }
    final baths = listing.baths;
    return EditListingState(
      listingId: listing.id,
      category: listing.category ?? 'property',
      title: listing.title ?? '',
      description: listing.description ?? '',
      price: listing.price == null
          ? ''
          : listing.price!.toStringAsFixed(listing.price! % 1 == 0 ? 0 : 2),
      city: listing.city ?? '',
      neighborhood: listing.neighborhood ?? '',
      beds: bedsLabel,
      baths: baths?.toStringAsFixed(baths % 1 == 0 ? 0 : 1),
      propertyType: listing.propertyType,
      brand: listing.vehicleBrand,
      model: listing.vehicleModel,
      year: listing.year?.toString() ?? '',
      mileage: listing.mileage?.toString() ?? '',
      serviceCategory: listing.serviceCategory,
      furnished: listing.furnished ?? false,
      petFriendly: listing.petFriendly ?? false,
      amenities: listing.amenities,
      existingImages: List<String>.from(listing.images),
    );
  }
}

class EditListingNotifier extends Notifier<EditListingState?> {
  @override
  EditListingState? build() => null;

  void load(Listing listing) {
    state = EditListingState.fromListing(listing);
    Future(() async {
      try {
        final full = await ref
            .read(listingRepositoryProvider)
            .fetchById(listing.id);
        if (full != null) state = EditListingState.fromListing(full);
      } catch (_) {}
    });
  }

  void clear() => state = null;

  void update(EditListingState Function(EditListingState current) fn) {
    final current = state;
    if (current == null) return;
    state = fn(current).copyWith(clearError: true);
  }

  void removeExistingImage(int index) {
    final current = state;
    if (current == null) return;
    final next = List<String>.of(current.existingImages)..removeAt(index);
    state = current.copyWith(existingImages: next, clearError: true);
  }

  void reorderExistingImage(int oldIndex, int newIndex) {
    final current = state;
    if (current == null ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= current.existingImages.length ||
        newIndex >= current.existingImages.length) {
      return;
    }
    final next = List<String>.of(current.existingImages);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    state = current.copyWith(existingImages: next, clearError: true);
  }

  void removeNewPhoto(int index) {
    final current = state;
    if (current == null) return;
    final next = List<XFile>.of(current.newPhotos)..removeAt(index);
    state = current.copyWith(newPhotos: next, clearError: true);
  }

  void reorderNewPhoto(int oldIndex, int newIndex) {
    final current = state;
    if (current == null ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= current.newPhotos.length ||
        newIndex >= current.newPhotos.length) {
      return;
    }
    final next = List<XFile>.of(current.newPhotos);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    state = current.copyWith(newPhotos: next, clearError: true);
  }

  Future<void> pickPhotos() async {
    final current = state;
    if (current == null) return;
    final remaining = current.maxPhotos - current.photoCount;
    if (remaining <= 0) {
      state = current.copyWith(
        error: 'Maximum photos reached for this category.',
      );
      return;
    }

    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 2400,
        requestFullMetadata: false,
      );
      picked = file == null ? const <XFile>[] : <XFile>[file];
    } else {
      picked = await picker.pickMultiImage(
        limit: remaining,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 2400,
        requestFullMetadata: false,
      );
    }
    if (picked.isEmpty) return;
    state = current.copyWith(
      newPhotos: [...current.newPhotos, ...picked.take(remaining)],
      clearError: true,
    );
  }

  Future<bool> save() async {
    final current = state;
    if (current == null) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = current.copyWith(error: 'Session expired — sign in again.');
      return false;
    }
    if (current.photoCount <= 0) {
      state = current.copyWith(error: 'At least 1 photo is required.');
      return false;
    }
    if (current.title.trim().isEmpty) {
      state = current.copyWith(error: 'Title is required.');
      return false;
    }
    final parsedPrice = double.tryParse(current.price.trim());
    if (parsedPrice == null || parsedPrice <= 0) {
      state = current.copyWith(error: 'Enter a price greater than 0.');
      return false;
    }

    final coords = ListingLocations.resolve(current.city);
    state = current.copyWith(saving: true, clearError: true);
    try {
      final repo = ref.read(listingRepositoryProvider);
      final ai = ref.read(aiEdgeRepositoryProvider);
      final uploaded = current.newPhotos.isEmpty
          ? <String>[]
          : await repo.uploadListingPhotos(
              userId: user.id,
              files: current.newPhotos,
              moderateImage: ai.assertImageSafe,
            );
      final images = [...current.existingImages, ...uploaded];
      final payload = <String, dynamic>{
        'title': current.title.trim(),
        'description': current.description.trim().isEmpty
            ? null
            : current.description.trim(),
        'price': parsedPrice,
        'city': current.city,
        'neighborhood': current.neighborhood.trim().isEmpty
            ? null
            : current.neighborhood.trim(),
        'location': current.neighborhood.trim().isNotEmpty
            ? current.neighborhood.trim()
            : current.city,
        'images': images,
        'amenities': current.amenities,
        'furnished': current.furnished,
        'pet_friendly': current.petFriendly,
        if (coords != null) ...{
          'latitude': coords.lat,
          'longitude': coords.lng,
          'country': coords.country,
          'state': coords.state,
        },
      };

      if (current.isProperty) {
        payload['property_type'] = current.propertyType?.toLowerCase();
        payload['beds'] = _bedsValue(current.beds);
        payload['baths'] = double.tryParse(current.baths ?? '');
      }
      if (current.isVehicle) {
        payload['vehicle_brand'] = current.brand;
        payload['vehicle_model'] = current.model;
        payload['year'] = int.tryParse(current.year);
        payload['mileage'] = int.tryParse(current.mileage);
      }
      if (current.isWorker) {
        payload['service_category'] = current.serviceCategory;
      }

      payload.removeWhere((_, value) => value == null);
      await repo.updateListing(current.listingId, payload);
      ref.invalidate(myListingsProvider);
      ref.invalidate(ownerListingsStatsProvider);
      ref.invalidate(swipeListingsProvider);
      ref.invalidate(mapListingsProvider);
      state = null;
      return true;
    } catch (error) {
      state = current.copyWith(
        saving: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  int? _bedsValue(String? beds) {
    if (beds == null) return null;
    if (beds == 'Studio') return 0;
    if (beds == '6+') return 6;
    return int.tryParse(beds);
  }
}

final editListingProvider =
    NotifierProvider<EditListingNotifier, EditListingState?>(
      EditListingNotifier.new,
    );
