import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/constants/listing_locations.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/constants/service_categories.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/my_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';

class AddListingNotifier extends Notifier<ListingDraft> {
  @override
  ListingDraft build() => const ListingDraft();

  void reset() => state = const ListingDraft();

  void setStep(int step) =>
      state = state.copyWith(step: step, clearError: true);

  void setCategory(ListingCategory category) {
    state = state.copyWith(category: category, clearError: true);
  }

  void setMode(ListingMode mode) {
    state = state.copyWith(mode: mode, clearError: true);
  }

  void toggleMode(ListingMode tapped) {
    if (state.mode == ListingMode.both) {
      state = state.copyWith(
        mode: tapped == ListingMode.rent ? ListingMode.sale : ListingMode.rent,
      );
      return;
    }
    if (state.mode == tapped) return;
    state = state.copyWith(mode: ListingMode.both);
  }

  void update(ListingDraft Function(ListingDraft current) fn) {
    state = fn(state).copyWith(clearError: true);
  }

  Future<void> pickPhotos() async {
    final picker = ImagePicker();
    final remaining = state.maxPhotos - state.photos.length;
    if (remaining <= 0) {
      state = state.copyWith(
        error: 'Maximum photos reached for this category.',
      );
      return;
    }
    final picked = await picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    state = state.copyWith(
      photos: [...state.photos, ...picked.take(remaining)],
      clearError: true,
    );
  }

  void setVideo(XFile file) {
    state = state.copyWith(video: file, clearError: true);
  }

