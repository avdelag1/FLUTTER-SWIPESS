import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/chip_selector.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/edit_listing_provider.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:google_fonts/google_fonts.dart';
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
      return const Scaffold(
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  _sectionLabel('Photos'),
                  const SizedBox(height: 10),
                  _PhotoGrid(state: state),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(editListingProvider.notifier).pickPhotos(),
                        icon: const Icon(
                          Icons.photo_library_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Gallery',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openCamera(state),
                        icon: const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Camera',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Basics'),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _title,
                    hint: 'Title',
                    icon: Icons.title_rounded,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(title: v)),
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _price,
                    hint: 'Price (USD)',
                    icon: Icons.attach_money_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(price: v)),
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _description,
                    hint: 'Description',
                    icon: Icons.notes_rounded,
                    maxLines: 5,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(description: v)),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Location'),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _country,
                    hint: 'Country (e.g. Mexico, UAE, France)',
                    icon: Icons.public_rounded,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(country: v)),
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _city,
                    hint: 'City',
                    icon: Icons.location_city_rounded,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(city: v)),
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _neighborhood,
                    hint: 'Neighborhood / area',
                    icon: Icons.place_outlined,
                    onChanged: (v) => ref
                        .read(editListingProvider.notifier)
                        .update((c) => c.copyWith(neighborhood: v)),
                  ),
                  if (state.isProperty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Property'),
                    const SizedBox(height: 10),
                    ChipSelector(
                      label: 'Property type',
                      options: ListingTaxonomies.propertyTypes,
                      selected: state.propertyType == null
                          ? const []
                          : [state.propertyType!],
                      multi: false,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update(
                            (c) => v.isEmpty
                                ? c.copyWith(clearPropertyType: true)
                                : c.copyWith(propertyType: v.first),
                          ),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 20),
                    _sectionLabel('Vehicle'),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: _brand,
                      hint: 'Brand',
                      icon: Icons.motorcycle_rounded,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(brand: v)),
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: _model,
                      hint: 'Model',
                      icon: Icons.tag_rounded,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(model: v)),
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: _year,
                      hint: 'Year',
                      icon: Icons.calendar_today_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => ref
                          .read(editListingProvider.notifier)
                          .update((c) => c.copyWith(year: v)),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
        .update((c) => c.copyWith(newPhotos: [...c.newPhotos, ...files]));
  }

  Future<void> _save() async {
    AppHaptics.medium();
    final ok = await ref.read(editListingProvider.notifier).save();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Listing updated')));
      Navigator.of(context).pop(true);
    }
  }
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({required this.state});
  final EditListingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <Widget>[
      for (var i = 0; i < state.existingImages.length; i++)
        _tile(
          child: Image.network(state.existingImages[i], fit: BoxFit.cover),
          onRemove: () =>
              ref.read(editListingProvider.notifier).removeExistingImage(i),
        ),
      for (var i = 0; i < state.newPhotos.length; i++)
        _tile(
          child: Image.file(File(state.newPhotos[i].path), fit: BoxFit.cover),
          onRemove: () =>
              ref.read(editListingProvider.notifier).removeNewPhoto(i),
        ),
    ];
    if (tiles.isEmpty) {
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
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }

  Widget _tile({required Widget child, required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(width: 96, height: 96, child: child),
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
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
