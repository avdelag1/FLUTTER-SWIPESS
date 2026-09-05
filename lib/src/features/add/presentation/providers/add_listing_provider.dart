import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
        imageQuality: 93,
        maxWidth: 2880,
        maxHeight: 2880,
        requestFullMetadata: false,
      );
      picked = file == null ? const <XFile>[] : <XFile>[file];
    } else {
      picked = await picker.pickMultiImage(
        limit: remaining,
        imageQuality: 93,
        maxWidth: 2880,
        maxHeight: 2880,
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

  Future<bool> prepareStudioVideo({void Function(String)? onProgress}) async {
    if (state.publishing) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        error:
            'Session expired — sign in again before creating the Studio video.',
      );
      return false;
    }

    final selection = ref.read(studioListingSelectionProvider);
    if (selection == null) return false;

    if (selection.hasRenderedVideo && selection.matchesPhotos(state.photos)) {
      return true;
    }
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

      onProgress?.call('Uploading photos (${state.photos.length})...');
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

      onProgress?.call('Composing and rendering MP4 (this takes a moment)...');
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

      onProgress?.call('Downloading MP4 to your device...');
      try {
        final response = await http.get(Uri.parse(render.videoUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File(
            '${tempDir.path}/studio_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          await file.writeAsBytes(response.bodyBytes);
          state = state.copyWith(
            video: XFile(file.path),
            publishing: false,
            clearError: true,
          );
          return true;
        }
      } catch (e) {
        debugPrint('[AddListing] Could not download Studio MP4: $e');
      }

      state = state.copyWith(publishing: false, clearError: true);
      return true;
    } catch (error) {
      if (render != null) {
        await ref.read(studioRenderRepositoryProvider).cleanup(render);
      }
      ref.read(studioListingSelectionProvider.notifier).clear();
      state = state.copyWith(
        error: error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('ClientException: ', ''),
        publishing: false,
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
    final usableStudio =
        studioSelection != null && studioSelection.matchesPhotos(state.photos);
    final studioIntent = state.video == null && studioSelection != null;

    if (studioIntent && !usableStudio) {
      state = state.copyWith(
        error:
            'Your Studio photos changed. Reopen Studio and create the real MP4 again before publishing.',
      );
      return false;
    }
    if (studioIntent &&
        (!studioSelection!.hasRenderedVideo ||
            studioSelection.uploadedImageUrls.length < 3)) {
      state = state.copyWith(
        error:
            'Studio is not finished yet. Create and play the REAL MP4 inside Studio before publishing.',
      );
      return false;
    }

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
      final video = usableStudio ? null : state.video;
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
          urls = List<String>.of(preparedStudio.uploadedImageUrls);
          final alreadyUploaded = urls.length <= state.photos.length
              ? urls.length
              : state.photos.length;
          if (alreadyUploaded < state.photos.length) {
            final extraUrls = await repo.uploadListingPhotos(
              userId: user.id,
              files: state.photos.skip(alreadyUploaded).toList(growable: false),
              moderateImage: ai.assertImageSafe,
            );
            urls.addAll(extraUrls);
          }
          videoUrl = preparedStudio.renderedVideoUrl;
          generatedStudioRender = StudioRenderResult(
            videoUrl: preparedStudio.renderedVideoUrl!,
            posterUrl: preparedStudio.renderedPosterUrl,
            durationSeconds: preparedStudio.renderedDurationSeconds ?? 0,
          );
          studioGenerated = true;
        } else {
          urls = await repo.uploadListingPhotos(
            userId: user.id,
            files: state.photos,
            moderateImage: ai.assertImageSafe,
          );
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
      'video_audio_enabled': studioGenerated ? true : draft.videoAudioEnabled,
      'background_music_url': studioGenerated ? null : backgroundMusicUrl,
      'background_music_preset': studioGenerated
          ? null
          : draft.backgroundMusicPreset,
      'background_music_name': studioGenerated
          ? null
          : draft.backgroundMusicName,
      'property_type': draft.category == ListingCategory.property
          ? _nullable(draft.propertyType)?.toLowerCase()
          : null,
      'beds': draft.category == ListingCategory.property
          ? _bedsValue(draft.beds)
          : null,
      'baths': draft.category == ListingCategory.property
          ? _bathsValue(draft.baths)
          : null,
      'furnished': draft.category == ListingCategory.property
          ? draft.furnished
          : null,
      'pet_friendly': draft.category == ListingCategory.property
          ? draft.petFriendly
          : null,
      'amenities': draft.category == ListingCategory.property
          ? draft.amenities
          : const <String>[],
      'vehicle_brand': isVehicle ? _nullable(draft.brand) : null,
      'vehicle_model': isVehicle ? _nullable(draft.model) : null,
      'year': isVehicle ? int.tryParse(draft.year.trim()) : null,
      'mileage': draft.category == ListingCategory.motorcycle
          ? int.tryParse(draft.mileage.trim())
          : null,
      'service_category': draft.category == ListingCategory.worker
          ? _nullable(draft.serviceCategory)
          : null,
      'pricing_unit': draft.category == ListingCategory.worker
          ? _nullable(draft.pricingUnit)
          : null,
      'availability': draft.category == ListingCategory.worker
          ? draft.availability
          : const <String>[],
      'languages': draft.category == ListingCategory.worker
          ? draft.languages
          : const <String>[],
      'skills': draft.category == ListingCategory.worker
          ? draft.skills
          : const <String>[],
    };

    data.removeWhere((key, value) => value == null);
    return data;
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _bedsValue(String? beds) {
    final value = beds?.trim();
    if (value == null || value.isEmpty) return null;
    if (value == 'Studio') return 0;
    if (value == '6+') return 6;
    return int.tryParse(value);
  }

  double? _bathsValue(String? baths) {
    final value = baths?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.endsWith('+')) {
      return double.tryParse(value.substring(0, value.length - 1));
    }
    return double.tryParse(value);
  }

  String _title() {
    final explicit = state.title.trim();
    if (explicit.isNotEmpty) return explicit;

    final propertyType = state.propertyType?.trim() ?? '';
    final brand = state.brand?.trim() ?? '';
    final model = state.model?.trim() ?? '';
    final serviceCategory = state.serviceCategory?.trim() ?? '';
    final kind = switch (state.category) {
      ListingCategory.property =>
        propertyType.isEmpty ? 'Property' : propertyType,
      ListingCategory.motorcycle => '${state.year.trim()} $brand $model'.trim(),
      ListingCategory.bicycle => '$brand $model'.trim(),
      ListingCategory.yacht => '${state.year.trim()} $brand $model'.trim(),
      ListingCategory.worker =>
        serviceCategory.isEmpty ? 'Worker' : serviceCategory,
    };
    return kind.isEmpty ? 'Listing' : kind;
  }

  String _description() {
    if (state.description.trim().isNotEmpty) return state.description.trim();
    final brand = state.brand?.trim() ?? '';
    final model = state.model?.trim() ?? '';
    final serviceCategory = state.serviceCategory?.trim() ?? '';
    return switch (state.category) {
      ListingCategory.property =>
        '${state.beds ?? '—'} bedrooms, ${state.baths ?? '—'} bathrooms',
      ListingCategory.motorcycle =>
        '$brand $model${state.engineCc.trim().isEmpty ? '' : ', ${state.engineCc.trim()} cc'}'
            .trim(),
      ListingCategory.bicycle => '$brand $model'.trim(),
      ListingCategory.yacht => '$brand $model'.trim(),
      ListingCategory.worker =>
        serviceCategory.isEmpty ? 'Professional service' : serviceCategory,
    };
  }

  String _legalMimeType(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  String _mimeTypeForLegalFile(PlatformFile file) {
    final mime = _legalMimeType(file);
    return mime == 'application/octet-stream' ? 'application/pdf' : mime;
  }
}

final addListingProvider = NotifierProvider<AddListingNotifier, ListingDraft>(
  AddListingNotifier.new,
);