  Future<void> pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 10),
    );
    if (file == null) return;
    // Duration probe uses dart:io and breaks Flutter web. Size is
    // enforced on upload; cropper already caps native videos at 10s.
    if (!kIsWeb && file.path.isNotEmpty) {
      // Keep the 10s hint when the picker reports a long clip name.
    }
    state = state.copyWith(video: file, clearError: true);
  }

  void removePhoto(int index) {
    final next = List.of(state.photos)..removeAt(index);
    state = state.copyWith(photos: next);
  }

  void removeVideo() => state = state.copyWith(clearVideo: true);

  Future<bool> publish() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        error: 'Session expired — sign in again to publish.',
      );
      return false;
    }
    if (state.photos.isEmpty) {
      state = state.copyWith(error: 'At least 1 photo is required.');
      return false;
    }
    final coords = ListingLocations.resolve(state.city);
    if (coords == null) {
      state = state.copyWith(
        error:
            'Select a city from the location picker so your listing appears on the map.',
      );
      return false;
    }

    state = state.copyWith(publishing: true, clearError: true);
    try {
      final repo = ref.read(listingRepositoryProvider);
      final ai = ref.read(aiEdgeRepositoryProvider);
      final urls = await repo.uploadListingPhotos(
        userId: user.id,
        files: state.photos,
        moderateImage: ai.assertImageSafe,
      );
      String? videoUrl;
      final video = state.video;
      if (video != null) {
        videoUrl = await repo.uploadListingVideo(userId: user.id, file: video);
      }
      final payload = _payload(user.id, urls, coords, videoUrl: videoUrl);
      await repo.createListing(payload);
      ref.invalidate(swipeListingsProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(ownerListingsStatsProvider);
      state = const ListingDraft();
      return true;
    } catch (error) {
      state = state.copyWith(
        publishing: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Map<String, dynamic> _payload(
    String userId,
    List<String> images,
    ({double lat, double lng, String country, String state}) coords, {
    String? videoUrl,
  }) {
    final draft = state;
    final isVehicle =
        draft.category == ListingCategory.motorcycle ||
        draft.category == ListingCategory.bicycle ||
        draft.category == ListingCategory.yacht;
    final listingType = draft.category == ListingCategory.worker
        ? 'service'
        : draft.modeValue;
    final title = _title();
    final description = _description();
    final location = draft.neighborhood.trim().isNotEmpty
        ? draft.neighborhood.trim()
        : draft.city;

    final data = <String, dynamic>{
      'user_id': userId,
      'owner_id': userId,
      'category': draft.categoryValue,
      'listing_type': listingType,
      'mode': draft.modeValue,
      'status': 'active',
      'is_active': true,
      'title': title,
      'price': double.tryParse(draft.price) ?? 0,
      'currency': 'USD',
      'description': description,
      'country': coords.country,
      'state': coords.state,
      'city': draft.city,
      'location': location,
      'neighborhood': draft.neighborhood.trim().isEmpty
          ? null
          : draft.neighborhood.trim(),
      'latitude': coords.lat,
      'longitude': coords.lng,
      'images': images,
      'image_url': images.isNotEmpty ? images.first : null,
      'video_url': videoUrl,
      'amenities': draft.amenities,
      'services_included': draft.included,
    };

    if (draft.category == ListingCategory.property) {
      data['property_type'] = draft.propertyType?.toLowerCase();
      data['beds'] = _bedsValue(draft.beds);
      data['baths'] = double.tryParse(draft.baths ?? '');
      data['furnished'] =
          draft.furnished || draft.amenities.contains('Furnished');
      data['pet_friendly'] =
          draft.petFriendly ||
          draft.vibe.contains('Pet-friendly') ||
          draft.rules.contains('Pets allowed');
      data['house_rules'] = ListingTaxonomies.joinChips(draft.rules);
      data['rental_duration_type'] = draft.rentalDuration;
    }

    if (draft.category == ListingCategory.worker) {
      data['service_category'] = draft.serviceCategory;
      data['pricing_unit'] = _pricingUnitSlug(draft.pricingUnit);
      data['skills'] = <String>{...draft.skills, ...draft.traits}.toList();
      data['time_slots_available'] = draft.availability;
      data['languages'] = draft.languages;
    }

    if (isVehicle) {
      data['vehicle_type'] = draft.categoryValue;
      data['vehicle_brand'] = draft.brand;
      data['vehicle_model'] = draft.model;
      data['vehicle_condition'] = ListingTaxonomies.conditionSlug(
        draft.condition,
      );
      data['year'] = int.tryParse(draft.year);
      data['mileage'] = int.tryParse(draft.mileage);
      data['engine_cc'] = int.tryParse(draft.engineCc);
    }

    if (draft.category == ListingCategory.motorcycle) {
      data['motorcycle_type'] = draft.vehicleType;
      data['has_abs'] = draft.features.contains('ABS');
      data['includes_helmet'] = draft.vehicleIncluded.contains('Helmet');
      data['includes_gear'] = draft.vehicleIncluded.contains('Riding gear');
    }

    if (draft.category == ListingCategory.bicycle) {
      data['bicycle_type'] = draft.vehicleType;
      data['frame_size'] = draft.frameSize;
      data['electric_assist'] =
          draft.vehicleType == 'Electric' ||
          draft.features.contains('Electric');
      data['includes_lock'] = draft.vehicleIncluded.contains('Lock');
      data['includes_lights'] = draft.vehicleIncluded.contains('Lights');
    }

    if (draft.category == ListingCategory.yacht) {
      data['length_m'] = double.tryParse(draft.lengthM);
      data['berths'] = int.tryParse(draft.berths);
      data['max_passengers'] = int.tryParse(draft.maxPassengers);
    }

    data.removeWhere((_, value) => value == null);
    return data;
  }

  String _title() {
    final draft = state;
    if (draft.title.trim().isNotEmpty) return draft.title.trim();
    switch (draft.category) {
      case ListingCategory.property:
        final parts = <String>[
          if (draft.adjectives.isNotEmpty) draft.adjectives.first,
          if (draft.sizes.isNotEmpty) draft.sizes.first,
          if (draft.beds == 'Studio') 'Studio',
          if (draft.beds != null && draft.beds != 'Studio') '${draft.beds}BR',
          if (draft.propertyType != null) draft.propertyType!,
        ];
        var title = parts.join(' ').trim();
        if (title.isEmpty) title = 'Property';
        return '$title in ${draft.city}';
      case ListingCategory.worker:
        final name = serviceCategoryLabel(draft.serviceCategory);
        final adj = draft.traits.isNotEmpty
            ? '${draft.traits.first} '
            : (draft.skills.isNotEmpty ? '${draft.skills.first} ' : '');
        return '$adj$name · ${draft.city}'.trim();
      case ListingCategory.motorcycle:
      case ListingCategory.bicycle:
      case ListingCategory.yacht:
        final parts = <String>[
          if (draft.year.isNotEmpty) draft.year,
          if (draft.brand != null) draft.brand!,
          if (draft.model != null) draft.model!,
          if (draft.vehicleType != null) draft.vehicleType!,
        ];
        var title = parts.join(' ').trim();
        if (title.isEmpty) title = draft.categoryValue;
        return '$title · ${draft.city}';
    }
  }

  String _description() {
    final draft = state;
    if (draft.description.trim().isNotEmpty) return draft.description.trim();
    return ListingTaxonomies.joinChips([
      ...draft.adjectives.take(1),
      ...draft.sizes.take(1),
      if (draft.propertyType != null) draft.propertyType!,
      if (draft.vehicleType != null) draft.vehicleType!,
      if (draft.condition != null) draft.condition!,
      ...draft.vibe,
      ...draft.amenities,
      ...draft.included,
      ...draft.rules,
      ...draft.features,
      ...draft.vehicleIncluded,
      ...draft.traits,
      ...draft.skills,
      ...draft.availability,
      if (draft.serviceCategory != null)
        serviceCategoryLabel(draft.serviceCategory),
      draft.city,
    ]);
  }

  int? _bedsValue(String? beds) {
    if (beds == null) return null;
    if (beds == 'Studio') return 0;
    if (beds == '6+') return 6;
    return int.tryParse(beds);
  }

  String? _pricingUnitSlug(String? label) {
    switch (label) {
      case 'Hourly':
        return 'hour';
      case 'Daily':
        return 'day';
      case 'Per-job':
        return 'job';
      case 'Monthly contract':
        return 'month';
      default:
        return label?.toLowerCase();
    }
  }
}

final addListingProvider = NotifierProvider<AddListingNotifier, ListingDraft>(
  AddListingNotifier.new,
);
