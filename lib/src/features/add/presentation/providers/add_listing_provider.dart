import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/constants/listing_locations.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/constants/service_categories.dart';
import 'package:flutter_swipes/src/core/services/app_audio.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/my_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_place_search.dart';

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

    // image_picker 1.2.1 can reject pickMultiImage(limit: 1), so use the
    // single-image API when only one slot is left. Asking the picker to resize
    // and re-encode also makes iPhone HEIC/HEIF selections web-friendlier and
    // prevents giant camera originals from making uploads feel stalled.
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
    state = state.copyWith(
      photos: [...state.photos, ...picked.take(remaining)],
      clearError: true,
    );
  }

  Future<void> pickLegalDocuments() async {
    if (!state.supportsLegalVerification) {
      state = state.copyWith(
        error:
            'Verification proof is optional and available for every listing category.',
      );
      return;
    }
    final remaining = state.maxLegalDocuments - state.legalDocuments.length;
    if (remaining <= 0) {
      state = state.copyWith(error: 'Maximum verification documents reached.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    final picked = result?.files ?? const <PlatformFile>[];
    if (picked.isEmpty) return;
    final files = <XFile>[];
    for (final file in picked.take(remaining)) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      files.add(
        XFile.fromData(
          bytes,
          name: file.name,
          mimeType: _mimeTypeForLegalFile(file),
          length: bytes.lengthInBytes,
        ),
      );
    }
    if (files.isEmpty) return;
    state = state.copyWith(
      legalDocuments: [...state.legalDocuments, ...files],
      clearError: true,
    );
  }

  Future<void> captureLegalDocument() async {
    if (!state.supportsLegalVerification) return;
    final remaining = state.maxLegalDocuments - state.legalDocuments.length;
    if (remaining <= 0) {
      state = state.copyWith(error: 'Maximum verification documents reached.');
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2400,
      maxHeight: 2400,
      requestFullMetadata: false,
    );
    if (file == null) return;
    state = state.copyWith(
      legalDocuments: [...state.legalDocuments, file],
      clearError: true,
    );
  }

  void removeLegalDocument(int index) {
    final next = List<XFile>.of(state.legalDocuments)..removeAt(index);
    state = state.copyWith(legalDocuments: next, clearError: true);
  }

  void setVideo(XFile file) {
    state = state.copyWith(video: file, clearError: true);
  }

  void setVideoAudioEnabled(bool enabled) {
    state = state.copyWith(videoAudioEnabled: enabled, clearError: true);
  }

  void setBackgroundMusicPreset(String id, String name) {
    state = state.copyWith(
      videoAudioEnabled: false,
      clearBackgroundMusic: true,
      backgroundMusicPreset: id,
      backgroundMusicName: name,
      clearError: true,
    );
  }

  void setBackgroundMusicFile(XFile file) {
    state = state.copyWith(
      videoAudioEnabled: false,
      backgroundMusic: file,
      clearBackgroundMusicPreset: true,
      backgroundMusicName: file.name,
      clearError: true,
    );
  }

  void clearBackgroundMusic() {
    state = state.copyWith(
      clearBackgroundMusic: true,
      clearBackgroundMusicPreset: true,
      clearBackgroundMusicName: true,
      clearError: true,
    );
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
    final next = List<XFile>.of(state.photos)..removeAt(index);
    state = state.copyWith(photos: next, clearError: true);
  }

  /// Tinder-style media ordering: index 0 is always the public cover photo.
  void reorderPhoto(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= state.photos.length ||
        newIndex >= state.photos.length) {
      return;
    }
    final next = List<XFile>.of(state.photos);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    state = state.copyWith(photos: next, clearError: true);
  }

  void removeVideo() => state = state.copyWith(
    clearVideo: true,
    videoAudioEnabled: true,
    clearBackgroundMusic: true,
    clearBackgroundMusicPreset: true,
    clearBackgroundMusicName: true,
  );

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
    final parsedPrice = double.tryParse(state.price.trim());
    if (parsedPrice == null || parsedPrice <= 0) {
      state = state.copyWith(error: 'Enter a price greater than 0.');
      return false;
    }
    final currency = state.currency.trim().toUpperCase();
    if (!const {'USD', 'MXN'}.contains(currency)) {
      state = state.copyWith(error: 'Choose USD or MXN for the price.');
      return false;
    }

    // Verification is optional. Users can publish immediately and choose to
    // submit private proof for an admin-reviewed blue check and visibility boost.

    // Check the server quota before geocoding or uploading photos. The database
    // trigger is still the final enforcement layer, but this gives the user a
    // clear answer immediately instead of a generic save failure after upload.
    try {
      final quota = await Supabase.instance.client.rpc(
        'rpc_can_publish_listing',
        params: {'p_category': state.categoryValue},
      );
      if (quota is Map && quota['can_create_listing'] == false) {
        final tier = (quota['tier'] ?? 'current').toString();
        final limit = quota['max_active_listings'];
        final suffix = limit == null ? '' : ' ($limit active listings)';
        state = state.copyWith(
          error:
              'Active listing limit reached for $tier tier$suffix. Deactivate an existing listing or upgrade your plan.',
        );
        return false;
      }
    } catch (error) {
      // Fail open here: the database guardrail still enforces the real limit.
      debugPrint('[AddListing] quota preflight fallback: $error');
    }

    if (state.video != null) {
      try {
        final allowed = await Supabase.instance.client.rpc(
          'rpc_can_upload_listing_video',
        );
        if (allowed != true) {
          state = state.copyWith(
            error:
                'Listing video + dashboard Quick Filter exposure is a paid Premium benefit. Upgrade or remove the video to publish.',
          );
          return false;
        }
      } catch (error) {
        debugPrint('[AddListing] video entitlement check failed: $error');
        state = state.copyWith(
          error: 'Could not verify Premium video access. Please retry.',
        );
        return false;
      }
    }

    var coords = ListingLocations.resolve(state.city);
    if (coords == null) {
      if (state.city.trim().isEmpty) {
        state = state.copyWith(error: 'City is required.');
        return false;
      }
      final query = '${state.city}, ${state.country}'.trim();
      final results = await MapboxPlaceSearch.search(query);
      if (results.isNotEmpty) {
        final first = results.first;
        coords = (
          lat: first.latitude,
          lng: first.longitude,
          country: first.country.isNotEmpty ? first.country : state.country,
          state: '',
        );
      } else {
        // Fallback if Mapbox fails or doesn't find it.
        coords = (lat: 0.0, lng: 0.0, country: state.country, state: '');
      }
    }

    state = state.copyWith(publishing: true, clearError: true);
    final repo = ref.read(listingRepositoryProvider);
    String? createdListingId;
    try {
      final ai = ref.read(aiEdgeRepositoryProvider);
      final video = state.video;
      final backgroundMusic = state.backgroundMusic;

      final photosFuture = repo.uploadListingPhotos(
        userId: user.id,
        files: state.photos,
        moderateImage: ai.assertImageSafe,
      );
      final videoFuture = video == null
          ? Future<String?>.value(null)
          : repo
                .uploadListingVideo(userId: user.id, file: video)
                .then<String?>((url) => url);
      final musicFuture = video == null || backgroundMusic == null
          ? Future<String?>.value(null)
          : repo.uploadListingAudio(userId: user.id, file: backgroundMusic);

      final urls = await photosFuture;
      final videoUrl = await videoFuture;
      final backgroundMusicUrl = await musicFuture;
      final payload = _payload(
        user.id,
        urls,
        coords,
        videoUrl: videoUrl,
        backgroundMusicUrl: backgroundMusicUrl,
      );
      final listing = await repo.createListing(payload);
      createdListingId = listing.id;
      if (state.supportsLegalVerification && state.legalDocuments.isNotEmpty) {
        await repo.uploadListingLegalDocuments(
          userId: user.id,
          listingId: listing.id,
          category: state.categoryValue,
          files: state.legalDocuments,
        );
      }
      ref.invalidate(swipeListingsProvider);
      ref.invalidate(mapListingsProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(ownerListingsStatsProvider);
      state = const ListingDraft();
      await AppAudio.instance.playSuccessFromPrefs();
      return true;
    } catch (error) {
      // A required verification upload is part of publishing. If anything fails
      // after the listing row is created, remove that row so an unverified item
      // can never leak onto the live marketplace because of a partial upload.
      if (createdListingId != null) {
        try {
          await repo.deleteListing(createdListingId);
        } catch (_) {}
      }
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
    String? backgroundMusicUrl,
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
    final currency = draft.currency.trim().toUpperCase();

    final data = <String, dynamic>{
      'user_id': userId,
      'owner_id': userId,
      'category': draft.categoryValue,
      'listing_type': listingType,
      'mode': draft.modeValue,
      'status': 'active',
      'is_active': true,
      'title': title,
      'price': double.parse(draft.price.trim()),
      'currency': const {'USD', 'MXN'}.contains(currency) ? currency : 'USD',
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
      'video_url': videoUrl,
      'video_audio_enabled': draft.videoAudioEnabled,
      'background_music_url': backgroundMusicUrl,
      'background_music_preset': draft.backgroundMusicPreset,
      'background_music_name': draft.backgroundMusicName,
      'amenities': draft.amenities,
      'services_included': draft.included,
      'has_verified_documents': false,
      'verification_status': draft.legalDocuments.isNotEmpty
          ? 'pending'
          : 'unverified',
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

  String _mimeTypeForLegalFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

final addListingProvider = NotifierProvider<AddListingNotifier, ListingDraft>(
  AddListingNotifier.new,
);
