import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/app_action_banner.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/chip_selector.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/add/data/remote_media_file.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/edit_listing_provider.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_swipes/src/core/widgets/glass_dropdown_field.dart';
import 'package:image_picker/image_picker.dart';

/// Cap UnifiedListingForm edit path — update title, media, details, save.
class EditListingScreen extends ConsumerStatefulWidget {
  const EditListingScreen({super.key, required this.listing});

  final Listing listing;

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  late final TextEditingController _title;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _neighborhood;
  late final TextEditingController _year;
  late final TextEditingController _mileage;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _country;
  late final TextEditingController _city;

  @override
  void initState() {
    super.initState();
    // The editor is a focused task surface. The shell header and bottom dock
    // are useful elsewhere, but they sit above this route and can intercept
    // its media and save controls on short phone screens.
    ref.read(chromeVisibilityProvider.notifier).hide();
    final seed = EditListingState.fromListing(widget.listing);
    _title = TextEditingController(text: seed.title);
    _price = TextEditingController(text: seed.price);
    _description = TextEditingController(text: seed.description);
    _country = TextEditingController(text: seed.country);
    _city = TextEditingController(text: seed.city);
    _neighborhood = TextEditingController(text: seed.neighborhood);
    _year = TextEditingController(text: seed.year);
    _mileage = TextEditingController(text: seed.mileage);
    _brand = TextEditingController(text: seed.brand ?? '');
    _model = TextEditingController(text: seed.model ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(editListingProvider.notifier).load(widget.listing);
    });
  }

  @override
  void dispose() {
    // Restore the shared controls for the profile/listing screen underneath.
    ref.read(chromeVisibilityProvider.notifier).show();
    _title.dispose();
    _price.dispose();
    _description.dispose();
    _country.dispose();
    _city.dispose();
    _neighborhood.dispose();
    _year.dispose();
    _mileage.dispose();
    _brand.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editListingProvider);
    if (state == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EDIT LISTING',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          state.category.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  _sectionLabel('Photos'),
                  SizedBox(height: 10),
                  _PhotoGrid(state: state),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(editListingProvider.notifier).pickPhotos(),
                        icon: Icon(
                          Icons.photo_library_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Gallery',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openCamera(state),
                        icon: Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Camera',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  _sectionLabel('Video'),
                  SizedBox(height: 10),
                  _VideoEditorCard(state: state),
                  SizedBox(height: 20),
                  _sectionLabel('Basics'),
                  SizedBox(height: 10),
                  GlassTextField(
                    controller: _title,
                    hint: 'Title',
                    icon: Icons.title_rounded,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(title: v)),
                  ),
                  SizedBox(height: 10),
                  GlassTextField(
                    controller: _price,
                    hint: 'Price (USD)',
                    icon: Icons.attach_money_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(price: v)),
                  ),
                  SizedBox(height: 10),
                  GlassTextField(
                    controller: _description,
                    hint: 'Description',
                    icon: Icons.notes_rounded,
                    maxLines: 5,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(description: v)),
                  ),
                  SizedBox(height: 20),
                  _sectionLabel('Location'),
                  SizedBox(height: 10),
                  GlassTextField(
                    controller: _country,
                    hint: 'Country (e.g. Mexico, UAE, France)',
                    icon: Icons.public_rounded,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(country: v)),
                  ),
                  SizedBox(height: 10),
                  GlassTextField(
                    controller: _city,
                    hint: 'City',
                    icon: Icons.location_city_rounded,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(city: v)),
                  ),
                  SizedBox(height: 10),
                  GlassTextField(
                    controller: _neighborhood,
                    hint: 'Neighborhood / area',
                    icon: Icons.place_outlined,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(neighborhood: v)),
                  ),
                  if (state.isProperty) ...[
                    SizedBox(height: 20),
                    _sectionLabel('Property'),
                    SizedBox(height: 10),
                    GlassDropdownField(
                      label: 'Property type',
                      options: ListingTaxonomies.propertyTypes,
                      value: state.propertyType,
                      icon: Icons.home_work_rounded,
                      hint: 'e.g. Apartment, House, Studio...',
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update(
                            (c) => v.isEmpty
                                ? c.copyWith(clearPropertyType: true)
                                : c.copyWith(propertyType: v),
                          ),
                    ),
                    SizedBox(height: 10),
                    ChipSelector(
                      label: 'Beds',
                      options: ListingTaxonomies.bedroomCounts,
                      selected: state.beds == null ? const [] : [state.beds!],
                      multi: false,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update(
                            (c) => c.copyWith(beds: v.isEmpty ? null : v.first),
                          ),
                    ),
                    SizedBox(height: 10),
                    ChipSelector(
                      label: 'Baths',
                      options: ListingTaxonomies.bathroomCounts,
                      selected: state.baths == null ? const [] : [state.baths!],
                      multi: false,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update(
                            (c) =>
                                c.copyWith(baths: v.isEmpty ? null : v.first),
                          ),
                    ),
                    SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Furnished',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      value: state.furnished,
                      activeTrackColor: AppTheme.brandPrimary,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(furnished: v)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Pet friendly',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      value: state.petFriendly,
                      activeTrackColor: AppTheme.brandPrimary,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(petFriendly: v)),
                    ),
                    SizedBox(height: 8),
                    ChipSelector(
                      label: 'Features',
                      options: ListingTaxonomies.propertyFeatures,
                      selected: state.amenities,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(amenities: v)),
                    ),
                  ],
                  if (state.isVehicle) ...[
                    SizedBox(height: 20),
                    _sectionLabel('Vehicle'),
                    SizedBox(height: 10),
                    GlassTextField(
                      controller: _brand,
                      hint: 'Brand',
                      icon: Icons.motorcycle_rounded,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(brand: v)),
                    ),
                    SizedBox(height: 10),
                    GlassTextField(
                      controller: _model,
                      hint: 'Model',
                      icon: Icons.tag_rounded,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(model: v)),
                    ),
                    SizedBox(height: 10),
                    GlassTextField(
                      controller: _year,
                      hint: 'Year',
                      icon: Icons.calendar_today_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(year: v)),
                    ),
                    SizedBox(height: 10),
                    GlassTextField(
                      controller: _mileage,
                      hint: 'Mileage / hours',
                      icon: Icons.speed_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(mileage: v)),
                    ),
                  ],
                  if (state.error != null) ...[
                    SizedBox(height: 16),
                    Text(
                      state.error!,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF87171),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: BrandPrimaryButton(
                label: 'Save changes',
                loading: state.saving,
                onPressed: state.saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.4,
      ),
    );
  }

  Future<void> _openCamera(EditListingState state) async {
    final remaining = state.maxPhotos - state.photoCount;
    if (remaining <= 0) return;
    final files = await Navigator.of(context).push<List<XFile>>(
      MaterialPageRoute(
        builder: (_) => ListingCameraScreen(
          maxPhotos: remaining,
          existingCount: state.photoCount,
        ),
      ),
    );
    if (files == null || files.isEmpty) return;
    ref
        .read(editListingProvider.notifier)
        .update(
          (c) => c.copyWith(
            newPhotos: [...c.newPhotos, ...files],
            photoOrder: [
              ...c.resolvedPhotoOrder,
              for (final file in files) 'new:${file.path}',
            ],
          ),
        );
  }

  Future<void> _save() async {
    AppHaptics.medium();
    final ok = await ref.read(editListingProvider.notifier).save();
    if (!mounted) return;
    if (ok) {
      AppActionBanner.success(
        context,
        title: 'Listing updated',
        detail: 'Your changes are live.',
      );
      Navigator.of(context).pop(true);
    }
  }
}

