import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

/// Cap live map — raster tiles + pins. Map stays mounted so taps/filters don't freeze.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  String _category = 'all';
  Listing? _selected;
  bool _menuOpen = false;
  bool _radiusOpen = false;
  final _mapController = MapController();

  static const _categories = [
    ('all', 'All', Icons.public_rounded),
    ('property', 'Homes', Icons.apartment_rounded),
    ('motorcycle', 'Motos', Icons.two_wheeler_rounded),
    ('bicycle', 'Bikes', Icons.pedal_bike_rounded),
    ('yacht', 'Yachts', Icons.sailing_rounded),
    ('worker', 'Workers', Icons.people_alt_rounded),
  ];

  /// Cap pin pressure — too many Marker widgets rebuild-locks the map.
  static const _maxPins = 60;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<Listing> _filtered(List<Listing> listings) {
    final base = _category == 'all'
        ? listings
        : listings.where((l) => (l.category ?? '') == _category).toList();
    if (base.length <= _maxPins) return base;
    return base.take(_maxPins).toList();
  }

  double _zoomForRadius(int km) {
    if (km <= 5) return 13.2;
    if (km <= 10) return 12.4;
    if (km <= 25) return 11.4;
    if (km <= 50) return 10.6;
    if (km <= 100) return 9.6;
    return 8.6;
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(discoveryLocationProvider);
    final async = ref.watch(mapListingsProvider);
    final center = LatLng(location.latitude, location.longitude);
    final listings = async.asData?.value ?? const <Listing>[];
    final filtered = _filtered(listings);
    final radiusKm = location.radiusKm;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Stack(
        children: [
          // Always mounted — never gate the map behind listing Future.
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, _) {
                if (_selected != null) setState(() => _selected = null);
              },
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
                keepBuffer: 2,
                panBuffer: 1,
              ),
              MarkerLayer(
                markers: [
                  for (final listing in filtered)
                    if (listing.latitude != null && listing.longitude != null)
                      Marker(
                        point: LatLng(listing.latitude!, listing.longitude!),
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _selected = listing),
                          child: _Pin(
                            listing: listing,
                            selected: _selected?.id == listing.id,
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),
          if (async.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: AppTheme.brandPrimary,
              ),
            ),
          if (async.hasError && listings.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: Material(
                color: const Color(0xE016161C),
                borderRadius: BorderRadius.circular(16),
                child: TextButton(
                  onPressed: () => ref.invalidate(mapListingsProvider),
                  child: const Text(
                    'Pins failed to load — tap to retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HudCircle(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _HudCircle(
                        icon: _menuOpen
                            ? Icons.close_rounded
                            : Icons.menu_rounded,
                        onTap: () => setState(() {
                          _menuOpen = !_menuOpen;
                          if (_menuOpen) _radiusOpen = false;
                        }),
                      ),
                      if (_menuOpen) ...[
                        const SizedBox(height: 8),
                        _HudCircle(
                          icon: Icons.search_rounded,
                          onTap: () => _pickCity(context),
                        ),
                        const SizedBox(height: 8),
                        _HudCircle(
                          icon: Icons.navigation_rounded,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _mapController.move(
                              center,
                              _zoomForRadius(radiusKm),
                            );
                          },
                          accent: true,
                        ),
                        const SizedBox(height: 8),
                        for (final c in _categories.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HudCircle(
                              icon: c.$3,
                              selected: _category == c.$1,
                              onTap: () => setState(() {
                                _category = c.$1;
                                _selected = null;
                              }),
                            ),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom-left Cap controls
          Positioned(
            left: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xF2161B27),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF34D399).withAlpha(180),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You are here',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _mapController.move(
                          center,
                          _zoomForRadius(radiusKm),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0072FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x660072FF),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            _radiusOpen = !_radiusOpen;
                            if (_radiusOpen) _menuOpen = false;
                          }),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xF2161B27),
                              borderRadius: BorderRadius.circular(999),
                              border:
                                  Border.all(color: Colors.white.withAlpha(30)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '$radiusKm km',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF00C6FF),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _radiusOpen
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
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
              bottom: MediaQuery.paddingOf(context).bottom + 120,
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
    final cities = [
      'Tulum',
      'Cancún',
      'Playa del Carmen',
      'Mérida',
      'Mexico City',
    ];
    final city = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12161F),
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
            for (final city in cities)
              ListTile(
                title: Text(city, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, city),
              ),
          ],
        );
      },
    );
    if (city != null && mounted) {
      ref.read(discoveryLocationProvider.notifier).setCity(city);
      final loc = ref.read(discoveryLocationProvider);
      _mapController.move(
        LatLng(loc.latitude, loc.longitude),
        _zoomForRadius(loc.radiusKm),
      );
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
    final price = listing.price;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? Colors.white : AppTheme.brandPrimary,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.brandPrimary : Colors.white,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          price == null ? '•' : '\$${price.toStringAsFixed(0)}',
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

class _HudCircle extends StatelessWidget {
  const _HudCircle({
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected || accent
              ? Colors.black.withAlpha(160)
              : Colors.black.withAlpha(90),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? const Color(0xFF00C6FF)
                : Colors.white.withAlpha(40),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
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
        height: 96,
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
                  ? Image.network(
                      listing.primaryImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0xFF22222A)),
                    )
                  : const ColoredBox(color: Color(0xFF22222A)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      listing.title ?? 'Listing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      listing.formattedLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      listing.formattedPrice,
                      style: const TextStyle(
                        color: AppTheme.brandPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
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
