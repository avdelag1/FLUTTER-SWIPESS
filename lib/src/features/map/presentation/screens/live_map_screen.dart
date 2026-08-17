import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/data/map_basemap.dart';
import 'package:flutter_swipes/src/features/map/data/map_camera.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_sheet.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_gps_dot.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_pin_markers.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_preview_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

/// Full-screen discovery map.
/// Opens from a world view and performs one clean fly-in to the selected
/// location/radius. Listings and members are always rendered when their
/// registered city matches, even when an exact GPS coordinate is unavailable.
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
  final MapController _mapController = MapController();
  late final AnimationController _fly;

  String _layer = 'all'; // all | listings | people
  MapPin? _selected;
  bool _citiesOpen = false;
  bool _radiusOpen = false;
  bool _mapReady = false;
  bool _initialFlyDone = false;
  double _zoom = MapCameraMath.globeAltitudeZoom;

  static const _radiusOptions = [5, 10, 25, 50, 100, 200];

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
  }

  @override
  void dispose() {
    _fly.dispose();
    _mapController.dispose();
    super.dispose();
  }

  double _zoomForRadius(int km) => MapCameraMath.zoomForRadiusKm(km);

  void _move(LatLng center, double zoom) {
    if (!_mapReady) return;
    try {
      _mapController.move(center, zoom);
    } catch (_) {}
  }

  void _flyTo(LatLng center, int radiusKm, {bool worldFirst = false}) {
    if (!_mapReady) return;
    _fly.stop();
    _fly.reset();
    final startZoom = worldFirst ? MapCameraMath.globeAltitudeZoom : _zoom;
    final targetZoom = _zoomForRadius(radiusKm);
    _move(center, startZoom);

    void tick() {
      if (!_mapReady) return;
      final t = Curves.easeInOutCubicEmphasized.transform(_fly.value);
      final z = startZoom + (targetZoom - startZoom) * t;
      _move(center, z);
      _zoom = z;
      if (_fly.isCompleted) _fly.removeListener(tick);
    }

    _fly.addListener(tick);
    _fly.forward(from: 0);
  }

  ({double lat, double lng}) _cityPoint(
    String key,
    DiscoveryLocation loc, {
    required bool listing,
  }) {
    var hash = listing ? 97 : 193;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final ring = 0.0045 + ((hash ~/ 360) % 8) * 0.0018;
    final lat = loc.latitude + math.sin(angle) * ring;
    final cosLat = math.cos(loc.latitude * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    final lng = loc.longitude + math.cos(angle) * ring / lngScale;
    return (lat: lat, lng: lng);
  }

  MapPin _listingPin(dynamic listing, DiscoveryLocation loc) {
    if (listing.latitude != null && listing.longitude != null) {
      return MapPin.listing(listing);
    }
    final p = _cityPoint(listing.id, loc, listing: true);
    return MapPin.listingAt(listing, p.lat, p.lng);
  }

  MapPin _profilePin(dynamic profile, DiscoveryLocation loc) {
    if (profile.latitude != null && profile.longitude != null) {
      return MapPin.profile(profile);
    }
    final p = _cityPoint(profile.id, loc, listing: false);
    return MapPin.profileAt(profile, p.lat, p.lng);
  }

  List<MapPin> _pins(
    DiscoveryLocation loc,
    AsyncValue<List<dynamic>> listingsAsync,
    AsyncValue<List<dynamic>> profilesAsync,
  ) {
    final listings = listingsAsync.value ?? const [];
    final profiles = profilesAsync.value ?? const [];
    return [
      if (_layer != 'people')
        for (final listing in listings) _listingPin(listing, loc),
      if (_layer != 'listings')
        for (final profile in profiles) _profilePin(profile, loc),
    ];
  }

  void _openSelected() {
    final pin = _selected;
    if (pin == null) return;
    AppHaptics.medium();
    context.push(pin.isListing ? '/listing/${pin.id}' : '/profile/${pin.id}');
  }

  Future<void> _locateGps() async {
    AppHaptics.medium();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final loc = ref.read(discoveryLocationProvider);
        _flyTo(LatLng(loc.latitude, loc.longitude), loc.radiusKm);
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
      final radius = ref.read(discoveryLocationProvider).radiusKm;
      _flyTo(LatLng(pos.latitude, pos.longitude), radius);
      ref.invalidate(mapListingsProvider);
      ref.invalidate(mapProfilesProvider);
    } catch (_) {
      final loc = ref.read(discoveryLocationProvider);
      _flyTo(LatLng(loc.latitude, loc.longitude), loc.radiusKm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    final listingsRaw = ref.watch(mapListingsProvider);
    final profilesRaw = ref.watch(mapProfilesProvider);
    final isLight = ref.watch(isLightThemeProvider);
    final center = LatLng(loc.latitude, loc.longitude);

    // Keep strong types locally while allowing the common pin builder above.
    final listingsAsync = listingsRaw as AsyncValue<List<dynamic>>;
    final profilesAsync = profilesRaw as AsyncValue<List<dynamic>>;
    final pins = _pins(loc, listingsAsync, profilesAsync);
    final listingCount = listingsRaw.value?.length ?? 0;
    final peopleCount = profilesRaw.value?.length ?? 0;
    final loading = listingsRaw.isLoading || profilesRaw.isLoading;
    final pad = MediaQuery.paddingOf(context);

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null) return;
      if (previous.latitude == next.latitude &&
          previous.longitude == next.longitude &&
          previous.radiusKm == next.radiusKm &&
          previous.city == next.city) {
        return;
      }
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _flyTo(LatLng(next.latitude, next.longitude), next.radiusKm);
      });
    });

    return Material(
      color: MapBasemap.canvas,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: MapCameraMath.globeAltitudeZoom,
                minZoom: 2.5,
                maxZoom: 18,
                backgroundColor: MapBasemap.canvas,
                onMapReady: () {
                  _mapReady = true;
                  if (!_initialFlyDone) {
                    _initialFlyDone = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _flyTo(center, loc.radiusKm, worldFirst: true);
                    });
                  }
                },
                onTap: (_, _) => setState(() {
                  _selected = null;
                  _radiusOpen = false;
                }),
                onPositionChanged: (position, _) {
                  if (!_fly.isAnimating) _zoom = position.zoom;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapBasemap.urlTemplate(isLight),
                  subdomains: MapBasemap.subdomains,
                  additionalOptions: MapBasemap.additionalOptions,
                  userAgentPackageName: MapBasemap.userAgentPackageName,
                  tileDimension: 256,
                  maxNativeZoom: 19,
                  keepBuffer: 4,
                  panBuffer: 2,
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: loc.radiusKm * 1000,
                      useRadiusInMeter: true,
                      color: const Color(0x293B82F6),
                      borderColor: const Color(0xFF3B82F6),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const MapGpsDot(),
                    ),
                    for (final pin in pins) _pinMarker(pin),
                  ],
                ),
              ],
            ),
            if (loading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: Color(0xFF3B82F6),
                  backgroundColor: Colors.transparent,
                ),
              ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GlassButton(
                        icon: Icons.close_rounded,
                        label: 'CLOSE',
                        onTap: widget.onClose ?? () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      _GlassButton(
                        icon: Icons.location_city_rounded,
                        label: 'CITIES',
                        selected: _citiesOpen,
                        onTap: () => setState(() {
                          _citiesOpen = !_citiesOpen;
                          _radiusOpen = false;
                        }),
                      ),
                      const Spacer(),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            children: [
                              _LayerButton(
                                icon: Icons.layers_rounded,
                                label: 'ALL',
                                active: _layer == 'all',
                                onTap: () => setState(() {
                                  _layer = 'all';
                                  _selected = null;
                                }),
                              ),
                              const SizedBox(width: 6),
                              _LayerButton(
                                icon: Icons.home_work_rounded,
                                label: 'LISTINGS $listingCount',
                                active: _layer == 'listings',
                                onTap: () => setState(() {
                                  _layer = 'listings';
                                  _selected = null;
                                }),
                              ),
                              const SizedBox(width: 6),
                              _LayerButton(
                                icon: Icons.people_alt_rounded,
                                label: 'USERS $peopleCount',
                                active: _layer == 'people',
                                onTap: () => setState(() {
                                  _layer = 'people';
                                  _selected = null;
                                }),
                              ),
                            ],
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
                top: pad.top + 62,
                left: 12,
                right: 12,
                bottom: pad.bottom + 22,
                child: MapCitySheet(
                  onClose: () => setState(() => _citiesOpen = false),
                  onPick: (city) {
                    ref.read(discoveryLocationProvider.notifier).setCoordinates(
                          city: city.name,
                          country: city.country,
                          latitude: city.lat,
                          longitude: city.lng,
                        );
                    setState(() {
                      _citiesOpen = false;
                      _selected = null;
                    });
                    _flyTo(LatLng(city.lat, city.lng), loc.radiusKm);
                  },
                ),
              ),

            Positioned(
              right: 12,
              bottom: pad.bottom + 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_radiusOpen)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xE611141A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          for (final km in _radiusOptions)
                            _RadiusChoice(
                              km: km,
                              active: km == loc.radiusKm,
                              onTap: () {
                                ref
                                    .read(discoveryLocationProvider.notifier)
                                    .setRadiusKm(km);
                                setState(() => _radiusOpen = false);
                                _flyTo(center, km);
                              },
                            ),
                        ],
                      ),
                    ),
                  _GlassButton(
                    icon: Icons.radar_rounded,
                    label: '${loc.radiusKm} KM',
                    selected: _radiusOpen,
                    onTap: () => setState(() => _radiusOpen = !_radiusOpen),
                  ),
                  const SizedBox(height: 8),
                  _GlassButton(
                    icon: Icons.my_location_rounded,
                    label: 'ME',
                    onTap: _locateGps,
                  ),
                ],
              ),
            ),

            if (_selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: pad.bottom + 18,
                child: MapPreviewCard(
                  pin: _selected!,
                  onOpen: _openSelected,
                  onClose: () => setState(() => _selected = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _pinMarker(MapPin pin) {
    final selected = _selected?.id == pin.id &&
        _selected?.isListing == pin.isListing;
    if (pin.isListing) {
      return Marker(
        point: LatLng(pin.lat, pin.lng),
        width: MapListingPinMarker.width,
        height: MapListingPinMarker.height,
        alignment: MapListingPinMarker.anchor,
        child: GestureDetector(
          onTap: () {
            AppHaptics.selection();
            setState(() => _selected = pin);
          },
          child: MapListingPinMarker(
            title: pin.listing?.title ?? 'Listing',
            imageUrl: pin.listing?.primaryImage,
            selected: selected,
          ),
        ),
      );
    }
    return Marker(
      point: LatLng(pin.lat, pin.lng),
      width: 44,
      height: 44,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          setState(() => _selected = pin);
        },
        child: MapProfilePinMarker(
          imageUrl: pin.profile?.avatarUrl,
          selected: selected,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xE6FFFFFF)
                : const Color(0xA611141A),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.white : Colors.white38,
              width: .8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? const Color(0xFF111318) : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: selected ? const Color(0xFF111318) : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerButton extends StatelessWidget {
  const _LayerButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xE6FFFFFF) : const Color(0xA611141A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white38, width: .8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? const Color(0xFF111318) : Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: active ? const Color(0xFF111318) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 8.5,
                letterSpacing: .35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadiusChoice extends StatelessWidget {
  const _RadiusChoice({
    required this.km,
    required this.active,
    required this.onTap,
  });

  final int km;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.radar_rounded,
              size: 14,
              color: active ? const Color(0xFF60A5FA) : Colors.white70,
            ),
            const SizedBox(width: 7),
            Text(
              '$km km',
              style: GoogleFonts.plusJakartaSans(
                color: active ? const Color(0xFF60A5FA) : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
