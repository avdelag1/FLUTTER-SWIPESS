import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/data/map_basemap.dart';
import 'package:flutter_swipes/src/features/map/data/map_camera.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

/// Cap PassportMap / live map — satellite fly-in, 10 km radius, listings + people.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({
    super.key,
    this.asOverlay = false,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final bool asOverlay;
  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen>
    with SingleTickerProviderStateMixin {
  String _layer = 'all'; // all | listings | people
  String _category = 'all';
  MapPin? _selected;
  bool _menuOpen = false;
  bool _radiusOpen = false;
  bool _citiesOpen = false;
  final _mapController = MapController();
  double _zoom = MapCameraMath.openAltitudeZoom;
  late final AnimationController _fly;
  bool _didFly = false;
  bool _mapReady = false;

  static const _categories = [
    ('all', 'All', Icons.public_rounded),
    ('property', 'Homes', Icons.apartment_rounded),
    ('motorcycle', 'Motos', Icons.two_wheeler_rounded),
    ('bicycle', 'Bikes', Icons.pedal_bike_rounded),
    ('yacht', 'Yachts', Icons.sailing_rounded),
    ('worker', 'Workers', Icons.people_alt_rounded),
  ];

  static const _radiusOptions = [5, 10, 25, 50, 100, 200];

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: MapCameraMath.openGlideMs),
    );
  }

  @override
  void dispose() {
    _fly.stop();
    _fly.dispose();
    _mapController.dispose();
    super.dispose();
  }

  double _zoomForRadius(int km) => MapCameraMath.zoomForRadiusKm(km);

  void _safeMove(LatLng dest, double zoom, {double rotation = 0}) {
    if (!_mapReady) return;
    try {
      _mapController.moveAndRotate(dest, zoom, rotation);
    } catch (_) {}
  }

  void _startDroneFlyIn(LatLng center, int radiusKm) {
    if (_didFly) return;
    _didFly = true;
    final startZ = MapCameraMath.openAltitudeZoom;
    final endZ = _zoomForRadius(radiusKm);
    // Web: skip bank rotation — rotated raster tiles often fail to paint.
    final startBank = kIsWeb ? 0.0 : MapCameraMath.openBankDegrees;
    _fly.addListener(() {
      if (!mounted || !_mapReady) return;
      final t = Curves.easeInOutCubic.transform(_fly.value);
      final z = startZ + (endZ - startZ) * t;
      final bank = startBank * (1 - t);
      _safeMove(center, z, rotation: bank);
    });
    _fly.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _safeMove(center, endZ);
      }
    });
    _fly.forward();
  }

  List<_MapCluster> _cluster(List<MapPin> pins, double zoom) {
    if (pins.isEmpty) return const [];
    final cell = zoom >= 13
        ? 0.01
        : zoom >= 11
            ? 0.04
            : zoom >= 9
                ? 0.12
                : 0.28;
    final buckets = <String, List<MapPin>>{};
    for (final p in pins) {
      final key =
          '${(p.lat / cell).floor()}_${(p.lng / cell).floor()}';
      buckets.putIfAbsent(key, () => []).add(p);
    }
    return [
      for (final group in buckets.values)
        _MapCluster(
          point: LatLng(
            group.map((e) => e.lat).reduce((a, b) => a + b) /
                group.length,
            group.map((e) => e.lng).reduce((a, b) => a + b) /
                group.length,
          ),
          pins: group,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(discoveryLocationProvider);
    final asyncListings = ref.watch(mapListingsProvider);
    final asyncProfiles = ref.watch(mapProfilesProvider);
    final center = LatLng(location.latitude, location.longitude);
    final radiusKm = location.radiusKm;
    
    final listingsRaw = asyncListings.value ?? [];
    final profiles = asyncProfiles.value ?? [];
    final isLoading = asyncListings.isLoading || asyncProfiles.isLoading;
    final listings = listingsRaw.isNotEmpty
        ? listingsRaw
        : _demoListings(center, location.city);
    const haversine = Distance();
    bool inRadius(double lat, double lng) {
      return haversine.as(
            LengthUnit.Kilometer,
            center,
            LatLng(lat, lng),
          ) <=
          radiusKm;
    }

    return Material(
      color: const Color(0xFF1A1A2E),
      child: Stack(
        children: [
          Positioned.fill(
            child: Builder(builder: (context) {
              final List<MapPin> allPins = [
                if (_layer != 'people')
                  ...listings
                      .where((l) =>
                          l.latitude != null &&
                          l.longitude != null &&
                          inRadius(l.latitude!, l.longitude!))
                      .map((l) => MapPin.listing(l)),
                if (_layer != 'listings')
                  ...profiles
                      .where((p) =>
                          p.latitude != null &&
                          p.longitude != null &&
                          inRadius(p.latitude!, p.longitude!))
                      .map((p) => MapPin.profile(p)),
              ];
              final filtered = _category == 'all' || _layer == 'people'
                  ? allPins
                  : allPins
                      .where((p) =>
                          !p.isListing ||
                          (p.listing?.category ?? '') == _category)
                      .toList();
              final clusters = _cluster(filtered, _zoom);
              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: MapCameraMath.openAltitudeZoom,
                  initialRotation: kIsWeb ? 0 : MapCameraMath.openBankDegrees,
                  minZoom: 3,
                  maxZoom: 18,
                  backgroundColor: const Color(0xFF1A1A2E),
                  onMapReady: () {
                    _mapReady = true;
                    _startDroneFlyIn(center, radiusKm);
                  },
                  onTap: (_, _) => setState(() {
                    _selected = null;
                    _menuOpen = false;
                    _radiusOpen = false;
                  }),
                  onPositionChanged: (pos, _) {
                    final z = pos.zoom;
                    if (_fly.isAnimating) {
                      _zoom = z;
                      return;
                    }
                    if ((z - _zoom).abs() > 0.15) {
                      setState(() => _zoom = z);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: MapBasemap.streetsUrl,
                    subdomains: MapBasemap.subdomains,
                    userAgentPackageName: MapBasemap.userAgentPackageName,
                    tileDimension: 256,
                    maxNativeZoom: 19,
                  ),
                  TileLayer(
                    urlTemplate: MapBasemap.urlTemplate,
                    additionalOptions: MapBasemap.additionalOptions,
                    userAgentPackageName: MapBasemap.userAgentPackageName,
                    tileDimension: 256,
                    maxNativeZoom: 19,
                  ),
                  if (MapBasemap.labelsUrl != null)
                    TileLayer(
                      urlTemplate: MapBasemap.labelsUrl!,
                      subdomains: MapBasemap.subdomains,
                      userAgentPackageName: MapBasemap.userAgentPackageName,
                      tileDimension: 256,
                      maxNativeZoom: 19,
                    ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: const Color(0x1400C6FF),
                        borderColor: const Color(0xCC00C6FF),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C6FF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x8800C6FF),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final c in clusters)
                        if (c.count == 1)
                          _pinMarker(
                            c.pins.first,
                            selected: _selected != null &&
                                _samePin(_selected!, c.pins.first),
                          )
                        else
                          Marker(
                            point: c.point,
                            width: c.count >= 10 ? 56 : 48,
                            height: c.count >= 10 ? 56 : 48,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _safeMove(
                                  c.point,
                                  math.min(_zoom + 1.6, 16),
                                );
                              },
                              child: _ClusterBubble(count: c.count),
                            ),
                          ),
                    ],
                  ),
                ],
              );
            }),
          ),
          if (isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF00C6FF),
                backgroundColor: Colors.transparent,
              ),
            ),

          // Cap HUD — X left, Menu right
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HudCircle(
                    icon: Icons.close_rounded,
                    onTap: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
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
                          onTap: () => setState(() {
                            _citiesOpen = !_citiesOpen;
                            _menuOpen = false;
                            _radiusOpen = false;
                          }),
                        ),
                        const SizedBox(height: 8),
                        _HudCircle(
                          icon: Icons.navigation_rounded,
                          onTap: () => _locateGps(),
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
                    border: Border.all(color: Colors.white, width: 1.5),
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
                        _safeMove(
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
                                  Border.all(color: Colors.transparent),
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
                        if (_radiusOpen)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xF212161F),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Colors.transparent),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final km in _radiusOptions)
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      ref
                                          .read(
                                              discoveryLocationProvider.notifier)
                                          .setRadiusKm(km);
                                      _safeMove(
                                        center,
                                        _zoomForRadius(km),
                                      );
                                      setState(() => _radiusOpen = false);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '$km km',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: km == radiusKm
                                              ? const Color(0xFF00C6FF)
                                              : Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Positioned(
            top: MediaQuery.paddingOf(context).top + 56,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xF2161B27),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final layer in const [
                      ('all', 'All'),
                      ('listings', 'Listings'),
                      ('people', 'People'),
                    ])
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _layer = layer.$1;
                            _selected = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _layer == layer.$1
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            layer.$2,
                            style: GoogleFonts.plusJakartaSans(
                              color: _layer == layer.$1
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (_citiesOpen)
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.paddingOf(context).top + 104,
              bottom: MediaQuery.paddingOf(context).bottom + 120,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF212161F),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    Text(
                      'PASSPORT CITIES',
                      style: AppTheme.displayItalic.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    for (final city in PassportCities.all)
                      ListTile(
                        dense: true,
                        title: Text(
                          city.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          city.country,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        onTap: () {
                          ref.read(discoveryLocationProvider.notifier).setCoordinates(
                                city: city.name,
                                country: city.country,
                                latitude: city.lat,
                                longitude: city.lng,
                              );
                          _safeMove(
                            LatLng(city.lat, city.lng),
                            _zoomForRadius(radiusKm),
                          );
                          setState(() {
                            _citiesOpen = false;
                            _selected = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

          if (_selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 120,
              child: _PreviewCard(
                pin: _selected!,
                onOpen: () {
                  if (_selected!.isListing) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ListingDetailScreen(listingData: _selected!.listing!),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileDetailScreen(userId: _selected!.profile!.id),
                      ),
                    );
                  }
                },
                onClose: () => setState(() => _selected = null),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _locateGps() async {
    HapticFeedback.mediumImpact();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final loc = ref.read(discoveryLocationProvider);
        _safeMove(
          LatLng(loc.latitude, loc.longitude),
          _zoomForRadius(loc.radiusKm),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      ref.read(discoveryLocationProvider.notifier).setCoordinates(
            city: 'Near you',
            country: '',
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      _safeMove(
        LatLng(pos.latitude, pos.longitude),
        _zoomForRadius(ref.read(discoveryLocationProvider).radiusKm),
      );
      ref.invalidate(mapListingsProvider);
      ref.invalidate(mapProfilesProvider);
    } catch (_) {
      final loc = ref.read(discoveryLocationProvider);
      _safeMove(
        LatLng(loc.latitude, loc.longitude),
        _zoomForRadius(loc.radiusKm),
      );
    }
  }

  static bool _samePin(MapPin a, MapPin b) {
    if (a.isListing != b.isListing) return false;
    if (a.isListing) return a.listing?.id == b.listing?.id;
    return a.profile?.id == b.profile?.id;
  }

  Marker _pinMarker(MapPin pin, {required bool selected}) {
    if (pin.isListing) {
      final title = pin.listing?.title ?? 'Listing';
      final short = title.length > 18 ? '${title.substring(0, 15)}…' : title;
      return Marker(
        point: LatLng(pin.lat, pin.lng),
        width: 148,
        height: 28,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selected = pin);
          },
          child: _ListingPill(label: short, selected: selected),
        ),
      );
    }
    final name = pin.profile?.displayName ?? 'User';
    return Marker(
      point: LatLng(pin.lat, pin.lng),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selected = pin);
        },
        child: _ProfileDot(
          imageUrl: pin.profile?.avatarUrl,
          initial: name.isNotEmpty ? name[0].toUpperCase() : '?',
          selected: selected,
        ),
      ),
    );
  }

  static List<Listing> _demoListings(LatLng center, String city) {
    const photo =
        'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=800&q=80';
    const offsets = <(double, double, String, double)>[
      (0.018, -0.012, 'Tranquil Oasis', 2400),
      (-0.014, 0.016, 'Jungle Villa', 3100),
      (0.008, 0.022, 'Beach Studio', 1800),
      (-0.02, -0.018, 'Casa Azul', 2650),
    ];
    return [
      for (var i = 0; i < offsets.length; i++)
        Listing(
          id: 'map-demo-$i',
          title: offsets[i].$3,
          category: 'property',
          city: city,
          price: offsets[i].$4,
          currency: 'USD',
          latitude: center.latitude + offsets[i].$1,
          longitude: center.longitude + offsets[i].$2,
          images: const [photo],
        ),
    ];
  }
}


