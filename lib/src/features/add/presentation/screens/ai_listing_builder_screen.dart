import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Capacitor “AI LISTING BUILDER” — enhance + extract via edge functions.
class AiListingBuilderScreen extends ConsumerStatefulWidget {
  const AiListingBuilderScreen({super.key});

  @override
  ConsumerState<AiListingBuilderScreen> createState() =>
      _AiListingBuilderScreenState();
}

class _AiListingBuilderScreenState extends ConsumerState<AiListingBuilderScreen> {
  String _category = 'property';
  final _city = TextEditingController(text: 'Tulum');
  final _description = TextEditingController();
  final _photos = <XFile>[];
  bool _busy = false;
  bool _enhancing = false;

  @override
  void dispose() {
    _city.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() {
      _photos
        ..clear()
        ..addAll(files.take(30));
    });
  }

  Future<void> _enhance() async {
    if (_enhancing) return;
    HapticFeedback.lightImpact();
    final raw = _description.text.trim();
    if (raw.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short description first')),
      );
      return;
    }
    setState(() => _enhancing = true);
    final polished = await ref.read(aiEdgeRepositoryProvider).enhanceText(
          text: raw,
          type: 'listing',
        );
    if (!mounted) return;
    setState(() => _enhancing = false);
    if (polished == null || polished.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not enhance — try again')),
      );
      return;
    }
    setState(() => _description.text = polished);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI enhance applied')),
    );
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final notifier = ref.read(addListingProvider.notifier);
    var cat = switch (_category) {
      'motorcycle' => ListingCategory.motorcycle,
      'bicycle' => ListingCategory.bicycle,
      'yacht' => ListingCategory.yacht,
      'worker' => ListingCategory.worker,
      _ => ListingCategory.property,
    };
    notifier.reset();
    notifier.setCategory(cat);
    final desc = _description.text.trim();
    final city = _city.text.trim().isEmpty ? 'Tulum' : _city.text.trim();

    Map<String, dynamic> parsed = const {};
    if (desc.isNotEmpty) {
      parsed = await ref.read(aiEdgeRepositoryProvider).extractListing(
            category: _category,
            prompt: desc,
            city: city,
          );
    }

    final detected = parsed['category']?.toString();
    if (detected != null &&
        const {
          'property',
          'motorcycle',
          'bicycle',
          'yacht',
          'worker',
        }.contains(detected)) {
      _category = detected;
      cat = switch (detected) {
        'motorcycle' => ListingCategory.motorcycle,
        'bicycle' => ListingCategory.bicycle,
        'yacht' => ListingCategory.yacht,
        'worker' => ListingCategory.worker,
        _ => ListingCategory.property,
      };
      notifier.setCategory(cat);
    }

    final titleRaw = parsed['title']?.toString().trim();
    final descOut = parsed['description']?.toString().trim().isNotEmpty == true
        ? parsed['description'].toString().trim()
        : desc;
    final cityOut = parsed['city']?.toString().trim().isNotEmpty == true
        ? parsed['city'].toString().trim()
        : city;
    final priceOut = parsed['price']?.toString() ?? '';
    final amenities = <String>[
      if (parsed['amenities'] is List)
        ...((parsed['amenities'] as List).map((e) => e.toString())),
      if (desc.toLowerCase().contains('wifi')) 'WiFi',
      if (desc.toLowerCase().contains('pool')) 'Private Pool',
      if (desc.toLowerCase().contains('ac') || desc.toLowerCase().contains('air'))
        'AC',
    ];
    final adjectives = <String>[
      if (descOut.toLowerCase().contains('ocean') ||
          descOut.toLowerCase().contains('beach'))
        'Oceanfront',
      if (descOut.toLowerCase().contains('pool')) 'Pool',
      if (descOut.toLowerCase().contains('luxury') ||
          descOut.toLowerCase().contains('premium'))
        'Luxury',
      if (descOut.toLowerCase().contains('modern')) 'Modern',
    ];

    notifier.update(
      (d) => d.copyWith(
        city: cityOut,
        country: parsed['country']?.toString() ?? d.country,
        description: descOut,
        title: (titleRaw != null && titleRaw.isNotEmpty)
            ? titleRaw
            : (descOut.isEmpty
                ? d.title
                : (descOut.length > 48
                    ? '${descOut.substring(0, 48)}…'
                    : descOut)),
        price: priceOut.isNotEmpty ? priceOut : d.price,
        photos: [..._photos],
        adjectives: adjectives.isEmpty ? d.adjectives : adjectives,
        amenities: amenities.isEmpty ? d.amenities : amenities.toSet().toList(),
        beds: parsed['beds']?.toString() ?? d.beds,
        baths: parsed['baths']?.toString() ?? d.baths,
        propertyType: parsed['property_type']?.toString() ?? d.propertyType,
        furnished: parsed['furnished'] == true ? true : d.furnished,
        petFriendly: parsed['pet_friendly'] == true ? true : d.petFriendly,
        brand: parsed['make']?.toString() ??
            parsed['brand']?.toString() ??
            d.brand,
        model: parsed['model']?.toString() ?? d.model,
        year: parsed['year']?.toString() ?? d.year,
        mileage: parsed['mileage']?.toString() ?? d.mileage,
        engineCc: parsed['engine_cc']?.toString() ?? d.engineCc,
        vehicleType: parsed['vehicle_type']?.toString() ?? d.vehicleType,
        condition: parsed['condition']?.toString() ?? d.condition,
        lengthM: parsed['length_m']?.toString() ?? d.lengthM,
        berths: parsed['berths']?.toString() ?? d.berths,
        maxPassengers: parsed['max_passengers']?.toString() ?? d.maxPassengers,
        serviceCategory:
            parsed['service_category']?.toString() ?? d.serviceCategory,
        pricingUnit: parsed['pricing_unit']?.toString() ?? d.pricingUnit,
        skills: parsed['skills'] is List
            ? (parsed['skills'] as List).map((e) => e.toString()).toList()
            : d.skills,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AddListingScreen(initialCategory: _category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0714),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B5DE5).withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFFC9B6FF)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI LISTING BUILDER',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFC9B6FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ONE-STEP AI SETUP • EDGE',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0x99C9B6FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text('1. CATEGORY', style: _label),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in const [
                        ('property', 'PROPERTY', Icons.apartment_rounded),
                        ('motorcycle', 'MOTORCYCLE', Icons.two_wheeler_rounded),
                        ('bicycle', 'BICYCLE', Icons.pedal_bike_rounded),
                        ('yacht', 'YACHT', Icons.anchor_rounded),
                        ('worker', 'JOB / SERVICE', Icons.work_rounded),
                      ])
                        _CatChip(
                          label: c.$2,
                          icon: c.$3,
                          selected: _category == c.$1,
                          onTap: () => setState(() => _category = c.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('2. PHOTOS (${_photos.length}/30)', style: _label),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickPhotos,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withAlpha(30)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera_rounded,
                                color: Colors.white.withAlpha(140), size: 32),
                            const SizedBox(height: 8),
                            Text('TAP TO ADD PHOTOS',
                                style: _label.copyWith(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('3. LOCATION', style: _label),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _city,
                    hint: 'Quick search: type any city...',
                    icon: Icons.search_rounded,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'GENERAL AREA ONLY — NO EXACT ADDRESS',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text('4. DESCRIPTION', style: _label),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _enhancing ? null : _enhance,
                        icon: _enhancing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFC9B6FF),
                                ),
                              )
                            : const Icon(Icons.auto_awesome,
                                size: 16, color: Color(0xFFC9B6FF)),
                        label: Text(
                          'AI ENHANCE',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFC9B6FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GlassTextField(
                    controller: _description,
                    hint:
                        "Describe your listing or just tap publish. E.g. 'Stunning ocean view property with private pool'...",
                    icon: Icons.mic_none_rounded,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SECURELY PROCESSED BY SWIPESS AI (SUPABASE EDGE · GROQ).',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _create,
                      icon: const Icon(Icons.bolt_rounded),
                      label: Text(_busy ? 'PREPARING…' : 'CREATE AI LISTING'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2438),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cities: ${ListingTaxonomies.popularCities.take(3).join(', ')}…',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white24,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _label => GoogleFonts.plusJakartaSans(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      );
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.sizeOf(context).width - 42) / 2,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7B5CFF) : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected ? const Color(0xFF9B5DE5) : Colors.white.withAlpha(25),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
