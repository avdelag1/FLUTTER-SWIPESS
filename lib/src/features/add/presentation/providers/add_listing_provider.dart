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
import 'package:flutter_swipes/src/features/studio/data/studio_render_repository.dart';
import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';
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

    final List<XFile> picked;
    if (remaining == 1) {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1920,
        maxHeight: 1920,
        requestFullMetadata: false,
      );
      picked = file == null ? const <XFile>[] : <XFile>[file];
    } else {
      picked = await picker.pickMultiImage(
        limit: remaining,
        imageQuality: 86,
        maxWidth: 1920,
        maxHeight: 1920,
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
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return;
    state = state.copyWith(video: file, clearError: true);
  }

  void removePhoto(int index) {
    final next = List<XFile>.of(state.photos)..removeAt(index);
    state = state.copyWith(photos: next, clearError: true);
  }

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

  Future<bool> prepareStudioVideo() async {
    if (state.publishing) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        error: 'Session expired — sign in again before creating the Studio video.',
      );
      return false;
    }

    final selection = ref.read(studioListingSelectionProvider);
    if (selection == null || !selection.matchesPhotos(state.photos)) {
      state = state.copyWith(
        error: 'Choose a Studio video style again before creating the real video.',
      );
      return false;
    }
    if (selection.hasRenderedVideo) return true;
    if (state.photos.length < 3) {
      state = state.copyWith(error: 'Studio needs at least 3 photos.');
      return false;
    }

    try {
      final allowed = await Supabase.instance.client.rpc(
        'rpc_can_upload_listing_video',
      );
      if (allowed != true) {
        state = state.copyWith(
          error:
              'Listing video access could not be verified. Sign in again or retry.',
        );
        return false;
      }
    } catch (error) {
      debugPrint('[AddListing] Studio entitlement check failed: $error');
      state = state.copyWith(
        error: 'Could not verify video access. Please retry.',
      );
      return false;
    }

    state = state.copyWith(publishing: true, clearError: true);
    final repo = ref.read(listingRepositoryProvider);
    StudioRenderResult? render;
    try {
      final ai = ref.read(aiEdgeRepositoryProvider);
      final urls = await repo.uploadListingPhotos(
        userId: user.id,
        files: state.photos,
        moderateImage: ai.assertImageSafe,
      );
      if (urls.length < 3) {
        throw Exception(
          'Studio needs at least 3 approved photos. Choose another photo and try again.',
        );
      }

      render = await ref
          .read(studioRenderRepositoryProvider)
          .render(
            imageUrls: urls.take(6).toList(growable: false),
            project: selection.project,
          )
          .timeout(
            const Duration(minutes: 4),
            onTimeout: () => throw Exception(
              'Studio video took too long to render. Please retry — your photos are still here.',
            ),
          );

      final stored = ref
          .read(studioListingSelectionProvider.notifier)
          .setRendered(
            photos: state.photos,
            uploadedImageUrls: urls,
            videoUrl: render.videoUrl,
            posterUrl: render.posterUrl,
            durationSeconds: render.durationSeconds,
          );
      if (!stored) {
        await ref.read(studioRenderRepositoryProvider).cleanup(render);
        throw Exception(
          'The Studio photos changed while the video was rendering. Please create the video again.',
        );
      }

      state = state.copyWith(publishing: false, clearError: true);
      return true;
    } catch (error) {
      if (render != null) {
        await ref.read(studioRenderRepositoryProvider).cleanup(render);
      }
      state = state.copyWith(
        publishing: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> publish() async {
    if (state.publishing) return false;
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

    final studioSelection = ref.read(studioListingSelectionProvider);
    final usableStudio = studioSelection != null &&
        studioSelection.matchesPhotos(state.photos);

    try {
      final quota = await Supabase.instance.client.rpc(
        'rpc_can_publish_listing',
        params: {'p_category': state.categoryValue},
      );
      if (quota is Map && quota['can_create_listing'] == false) {
        final limit = quota['max_active_listings'];
        final suffix = limit == null ? '' : ' ($limit active listings)';
        state = state.copyWith(
          error:
              'Active listing limit reached$suffix for this category. Deactivate an existing listing in this category before publishing another.',
        );
        return false;
      }
    } catch (error) {
      debugPrint('[AddListing] quota preflight fallback: $error');
    }

    if (state.video != null || usableStudio) {
      try {
        final allowed = await Supabase.instance.client.rpc(
          'rpc_can_upload_listing_video',
        );
        if (allowed != true) {
          state = state.copyWith(
            error:
                'Listing video access could not be verified. Sign in again or retry the upload.',
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
        coords = (lat: 0.0, lng: 0.0, country: state.country, state: '');
      }
    }

    state = state.copyWith(publishing: true, clearError: true);
    final repo = ref.read(listingRepositoryProvider);
    String? createdListingId;
    StudioRenderResult? generatedStudioRender;
    try {
      final ai = ref.read(aiEdgeRepositoryProvider);
      final video = state.video;
      final backgroundMusic = state.backgroundMusic;

      late final List<String> urls;
      String? videoUrl;
      String? backgroundMusicUrl;
      var studioGenerated = false;

      if (video != null) {
        final uploadedMedia = await Future.wait<Object?>([
          repo.uploadListingPhotos(
            userId: user.id,
            files: state.photos,
            moderateImage: ai.assertImageSafe,
          ),
          repo
              .uploadListingVideo(userId: user.id, file: video)
              .then<String?>((url) => url),
          backgroundMusic == null
              ? Future<String?>.value(null)
              : repo.uploadListingAudio(userId: user.id, file: backgroundMusic),
        ]);
        urls = uploadedMedia[0] as List<String>;
        videoUrl = uploadedMedia[1] as String?;
        backgroundMusicUrl = uploadedMedia[2] as String?;
      } else {
        final preparedStudio = usableStudio ? studioSelection : null;
        if (preparedStudio != null &&
            preparedStudio.hasRenderedVideo &&
            preparedStudio.uploadedImageUrls.length >= 3) {
          // The user already waited for and confirmed the REAL MP4 in the
          // listing creator. Reuse those exact uploaded photos + video instead
          // of rendering a second time during Publish.
          urls = preparedStudio.uploadedImageUrls;
          videoUrl = preparedStudio.renderedVideoUrl;
          generatedStudioRender = StudioRenderResult(
            videoUrl: preparedStudio.renderedVideoUrl!,
            posterUrl: preparedStudio.renderedPosterUrl,
            durationSeconds: preparedStudio.renderedDurationSeconds ?? 0,
          );
          studioGenerated = true;
        } else {
          // Compatibility fallback for older clients / drafts: render on
          // Publish if the explicit pre-render step was not completed.
          urls = await repo.uploadListingPhotos(
            userId: user.id,
            files: state.photos,
            moderateImage: ai.assertImageSafe,
          );
          if (usableStudio && studioSelection != null) {
            if (urls.length < 3) {
              throw Exception(
                'Studio needs at least 3 approved photos. Choose another photo and try again.',
              );
            }
            final render = await ref
                .read(studioRenderRepositoryProvider)
                .render(
                  imageUrls: urls.take(6).toList(growable: false),
                  project: studioSelection.project,
                )
                .timeout(
                  const Duration(minutes: 4),
                  onTimeout: () => throw Exception(
                    'Studio video took too long to render. Please retry — your photos are still here.',
                  ),
                );
            generatedStudioRender = render;
            videoUrl = render.videoUrl;
            studioGenerated = true;
          }
        }
      }

      final payload = _payload(
        user.id,
        urls,
        coords,
        videoUrl: videoUrl,
        backgroundMusicUrl: backgroundMusicUrl,
        studioGenerated: studioGenerated,
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
      ref.invalidate(quickFilterPreviewListingsProvider);
      ref.invalidate(mapListingsProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(ownerListingsStatsProvider);
      ref.read(studioListingSelectionProvider.notifier).clear();
      state = const ListingDraft();
      await AppAudio.instance.playSuccessFromPrefs();
      return true;
    } catch (error) {
      if (createdListingId != null) {
        try {
          await repo.deleteListing(createdListingId);
        } catch (_) {}
      }
      if (generatedStudioRender != null) {
        await ref
            .read(studioRenderRepositoryProvider)
            .cleanup(generatedStudioRender);
        ref.read(studioListingSelectionProvider.notifier).clearRendered();
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
    bool studioGenerated = false,
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
      // Studio bakes its selected soundscape directly into the generated
      // MP4. Do not also attach listing soundtrack metadata or playback
      // would layer the same vibe over the rendered audio a second time.
      'video_audio_enabled': studioGenerated ? true : draft.videoAudioEnabled,
      'background_music_url': studioGenerated ? null : backgroundMusicUrl,
      'background_music_preset': studioGenerated
          ? null
          : draft.backgroundMusicPreset,
      'background_music_name': studioGenerated ? null : draft.backgroundMusicName,
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
