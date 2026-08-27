import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/constants/service_categories.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/chip_selector.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key, this.initialCategory, this.initialMode});

  /// Optional category id from create-listing chooser (`property`, `worker`, …).
  final String? initialCategory;

  /// Optional rent / sale / both from listing-type chooser.
  final ListingMode? initialMode;

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  late final TextEditingController _title;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _neighborhood;
  late final TextEditingController _year;
  late final TextEditingController _mileage;
  late final TextEditingController _engine;
  late final TextEditingController _length;
  late final TextEditingController _berths;
  late final TextEditingController _guests;
  late final TextEditingController _model;

  static const _steps = [
    (0, 'Media', Icons.upload_rounded),
    (1, 'Category', Icons.grid_view_rounded),
    (2, 'Details', Icons.description_outlined),
    (3, 'Publish', Icons.shield_outlined),
  ];

  @override
  void initState() {
    super.initState();
    var draft = ref.read(addListingProvider);
    final seeded =
        draft.photos.isNotEmpty ||
        draft.title.trim().isNotEmpty ||
        draft.description.trim().isNotEmpty;
    if (widget.initialCategory == null &&
        widget.initialMode == null &&
        !seeded) {
      Future.microtask(() {
        if (mounted) {
          ref.read(addListingProvider.notifier).reset();
        }
      });
    }
    _title = TextEditingController(text: draft.title);
    _price = TextEditingController(text: draft.price);
    _description = TextEditingController(text: draft.description);
    _neighborhood = TextEditingController(text: draft.neighborhood);
    _year = TextEditingController(text: draft.year);
    _mileage = TextEditingController(text: draft.mileage);
    _engine = TextEditingController(text: draft.engineCc);
    _length = TextEditingController(text: draft.lengthM);
    _berths = TextEditingController(text: draft.berths);
    _guests = TextEditingController(text: draft.maxPassengers);
    _model = TextEditingController(text: draft.model ?? '');

    final initial = widget.initialCategory;
    final mode = widget.initialMode;
    if (initial != null || mode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(addListingProvider.notifier);
        if (initial != null) {
          final cat = switch (initial) {
            'motorcycle' => ListingCategory.motorcycle,
            'bicycle' => ListingCategory.bicycle,
            'yacht' => ListingCategory.yacht,
            'worker' => ListingCategory.worker,
            _ => ListingCategory.property,
          };
          if (ref.read(addListingProvider).category != cat) {
            notifier.setCategory(cat);
          }
        }
        if (mode != null) {
          notifier.setMode(mode);
        }
        // Cap wizard: Media first when category already chosen.
        if (ref.read(addListingProvider).step == 0 && initial != null) {
          // stay on Media (step 0)
        }
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _description.dispose();
    _neighborhood.dispose();
    _year.dispose();
    _mileage.dispose();
    _engine.dispose();
    _length.dispose();
    _berths.dispose();
    _guests.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(addListingProvider);
    final top = MediaQuery.paddingOf(context).top;
    final stepMeta = _steps[draft.step.clamp(0, _steps.length - 1)];

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, top + 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CapBackButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STEP ${draft.step + 1} OF ${_steps.length}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stepMeta.$2.toUpperCase(),
                              style: AppTheme.displayItalic.copyWith(
                                fontSize: 26,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _WizardStepPills(
                    current: draft.step,
                    steps: _steps,
                    onSelect: (i) =>
                        ref.read(addListingProvider.notifier).setStep(i),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (draft.step + 1) / _steps.length,
                      minHeight: 3,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFEB4898),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 160),
                children: [
                  if (draft.step == 0) _PhotosStep(draft: draft),
                  if (draft.step == 1) _CategoryStep(draft: draft),
                  if (draft.step == 2)
                    _DetailsStep(
                      draft: draft,
                      title: _title,
                      price: _price,
                      description: _description,
                      neighborhood: _neighborhood,
                      year: _year,
                      mileage: _mileage,
                      engine: _engine,
                      length: _length,
                      berths: _berths,
                      guests: _guests,
                      model: _model,
                    ),
                  if (draft.step == 3) _PublishStep(draft: draft),
                  if (draft.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      draft.error!,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF87171),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (draft.step > 0)
                    BrandGhostButton(
                      label: 'Back',
                      onPressed: () => ref
                          .read(addListingProvider.notifier)
                          .setStep(draft.step - 1),
                    ),
                  if (draft.step > 0) const SizedBox(height: 12),
                  BrandPrimaryButton(
                    label: draft.step == 3 ? 'Publish listing' : 'Continue',
                    loading: draft.publishing,
                    onPressed: draft.publishing ? null : () => _next(draft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _next(ListingDraft draft) async {
    final notifier = ref.read(addListingProvider.notifier);
    notifier.update(
      (current) => current.copyWith(
        title: _title.text,
        price: _price.text,
        description: _description.text,
        neighborhood: _neighborhood.text,
        year: _year.text,
        mileage: _mileage.text,
        engineCc: _engine.text,
        lengthM: _length.text,
        berths: _berths.text,
        maxPassengers: _guests.text,
        model: _model.text.trim().isEmpty ? current.model : _model.text.trim(),
      ),
    );
    if (draft.step == 0 && draft.photos.isEmpty) {
      notifier.update(
        (c) => c.copyWith(error: 'Add at least one photo to continue.'),
      );
      return;
    }
    if (draft.step < 3) {
      notifier.setStep(draft.step + 1);
      return;
    }
    final ok = await notifier.publish();
    if (!mounted) return;
    final publishNotice = notifier.lastPublishNotice;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (publishNotice ??
                    'Listing published — it is live on the swipe deck.')
              : (ref.read(addListingProvider).error ??
                    'Could not save listing'),
        ),
      ),
    );
    if (ok) Navigator.of(context).maybePop();
  }
}

class _WizardStepPills extends StatelessWidget {
  const _WizardStepPills({
    required this.current,
    required this.steps,
    required this.onSelect,
  });

  final int current;
  final List<(int, String, IconData)> steps;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final step in steps) ...[
            GestureDetector(
              onTap: () => onSelect(step.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: step.$1 == current
                      ? AppTheme.brandPrimary
                      : step.$1 < current
                      ? const Color(0x2610B981)
                      : Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: step.$1 == current
                        ? AppTheme.brandPrimary
                        : step.$1 < current
                        ? const Color(0x4D10B981)
                        : Colors.white24,
                  ),
                  boxShadow: step.$1 == current
                      ? [
                          BoxShadow(
                            color: Colors.transparent,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      step.$1 < current ? Icons.check_rounded : step.$3,
                      size: 12,
                      color: step.$1 == current
                          ? Colors.white
                          : step.$1 < current
                          ? const Color(0xFF34D399)
                          : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      step.$2,
                      style: GoogleFonts.plusJakartaSans(
                        color: step.$1 == current
                            ? Colors.white
                            : step.$1 < current
                            ? const Color(0xFF34D399)
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublishStep extends StatelessWidget {
  const _PublishStep({required this.draft});
  final ListingDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & publish',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Confirm your listing looks right. Publishing makes it live on the swipe deck.',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _ReviewRow(label: 'Category', value: draft.category.name.toUpperCase()),
        _ReviewRow(label: 'Mode', value: draft.modeValue.toUpperCase()),
        _ReviewRow(label: 'Photos', value: '${draft.photos.length}'),
        _ReviewRow(
          label: 'Title',
          value: draft.title.trim().isEmpty ? '(auto)' : draft.title,
        ),
        _ReviewRow(
          label: 'Price',
          value: draft.price.trim().isEmpty ? '—' : draft.price,
        ),
        _ReviewRow(label: 'City', value: draft.city),
        if (draft.neighborhood.trim().isNotEmpty)
          _ReviewRow(label: 'Neighborhood', value: draft.neighborhood),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x2610B981),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x4D10B981)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF34D399)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your listing will appear for seekers matching this category and location.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFA7F3D0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Cap wizard chrome: Media → Category → Details → Publish

class _CategoryStep extends ConsumerWidget {
  const _CategoryStep({required this.draft});
  final ListingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const categories = [
      (
        ListingCategory.property,
        Icons.home_work_rounded,
        'Properties',
        'Homes, rooms, land',
      ),
      (
        ListingCategory.motorcycle,
        Icons.two_wheeler_rounded,
        'Motorcycles',
        'Motos for rent or sale',
      ),
      (
        ListingCategory.bicycle,
        Icons.pedal_bike_rounded,
        'Bicycles',
        'Bikes and e-bikes',
      ),
      (
        ListingCategory.yacht,
        Icons.sailing_rounded,
        'Yachts',
        'Boats to charter or buy',
      ),
      (
        ListingCategory.worker,
        Icons.work_rounded,
        'Workers',
        'Services and professionals',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in categories) ...[
          _SelectCard(
            icon: item.$2,
            title: item.$3,
            subtitle: item.$4,
            active: draft.category == item.$1,
            onTap: () =>
                ref.read(addListingProvider.notifier).setCategory(item.$1),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Text(
          'LISTING MODE',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xB3FFFFFF),
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ModePill(
                label: 'For Rent',
                icon: Icons.key_rounded,
                active:
                    draft.mode == ListingMode.rent ||
                    draft.mode == ListingMode.both,
                onTap: () => ref
                    .read(addListingProvider.notifier)
                    .toggleMode(ListingMode.rent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModePill(
                label: 'For Sale',
                icon: Icons.sell_rounded,
                active:
                    draft.mode == ListingMode.sale ||
                    draft.mode == ListingMode.both,
                onTap: () => ref
                    .read(addListingProvider.notifier)
                    .toggleMode(ListingMode.sale),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotosStep extends ConsumerWidget {
  const _PhotosStep({required this.draft});
  final ListingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PHOTOS · up to ${draft.maxPhotos} · first is the swipe cover',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.read(addListingProvider.notifier).pickPhotos(),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final files = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ListingCameraScreen(
                        maxPhotos: draft.maxPhotos,
                        existingCount: draft.photos.length,
                      ),
                    ),
                  );
                  if (files is! List || files.isEmpty) return;
                  final picked = files.whereType<XFile>().toList();
                  if (picked.isEmpty) return;
                  ref
                      .read(addListingProvider.notifier)
                      .update(
                        (d) => d.copyWith(
                          photos: [
                            ...d.photos,
                            ...picked,
                          ].take(draft.maxPhotos).toList(),
                        ),
                      );
                },
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Camera'),
                style: FilledButton.styleFrom(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: draft.photos.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            if (index == draft.photos.length) {
              return GestureDetector(
                onTap: () => ref.read(addListingProvider.notifier).pickPhotos(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.transparent,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Colors.white,
                  ),
                ),
              );
            }
            final photo = draft.photos[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FutureBuilder(
                    future: photo.readAsBytes(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const ColoredBox(color: Color(0xFF16161C));
                      }
                      return Image.memory(snap.data!, fit: BoxFit.cover);
                    },
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => ref
                        .read(addListingProvider.notifier)
                        .removePhoto(index),
                    child: const CircleAvatar(
                      radius: 12,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
                if (index == 0)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'COVER',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          'VIDEO · optional 10s loop for the swipe card',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        if (draft.video != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, color: Color(0xFFEB4898)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    draft.video!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(addListingProvider.notifier).removeVideo(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: () async {
              final picker = ImagePicker();
              final file = await picker.pickVideo(source: ImageSource.gallery);
              if (file == null || !context.mounted) return;
              final cropped = await Navigator.of(context).push<XFile>(
                MaterialPageRoute(
                  builder: (_) => VideoCropperScreen(file: file),
                ),
              );
              if (cropped != null && context.mounted) {
                ref.read(addListingProvider.notifier).setVideo(cropped);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white24,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.video_call_rounded,
                    color: Color(0xFFEB4898),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload looping video',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '10-second loop · under 50MB',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailsStep extends ConsumerWidget {
  const _DetailsStep({
    required this.draft,
    required this.title,
    required this.price,
    required this.description,
    required this.neighborhood,
    required this.year,
    required this.mileage,
    required this.engine,
    required this.length,
    required this.berths,
    required this.guests,
    required this.model,
  });

  final ListingDraft draft;
  final TextEditingController title;
  final TextEditingController price;
  final TextEditingController description;
  final TextEditingController neighborhood;
  final TextEditingController year;
  final TextEditingController mileage;
  final TextEditingController engine;
  final TextEditingController length;
  final TextEditingController berths;
  final TextEditingController guests;
  final TextEditingController model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(addListingProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassTextField(
          controller: title,
          hint: 'Title (optional — we can build it)',
          icon: Icons.title_rounded,
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: price,
          hint: draft.category == ListingCategory.worker ? 'Rate' : 'Price',
          icon: Icons.attach_money_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: description,
          hint: draft.category == ListingCategory.property
              ? 'Description — Airbnb-style story of the stay'
              : draft.category == ListingCategory.worker
              ? 'Describe your service, experience, and vibe'
              : 'Description — optional if chips below tell the story',
          icon: Icons.notes_rounded,
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        ChipSelector(
          label: 'City',
          options: ListingTaxonomies.popularCities,
          selected: [draft.city],
          multi: false,
          onChanged: (v) {
            if (v.isEmpty) return;
            n.update((c) => c.copyWith(city: v.first));
          },
        ),
        const SizedBox(height: 16),
        GlassTextField(
          controller: neighborhood,
          hint: 'Neighborhood (optional)',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 20),
        ChipSelector(
          label: 'Vibe words',
          options: ListingTaxonomies.adjectives,
          selected: draft.adjectives,
          onChanged: (v) => n.update((c) => c.copyWith(adjectives: v)),
        ),
        const SizedBox(height: 20),
        if (draft.category == ListingCategory.property) ..._property(n),
        if (draft.category == ListingCategory.motorcycle) ..._moto(n),
        if (draft.category == ListingCategory.bicycle) ..._bike(n),
        if (draft.category == ListingCategory.yacht) ..._yacht(n),
        if (draft.category == ListingCategory.worker) ..._worker(n),
      ],
    );
  }

  List<Widget> _property(AddListingNotifier n) {
    return [
      ChipSelector(
        label: 'Size',
        options: ListingTaxonomies.sizes,
        selected: draft.sizes,
        onChanged: (v) => n.update((c) => c.copyWith(sizes: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Property type',
        options: ListingTaxonomies.propertyTypes,
        selected: draft.propertyType == null ? const [] : [draft.propertyType!],
        multi: false,
        onChanged: (v) => n.update(
          (c) => c.copyWith(
            propertyType: v.isEmpty ? null : v.first,
            clearPropertyType: v.isEmpty,
          ),
        ),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Bedrooms',
        options: ListingTaxonomies.bedroomCounts,
        selected: draft.beds == null ? const [] : [draft.beds!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(beds: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Bathrooms',
        options: ListingTaxonomies.bathroomCounts,
        selected: draft.baths == null ? const [] : [draft.baths!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(baths: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Vibe',
        options: ListingTaxonomies.propertyVibe,
        selected: draft.vibe,
        onChanged: (v) => n.update((c) => c.copyWith(vibe: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Features',
        options: ListingTaxonomies.propertyFeatures,
        selected: draft.amenities,
        onChanged: (v) => n.update((c) => c.copyWith(amenities: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Included',
        options: ListingTaxonomies.propertyIncluded,
        selected: draft.included,
        onChanged: (v) => n.update((c) => c.copyWith(included: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'House rules',
        options: ListingTaxonomies.propertyRules,
        selected: draft.rules,
        onChanged: (v) => n.update((c) => c.copyWith(rules: v)),
      ),
      if (draft.mode != ListingMode.sale) ...[
        const SizedBox(height: 20),
        ChipSelector(
          label: 'Rental duration',
          options: ListingTaxonomies.rentalDurations,
          selected: draft.rentalDuration == null
              ? const []
              : [draft.rentalDuration!],
          multi: false,
          onChanged: (v) => n.update(
            (c) => c.copyWith(rentalDuration: v.isEmpty ? null : v.first),
          ),
        ),
      ],
    ];
  }

  List<Widget> _moto(AddListingNotifier n) {
    return [
      ChipSelector(
        label: 'Type',
        options: ListingTaxonomies.motoTypes,
        selected: draft.vehicleType == null ? const [] : [draft.vehicleType!],
        multi: false,
        onChanged: (v) => n.update(
          (c) => c.copyWith(vehicleType: v.isEmpty ? null : v.first),
        ),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Brand',
        options: ListingTaxonomies.motoBrands,
        selected: draft.brand == null ? const [] : [draft.brand!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(brand: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: model,
        hint: 'Model',
        icon: Icons.two_wheeler_rounded,
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: year,
        hint: 'Year',
        keyboardType: TextInputType.number,
        icon: Icons.calendar_today_rounded,
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: mileage,
        hint: 'Mileage (km)',
        keyboardType: TextInputType.number,
        icon: Icons.speed_rounded,
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: engine,
        hint: 'Engine cc',
        keyboardType: TextInputType.number,
        icon: Icons.tune_rounded,
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Condition',
        options: ListingTaxonomies.motoConditions,
        selected: draft.condition == null ? const [] : [draft.condition!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(condition: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Features',
        options: ListingTaxonomies.motoFeatures,
        selected: draft.features,
        onChanged: (v) => n.update((c) => c.copyWith(features: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Included',
        options: ListingTaxonomies.motoIncluded,
        selected: draft.vehicleIncluded,
        onChanged: (v) => n.update((c) => c.copyWith(vehicleIncluded: v)),
      ),
    ];
  }

  List<Widget> _bike(AddListingNotifier n) {
    return [
      ChipSelector(
        label: 'Type',
        options: ListingTaxonomies.bikeTypes,
        selected: draft.vehicleType == null ? const [] : [draft.vehicleType!],
        multi: false,
        onChanged: (v) => n.update(
          (c) => c.copyWith(vehicleType: v.isEmpty ? null : v.first),
        ),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Brand',
        options: ListingTaxonomies.bikeBrands,
        selected: draft.brand == null ? const [] : [draft.brand!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(brand: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: model,
        hint: 'Model',
        icon: Icons.pedal_bike_rounded,
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Frame size',
        options: ListingTaxonomies.bikeFrameSizes,
        selected: draft.frameSize == null ? const [] : [draft.frameSize!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(frameSize: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Condition',
        options: ListingTaxonomies.bikeConditions,
        selected: draft.condition == null ? const [] : [draft.condition!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(condition: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Features',
        options: ListingTaxonomies.bikeFeatures,
        selected: draft.features,
        onChanged: (v) => n.update((c) => c.copyWith(features: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Included',
        options: ListingTaxonomies.bikeIncluded,
        selected: draft.vehicleIncluded,
        onChanged: (v) => n.update((c) => c.copyWith(vehicleIncluded: v)),
      ),
    ];
  }

  List<Widget> _yacht(AddListingNotifier n) {
    return [
      ChipSelector(
        label: 'Type',
        options: ListingTaxonomies.yachtTypes,
        selected: draft.vehicleType == null ? const [] : [draft.vehicleType!],
        multi: false,
        onChanged: (v) => n.update(
          (c) => c.copyWith(vehicleType: v.isEmpty ? null : v.first),
        ),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Brand',
        options: ListingTaxonomies.yachtBrands,
        selected: draft.brand == null ? const [] : [draft.brand!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(brand: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: model,
        hint: 'Model',
        icon: Icons.sailing_rounded,
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: length,
        hint: 'Length (m)',
        keyboardType: TextInputType.number,
        icon: Icons.straighten_rounded,
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: berths,
        hint: 'Berths',
        keyboardType: TextInputType.number,
        icon: Icons.bed_rounded,
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: guests,
        hint: 'Max guests',
        keyboardType: TextInputType.number,
        icon: Icons.groups_rounded,
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Condition',
        options: ListingTaxonomies.yachtConditions,
        selected: draft.condition == null ? const [] : [draft.condition!],
        multi: false,
        onChanged: (v) =>
            n.update((c) => c.copyWith(condition: v.isEmpty ? null : v.first)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Features',
        options: ListingTaxonomies.yachtFeatures,
        selected: draft.features,
        onChanged: (v) => n.update((c) => c.copyWith(features: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Included',
        options: ListingTaxonomies.yachtIncluded,
        selected: draft.vehicleIncluded,
        onChanged: (v) => n.update((c) => c.copyWith(vehicleIncluded: v)),
      ),
    ];
  }

  List<Widget> _worker(AddListingNotifier n) {
    final skills = skillsForService(draft.serviceCategory);
    return [
      Text(
        'SERVICE TYPE',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 10),
      for (final group in serviceGroups) ...[
        Text(
          group.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.brandPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        ChipSelector(
          label: '',
          options: serviceCategoriesInGroup(group).map((s) => s.label).toList(),
          selected: draft.serviceCategory == null
              ? const []
              : [serviceCategoryLabel(draft.serviceCategory)],
          multi: false,
          onChanged: (v) {
            if (v.isEmpty) {
              n.update(
                (c) => c.copyWith(serviceCategory: null, skills: const []),
              );
              return;
            }
            final match = serviceCategories.firstWhere(
              (s) => s.label == v.first,
              orElse: () => serviceCategories.last,
            );
            n.update(
              (c) => c.copyWith(serviceCategory: match.value, skills: const []),
            );
          },
        ),
        const SizedBox(height: 14),
      ],
      if (skills.isNotEmpty) ...[
        ChipSelector(
          label: 'Skills / specialties',
          options: skills,
          selected: draft.skills,
          onChanged: (v) => n.update((c) => c.copyWith(skills: v)),
        ),
        const SizedBox(height: 20),
      ],
      ChipSelector(
        label: 'Traits',
        options: ListingTaxonomies.workerTraits,
        selected: draft.traits,
        onChanged: (v) => n.update((c) => c.copyWith(traits: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Availability',
        options: ListingTaxonomies.workerAvailability,
        selected: draft.availability,
        onChanged: (v) => n.update((c) => c.copyWith(availability: v)),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Pricing',
        options: ListingTaxonomies.workerPricing,
        selected: draft.pricingUnit == null ? const [] : [draft.pricingUnit!],
        multi: false,
        onChanged: (v) => n.update(
          (c) => c.copyWith(pricingUnit: v.isEmpty ? null : v.first),
        ),
      ),
      const SizedBox(height: 20),
      ChipSelector(
        label: 'Languages',
        options: ListingTaxonomies.languages,
        selected: draft.languages,
        onChanged: (v) => n.update((c) => c.copyWith(languages: v)),
      ),
    ];
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.brandPrimary.withAlpha(40)
              : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? AppTheme.brandPrimary : Colors.white.withAlpha(25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: Icon(icon, color: AppTheme.brandPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              active ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppTheme.brandPrimary : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppTheme.brandPrimary : Colors.white.withAlpha(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
