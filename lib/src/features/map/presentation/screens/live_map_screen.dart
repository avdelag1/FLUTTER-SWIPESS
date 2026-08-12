import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

/// Cap live map — OSM pins + category chips + preview card.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  String _category = 'all';
  Listing? _selected;
  final _mapController = MapController();

  static const _categories = [
    ('all', 'All'),
    ('property', 'Homes'),
    ('motorcycle', 'Motos'),
    ('bicycle', 'Bikes'),
    ('yacht', 'Yachts'),
    ('worker', 'Workers'),
  ];

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(discoveryLocationProvider);
    final async = ref.watch(mapListingsProvider);
    final center = LatLng(location.latitude, location.longitude);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(mapListingsProvider),
                child: const Text('Could not load map pins — retry'),
              ),
            ),
            data: (listings) {
              final filtered = _category == 'all'
                  ? listings
                  : listings
                      .where((l) => (l.category ?? '') == _category)
                      .toList();
              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12,
                  minZoom: 3,
                  maxZoom: 18,
                  onTap: (_, _) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConfig.hasMapboxToken
                        ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    additionalOptions: AppConfig.hasMapboxToken
                        ? {'accessToken': AppConfig.mapboxAccessToken}
                        : const {},
                    userAgentPackageName: 'com.swipess.flutter',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      for (final listing in filtered)
                        if (listing.latitude != null &&
                            listing.longitude != null)
                          Marker(
                            point: LatLng(
                                listing.latitude!, listing.longitude!),
                            width: 52,
                            height: 52,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selected = listing),
                              child: _Pin(
                                listing: listing,
                                selected: _selected?.id == listing.id,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _GlassCircle(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickCity(context),
                          child: Container(
                            height: 48,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(180),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: AppTheme.brandPrimary, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.expand_more_rounded,
                                    color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final c in _categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.$2),
                            selected: _category == c.$1,
                            onSelected: (_) => setState(() {
                              _category = c.$1;
                              _selected = null;
                            }),
                            selectedColor: AppTheme.brandPrimary,
                            backgroundColor: Colors.black.withAlpha(160),
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                            side: BorderSide(
                                color: Colors.white.withAlpha(40)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: _PreviewCard(
                listing: _selected!,
                onOpen: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ListingDetailScreen(listingData: _selected!),
                    ),
                  );
                },
                onClose: () => setState(() => _selected = null),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCity(BuildContext context) async {
    final city = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('CHOOSE CITY',
                style: AppTheme.displayItalic.copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            for (final city in ListingTaxonomies.popularCities)
              ListTile(
                title: Text(city, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, city),
              ),
          ],
        );
      },
    );
    if (city != null) {
      ref.read(discoveryLocationProvider.notifier).setCity(city);
      final loc = ref.read(discoveryLocationProvider);
      _mapController.move(LatLng(loc.latitude, loc.longitude), 12);
      setState(() => _selected = null);
    }
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.listing, required this.selected});
  final Listing listing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? Colors.white : AppTheme.brandPrimary,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.brandPrimary : Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandPrimary.withAlpha(selected ? 180 : 120),
            blurRadius: selected ? 16 : 12,
          ),
        ],
      ),
      child: Center(
        child: Text(
          listing.price == null
              ? '•'
              : '\$${listing.price!.toStringAsFixed(0)}',
          style: TextStyle(
            color: selected ? AppTheme.brandPrimary : Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.listing,
    required this.onOpen,
    required this.onClose,
  });

  final Listing listing;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF014141A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: listing.primaryImage != null
                  ? Image.network(listing.primaryImage!, fit: BoxFit.cover)
                  : const ColoredBox(color: Color(0xFF22222A)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title ?? 'Listing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      listing.formattedLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      listing.formattedPrice,
                      style: const TextStyle(
                        color: AppTheme.brandPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onOpen,
                      child: Text(
                        'OPEN DETAILS →',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