class MapPin {
  final bool isListing;
  final Listing? listing;
  final Profile? profile;
  final double lat;
  final double lng;

  MapPin.listing(this.listing)
      : isListing = true,
        profile = null,
        lat = listing!.latitude!,
        lng = listing.longitude!;

  MapPin.profile(this.profile)
      : isListing = false,
        listing = null,
        lat = profile!.latitude!,
        lng = profile.longitude!;
}

class _MapCluster {
  const _MapCluster({required this.point, required this.pins});
  final LatLng point;
  final List<MapPin> pins;
  int get count => pins.length;
}

class _ListingPill extends StatelessWidget {
  const _ListingPill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 0, 8, 0),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF00C6FF) : const Color(0xFF1D4ED8),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x380F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF00E5FF) : const Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : const Color(0xFF0F172A),
                fontSize: selected ? 11 : 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDot extends StatelessWidget {
  const _ProfileDot({
    required this.imageUrl,
    required this.initial,
    required this.selected,
  });

  final String? imageUrl;
  final String initial;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF312E81),
        border: Border.all(
          color: selected ? const Color(0xFFC7D2FE) : Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0x88818CF8)
                : const Color(0x590F172A),
            blurRadius: 8,
          ),
        ],
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final size = count >= 10 ? 46.0 : 38.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size + 14,
          height: size + 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x5500C6FF),
          ),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x660F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: count >= 100 ? 11 : 13,
            ),
          ),
        ),
      ],
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
    required this.pin,
    required this.onOpen,
    required this.onClose,
  });

  final MapPin pin;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = pin.isListing ? (pin.listing?.title ?? 'Listing') : pin.profile?.displayName ?? 'User';
    final subtitle = pin.isListing ? (pin.listing?.formattedLocation ?? '') : (pin.profile?.city ?? '');
    final price = pin.isListing ? (pin.listing?.formattedPrice ?? '') : (pin.profile?.role ?? '');
    final imageUrl = pin.isListing ? pin.listing?.primaryImage : pin.profile?.avatarUrl;
    
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
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover)
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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    if (price.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        price,
                        style: const TextStyle(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onOpen,
                      child: Text(
                        pin.isListing ? 'OPEN DETAILS →' : 'VIEW PROFILE →',
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