class _VideoEditorCard extends ConsumerStatefulWidget {
  const _VideoEditorCard({required this.state});

  final EditListingState state;

  @override
  ConsumerState<_VideoEditorCard> createState() => _VideoEditorCardState();
}

class _VideoEditorCardState extends ConsumerState<_VideoEditorCard> {
  bool _preparingVideo = false;

  EditListingState get state => widget.state;

  Future<void> _replaceVideo() async {
    if (state.saving || _preparingVideo) return;
    final notifier = ref.read(editListingProvider.notifier);
    final file = await notifier.pickVideo();
    if (!mounted || file == null) return;
    await _openEditor(file);
  }

  Future<void> _editVideo() async {
    if (state.saving || _preparingVideo) return;
    final notifier = ref.read(editListingProvider.notifier);
    if (!await notifier.ensureVideoAccess() || !mounted) return;

    XFile? file = state.newVideo;
    if (file == null) {
      final url = state.existingVideoUrl?.trim() ?? '';
      if (url.isEmpty) return;
      setState(() => _preparingVideo = true);
      try {
        file = await materializeRemoteMedia(
          url,
          suggestedName: 'swipess-listing-${state.listingId}.mp4',
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not prepare the current video for editing. Please retry or replace it.',
                ),
              ),
            );
        }
        return;
      } finally {
        if (mounted) setState(() => _preparingVideo = false);
      }
    }

    if (!mounted || file == null) return;
    await _openEditor(file);
  }

  Future<void> _openEditor(XFile file) async {
    final notifier = ref.read(editListingProvider.notifier);
    final current = ref.read(editListingProvider) ?? state;
    final cropped = await Navigator.of(context, rootNavigator: true)
        .push<XFile>(
          MaterialPageRoute(
            builder: (_) => VideoCropperScreen(
              file: file,
              videoAudioEnabled: current.videoAudioEnabled,
              backgroundMusic: current.backgroundMusic,
              backgroundMusicPreset: current.backgroundMusicPreset,
              backgroundMusicName: current.backgroundMusicName,
              onVideoAudioChanged: (enabled) {
                notifier.update((c) => c.copyWith(videoAudioEnabled: enabled));
              },
              onBackgroundMusicFile: (music) {
                notifier.update(
                  (c) => c.copyWith(
                    backgroundMusic: music,
                    clearBackgroundMusicPreset: true,
                    backgroundMusicName: music.name,
                    videoAudioEnabled: false,
                    removeExistingBackgroundMusic: true,
                  ),
                );
              },
              onBackgroundMusicPreset: (id, name) {
                notifier.update(
                  (c) => c.copyWith(
                    clearBackgroundMusic: true,
                    backgroundMusicPreset: id,
                    backgroundMusicName: name,
                    videoAudioEnabled: false,
                    removeExistingBackgroundMusic: true,
                  ),
                );
              },
              onBackgroundMusicClear: () {
                notifier.update(
                  (c) => c.copyWith(
                    clearBackgroundMusic: true,
                    clearBackgroundMusicPreset: true,
                    clearBackgroundMusicName: true,
                    removeExistingBackgroundMusic: true,
                  ),
                );
              },
            ),
          ),
        );
    if (cropped == null || !mounted) return;
    notifier.update(
      (c) => c.copyWith(newVideo: cropped, removeExistingVideo: false),
    );
  }

  void _customSoundtrack(XFile file) {
    ref
        .read(editListingProvider.notifier)
        .update(
          (c) => c.copyWith(
            backgroundMusic: file,
            clearBackgroundMusicPreset: true,
            backgroundMusicName: file.name,
            videoAudioEnabled: false,
            removeExistingBackgroundMusic: true,
          ),
        );
  }

  void _presetSoundtrack(String id, String name) {
    ref
        .read(editListingProvider.notifier)
        .update(
          (c) => c.copyWith(
            clearBackgroundMusic: true,
            backgroundMusicPreset: id,
            backgroundMusicName: name,
            videoAudioEnabled: false,
            removeExistingBackgroundMusic: true,
          ),
        );
  }

  void _clearSoundtrack() {
    ref
        .read(editListingProvider.notifier)
        .update(
          (c) => c.copyWith(
            clearBackgroundMusic: true,
            clearBackgroundMusicPreset: true,
            clearBackgroundMusicName: true,
            removeExistingBackgroundMusic: true,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editListingProvider.notifier);
    final pendingName = state.newVideo?.name.trim();
    final hasPending = pendingName != null && pendingName.isNotEmpty;
    final hasExisting =
        !state.removeExistingVideo &&
        (state.existingVideoUrl?.trim().isNotEmpty ?? false);
    final hasExistingCustomSoundtrack =
        state.backgroundMusic == null &&
        !state.removeExistingBackgroundMusic &&
        (state.existingBackgroundMusicUrl?.trim().isNotEmpty ?? false) &&
        !(state.backgroundMusicPreset?.trim().isNotEmpty ?? false);

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPending || hasExisting) ...[
            ListingVideoInlinePreview(
              file: hasPending ? state.newVideo : null,
              networkUrl: hasPending ? null : state.existingVideoUrl,
              muted: true,
              height: 260,
            ),
            SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withAlpha(36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _preparingVideo
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.video_settings_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPending
                          ? pendingName
                          : hasExisting
                          ? 'Current listing video'
                          : 'Add one listing video',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      _preparingVideo
                          ? 'Preparing the published clip for re-editing…'
                          : state.hasVideo
                          ? 'Trim, reframe, mute, add music or use a Swipess sound'
                          : 'Up to 60 sec • one Premium video per listing',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              if (state.hasVideo) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.saving || _preparingVideo
                        ? null
                        : _editVideo,
                    icon: Icon(Icons.tune_rounded, size: 18),
                    label: Text('Edit video'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.saving || _preparingVideo
                      ? null
                      : _replaceVideo,
                  icon: Icon(
                    state.hasVideo
                        ? Icons.swap_horiz_rounded
                        : Icons.video_library_rounded,
                    size: 18,
                  ),
                  label: Text(state.hasVideo ? 'Replace' : 'Choose video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withAlpha(54)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (state.hasVideo) ...[
                SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Remove video',
                  onPressed: state.saving || _preparingVideo
                      ? null
                      : notifier.removeVideo,
                  icon: Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
          if (state.hasVideo) ...[
            SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: Text(
                'Original video sound',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                state.videoAudioEnabled ? 'On' : 'Muted',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: state.videoAudioEnabled,
              activeTrackColor: AppTheme.brandPrimary,
              onChanged: state.saving
                  ? null
                  : (enabled) => notifier.update(
                      (c) => c.copyWith(videoAudioEnabled: enabled),
                    ),
            ),
            ListingVideoSoundtrackPicker(
              videoFile: state.newVideo,
              customMusic: state.backgroundMusic,
              presetId: state.backgroundMusicPreset,
              soundtrackName: state.backgroundMusicName,
              disabled: state.saving || _preparingVideo,
              onCustomPicked: _customSoundtrack,
              onPresetSelected: _presetSoundtrack,
              onClear: _clearSoundtrack,
            ),
            if (hasExistingCustomSoundtrack) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.fromLTRB(10, 7, 6, 7),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: Colors.white70,
                      size: 17,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        state.backgroundMusicName?.trim().isNotEmpty == true
                            ? state.backgroundMusicName!
                            : 'Current uploaded soundtrack',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: state.saving ? null : _clearSoundtrack,
                      child: Text('REMOVE'),
                    ),
                  ],
                ),
              ),
            ],
          ],
          SizedBox(height: 8),
          Text(
            'The edit page now uses the same video editor as Create with AI: 5–60s trim, portrait reframing, original-audio control, your own music and the 10 built-in Swipess sounds.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({required this.state});
  final EditListingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = state.resolvedPhotoOrder;
    if (order.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          'Add at least one photo',
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Long-press and drag to choose the exact photo order.',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white38,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: order.length,
            separatorBuilder: (_, _) => SizedBox(width: 8),
            itemBuilder: (_, index) {
              final token = order[index];
              final tile = _tileForToken(ref, token, index);
              return DragTarget<int>(
                onWillAcceptWithDetails: (details) => details.data != index,
                onAcceptWithDetails: (details) {
                  AppHaptics.light();
                  ref
                      .read(editListingProvider.notifier)
                      .reorderPhoto(details.data, index);
                },
                builder: (context, candidateData, rejectedData) {
                  final targeted = candidateData.isNotEmpty;
                  return LongPressDraggable<int>(
                    data: index,
                    maxSimultaneousDrags: 1,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: _tileForToken(ref, token, index),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: .28, child: tile),
                    child: AnimatedScale(
                      scale: targeted ? .94 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: tile,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tileForToken(WidgetRef ref, String token, int orderIndex) {
    if (token.startsWith('existing:')) {
      final url = token.substring('existing:'.length);
      final sourceIndex = state.existingImages.indexOf(url);
      return _tile(
        child: Image.network(url, fit: BoxFit.cover),
        onRemove: sourceIndex < 0
            ? () {}
            : () => ref
                  .read(editListingProvider.notifier)
                  .removeExistingImage(sourceIndex),
        isCover: orderIndex == 0,
      );
    }
    final path = token.startsWith('new:')
        ? token.substring('new:'.length)
        : token;
    final sourceIndex = state.newPhotos.indexWhere((file) => file.path == path);
    final file = sourceIndex < 0 ? null : state.newPhotos[sourceIndex];
    return _tile(
      child: file == null
          ? const ColoredBox(color: Color(0xFF16161C))
          : Image.file(File(file.path), fit: BoxFit.cover),
      onRemove: sourceIndex < 0
          ? () {}
          : () => ref
                .read(editListingProvider.notifier)
                .removeNewPhoto(sourceIndex),
      isCover: orderIndex == 0,
    );
  }

  Widget _tile({
    required Widget child,
    required VoidCallback onRemove,
    required bool isCover,
  }) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
          if (isCover)
            Positioned(
              left: 5,
              bottom: 5,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(185),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'COVER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
