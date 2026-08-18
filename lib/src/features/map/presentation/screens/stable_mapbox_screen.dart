import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_chips.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// The production discovery map.
///
/// Web support in Mapbox Maps Flutter 3.x is still partial. This screen never
/// lets an optional annotation API block the camera, controls, or real results.
/// The map always opens on the selected discovery location first, then each
/// visual layer is prepared independently and allowed to fail without taking
/// the rest of the experience down with it.
class StableMapboxScreen extends ConsumerStatefulWidget {
  const StableMapboxScreen({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<StableMapboxScreen> createState() =>
      _StableMapboxScreenState();
}

class _StableMapboxScreenState extends ConsumerState<StableMapboxScreen> {
  MapboxMap? _map;

  CircleAnnotationManager? _listingManager;
  CircleAnnotationManager? _peopleManager;
  CircleAnnotationManager? _locationManager;
  CircleAnnotationManager? _radiusFallbackManager;
  PolygonAnnotationManager? _radiusManager;

  MapPin? _selected;
  String _layer = 'all';
  bool _citiesOpen = false;
  bool _mapLoaded = false;
  int _annotationGeneration = 0;

  static const _darkStyle =
      'mapbox://styles/avdelag123/cmshydgsr00xz01s65m0x6u4n';
  static const _lightStyle =
      'mapbox://styles/avdelag123/cmshyf3kh00gw01s9gu3yelwz';

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;

    // Never reuse a stale empty FutureProvider result from a previous opening.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(mapListingsProvider);
      ref.invalidate(mapProfilesProvider);
    });
  }

  Point _point(double lat, double lng) =>
      Point(coordinates: Position(lng, lat));

  double _zoomForRadius(int km) {
    if (km <= 5) return 13.2;
    if (km <= 10) return 12.3;
    if (km <= 25) return 11.2;
    if (km <= 50) return 10.2;
    if (km <= 100) return 9.2;
    if (km <= 250) return 8.0;
    if (km <= 1000) return 5.8;
    if (km <= 5000) return 3.2;
    return 1.45;
  }

  double _approachZoom(int km) {
    final target = _zoomForRadius(km);
    return math.max(2.4, target - 2.6);
  }

  Future<void> _setCameraImmediate(DiscoveryLocation loc) async {
    final map = _map;
    if (map == null) return;
    try {
      await map.setCamera(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: _zoomForRadius(loc.radiusKm),
          pitch: 0,
          bearing: 0,
        ),
      );
    } catch (error) {
      debugPrint('Map camera set failed: $error');
    }
  }

  Future<void> _flyTo(DiscoveryLocation loc, {double? zoom}) async {
    final map = _map;
    if (map == null) return;
    final target = CameraOptions(
      center: _point(loc.latitude, loc.longitude),
      zoom: zoom ?? _zoomForRadius(loc.radiusKm),
      pitch: 0,
      bearing: 0,
    );

    try {
      await map.flyTo(
        target,
        MapAnimationOptions(duration: 780, startDelay: 0),
      );
    } catch (error) {
      // Camera animations are optional for correctness. If a web build cannot
      // animate, it still lands on the right place immediately.
      debugPrint('Map flyTo failed; falling back to setCamera: $error');
      await _setCameraImmediate(loc);
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    final loc = ref.read(discoveryLocationProvider);

    // Put the camera near the requested destination immediately. This is done
    // before any marker or polygon APIs are touched so annotations can never
    // leave the user stranded on the globe.
    try {
      await map.setCamera(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: _approachZoom(loc.radiusKm),
          pitch: 0,
          bearing: 0,
        ),
      );
    } catch (error) {
      debugPrint('Initial map camera failed: $error');
    }

    // Some web builds deliver map-loaded later than expected. A second camera
    // attempt makes the automatic zoom independent from that callback.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 180), () async {
        if (mounted) await _flyTo(ref.read(discoveryLocationProvider));
      }),
    );
  }

  Future<void> _onMapLoaded() async {
    _mapLoaded = true;

    // Camera first. Never await annotation setup before this line.
    await _flyTo(ref.read(discoveryLocationProvider));

    // Marker/radius APIs are best-effort and independent on web.
    unawaited(_prepareAnnotationManagers());
  }

  Future<void> _prepareAnnotationManagers() async {
    final map = _map;
    if (map == null || !_mapLoaded) return;

    try {
      _listingManager = await map.annotations.createCircleAnnotationManager();
      _listingManager?.tapEvents(
        onTap: (annotation) {
          final p = annotation.geometry.coordinates;
          _selectNearest(
            p.lat.toDouble(),
            p.lng.toDouble(),
            listingOnly: true,
          );
        },
      );
    } catch (error) {
      debugPrint('Listing annotation layer unavailable: $error');
    }

    try {
      _peopleManager = await map.annotations.createCircleAnnotationManager();
      _peopleManager?.tapEvents(
        onTap: (annotation) {
          final p = annotation.geometry.coordinates;
          _selectNearest(
            p.lat.toDouble(),
            p.lng.toDouble(),
            peopleOnly: true,
          );
        },
      );
    } catch (error) {
      debugPrint('People annotation layer unavailable: $error');
    }

    try {
      _locationManager = await map.annotations.createCircleAnnotationManager();
    } catch (error) {
      debugPrint('Location annotation layer unavailable: $error');
    }

    try {
      _radiusManager = await map.annotations.createPolygonAnnotationManager();
    } catch (error) {
      debugPrint('Polygon radius layer unavailable: $error');
    }

    // If polygon annotations are not implemented by the current web preview,
    // a large transparent circle still communicates the active search radius.
    if (_radiusManager == null) {
      try {
        _radiusFallbackManager =
            await map.annotations.createCircleAnnotationManager();
      } catch (error) {
        debugPrint('Radius fallback layer unavailable: $error');
      }
    }

    await _renderAnnotations();
  }

  ({double lat, double lng}) _spreadPoint(
    String key,
    double baseLat,
    double baseLng, {
    required bool listing,
  }) {
    var hash = listing ? 97 : 193;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final meters = 95 + ((hash ~/ 360) % 8) * 42;
    final latDelta = meters / 111320.0;
    final cosLat = math.cos(baseLat * math.pi / 180).abs();
    final lngDelta = meters / (111320.0 * (cosLat < .25 ? .25 : cosLat));
    return (
      lat: baseLat + math.sin(angle) * latDelta,
      lng: baseLng + math.cos(angle) * lngDelta,
    );
  }

  ({double lat, double lng}) _cityLevelPoint(
    String key,
    DiscoveryLocation loc, {
    required bool listing,
  }) {
    var hash = listing ? 97 : 193;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final ring = 0.008 + ((hash ~/ 360) % 7) * 0.0024;
    final lat = loc.latitude + math.sin(angle) * ring;
    final cosLat = math.cos(loc.latitude * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    final lng = loc.longitude + math.cos(angle) * ring / lngScale;
    return (lat: lat, lng: lng);
  }

  MapPin _listingPin(dynamic listing, DiscoveryLocation loc) {
    if (listing.latitude != null && listing.longitude != null) {
      final p = _spreadPoint(
        listing.id,
        listing.latitude!,
        listing.longitude!,
        listing: true,
      );
      return MapPin.listingAt(listing, p.lat, p.lng);
    }
    final p = _cityLevelPoint(listing.id, loc, listing: true);
    return MapPin.listingAt(listing, p.lat, p.lng);
  }

  MapPin _profilePin(dynamic profile, DiscoveryLocation loc) {
    if (profile.latitude != null && profile.longitude != null) {
      final p = _spreadPoint(
        profile.id,
        profile.latitude!,
        profile.longitude!,
        listing: false,
      );
      return MapPin.profileAt(profile, p.lat, p.lng);
    }
    final p = _cityLevelPoint(profile.id, loc, listing: false);
    return MapPin.profileAt(profile, p.lat, p.lng);
  }

  List<MapPin> _visiblePins() {
    final loc = ref.read(discoveryLocationProvider);
    final listings = ref.read(mapListingsProvider).value ?? const [];
    final profiles = ref.read(mapProfilesProvider).value ?? const [];
    return [
      if (_layer != 'people')
        for (final listing in listings) _listingPin(listing, loc),
      if (_layer != 'listings')
        for (final profile in profiles) _profilePin(profile, loc),
    ];
  }

  void _selectNearest(
    double lat,
    double lng, {
    bool listingOnly = false,
    bool peopleOnly = false,
  }) {
    final pins = _visiblePins();
    MapPin? best;
    var bestDistance = double.infinity;

    for (final pin in pins) {
      if (listingOnly && !pin.isListing) continue;
      if (peopleOnly && pin.isListing) continue;
      final dLat = pin.lat - lat;
      final dLng = pin.lng - lng;
      final distance = dLat * dLat + dLng * dLng;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = pin;
      }
    }

    if (best == null || !mounted) return;
    AppHaptics.selection();
    setState(() => _selected = best);
    unawaited(
      _map?.easeTo(
        CameraOptions(
          center: _point(best.lat, best.lng),
          zoom: 14.2,
          pitch: 0,
          bearing: 0,
          padding: MbxEdgeInsets(
            bottom: 128,
            left: 0,
            top: 0,
            right: 0,
          ),
        ),
        MapAnimationOptions(duration: 330, startDelay: 0),
      ) ??
          Future<void>.value(),
    );
  }

  Polygon _radiusPolygon(DiscoveryLocation loc) {
    final radius = loc.radiusKm.toDouble();
    final latDelta = radius / 111.32;
    final cosLat = math.cos(loc.latitude * math.pi / 180).abs();
    final lngDelta = radius / (111.32 * (cosLat < .25 ? .25 : cosLat));
    final ring = <Position>[];

    for (var i = 0; i <= 72; i++) {
      final angle = 2 * math.pi * i / 72;
      ring.add(
        Position(
          loc.longitude + math.cos(angle) * lngDelta,
          loc.latitude + math.sin(angle) * latDelta,
        ),
      );
    }
    return Polygon(coordinates: [ring]);
  }

  double _fallbackRadiusPixels(DiscoveryLocation loc, double zoom) {
    final cosLat = math.cos(loc.latitude * math.pi / 180).abs();
    final metersPerPixel =
        (156543.03392 * (cosLat < .1 ? .1 : cosLat)) / math.pow(2, zoom);
    final raw = (loc.radiusKm * 1000) / metersPerPixel;
    return raw.clamp(18.0, 480.0).toDouble();
  }

  Future<void> _renderAnnotations() async {
    if (!_mapLoaded) return;
    final generation = ++_annotationGeneration;
    final loc = ref.read(discoveryLocationProvider);
    final pins = _visiblePins();

    Future<void> renderListings() async {
      final manager = _listingManager;
      if (manager == null) return;
      try {
        await manager.deleteAll();
        if (!mounted || generation != _annotationGeneration) return;
        final options = <CircleAnnotationOptions>[
          for (final pin in pins)
            if (pin.isListing)
              CircleAnnotationOptions(
                geometry: _point(pin.lat, pin.lng),
                circleRadius: 8.2,
                circleColor: const Color(0xFF111318).toARGB32(),
                circleStrokeColor: Colors.white.toARGB32(),
                circleStrokeWidth: 2.4,
                circleOpacity: .98,
              ),
        ];
        if (options.isNotEmpty) await manager.createMulti(options);
      } catch (error) {
        debugPrint('Listing markers render failed: $error');
      }
    }

    Future<void> renderPeople() async {
      final manager = _peopleManager;
      if (manager == null) return;
      try {
        await manager.deleteAll();
        if (!mounted || generation != _annotationGeneration) return;
        final options = <CircleAnnotationOptions>[
          for (final pin in pins)
            if (!pin.isListing)
              CircleAnnotationOptions(
                geometry: _point(pin.lat, pin.lng),
                circleRadius: 7.5,
                circleColor: Colors.white.toARGB32(),
                circleStrokeColor: const Color(0xFF111318).toARGB32(),
                circleStrokeWidth: 2.0,
                circleOpacity: .98,
              ),
        ];
        if (options.isNotEmpty) await manager.createMulti(options);
      } catch (error) {
        debugPrint('People markers render failed: $error');
      }
    }

    Future<void> renderLocation() async {
      final manager = _locationManager;
      if (manager == null) return;
      try {
        await manager.deleteAll();
        if (!mounted || generation != _annotationGeneration) return;
        await manager.create(
          CircleAnnotationOptions(
            geometry: _point(loc.latitude, loc.longitude),
            circleRadius: 6.3,
            circleColor: const Color(0xFF147DFF).toARGB32(),
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2.6,
            circleOpacity: 1,
          ),
        );
      } catch (error) {
        debugPrint('Location marker render failed: $error');
      }
    }

    Future<void> renderRadius() async {
      final polygon = _radiusManager;
      if (polygon != null) {
        try {
          await polygon.deleteAll();
          if (!mounted || generation != _annotationGeneration) return;
          if (loc.radiusKm <= 1000) {
            await polygon.create(
              PolygonAnnotationOptions(
                geometry: _radiusPolygon(loc),
                fillColor: const Color(0xFF3B82F6).toARGB32(),
                fillOpacity: .10,
                fillOutlineColor: const Color(0xFF147DFF).toARGB32(),
              ),
            );
          }
          return;
        } catch (error) {
          debugPrint('Polygon radius render failed: $error');
        }
      }

      final fallback = _radiusFallbackManager;
      if (fallback == null || loc.radiusKm > 1000) return;
      try {
        await fallback.deleteAll();
        if (!mounted || generation != _annotationGeneration) return;
        var zoom = _zoomForRadius(loc.radiusKm);
        try {
          zoom = (await _map?.getCameraState())?.zoom ?? zoom;
        } catch (_) {}
        await fallback.create(
          CircleAnnotationOptions(
            geometry: _point(loc.latitude, loc.longitude),
            circleRadius: _fallbackRadiusPixels(loc, zoom),
            circleColor: const Color(0xFF3B82F6).toARGB32(),
            circleStrokeColor: const Color(0xFF147DFF).toARGB32(),
            circleStrokeWidth: 1.4,
            circleOpacity: .08,
          ),
        );
      } catch (error) {
        debugPrint('Fallback radius render failed: $error');
      }
    }

    await Future.wait([
      renderListings(),
      renderPeople(),
      renderLocation(),
      renderRadius(),
    ]);
  }

  void _setRange(int km) {
    AppHaptics.selection();
    ref.read(discoveryLocationProvider.notifier).setRadiusKm(km);
  }

  void _openPin(MapPin pin) {
    AppHaptics.medium();
    context.push(pin.isListing ? '/listing/${pin.id}' : '/profile/${pin.id}');
  }

  Future<void> _changeZoom(double delta) async {
    final map = _map;
    if (map == null) return;
    try {
      final camera = await map.getCameraState();
      await map.easeTo(
        CameraOptions(
          zoom: (camera.zoom + delta).clamp(1.0, 18.0).toDouble(),
          pitch: 0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 180, startDelay: 0),
      );
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 210),
          _renderAnnotations,
        ),
      );
    } catch (error) {
      debugPrint('Map zoom control failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    final listingsAsync = ref.watch(mapListingsProvider);
    final profilesAsync = ref.watch(mapProfilesProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tokenReady = AppConfig.mapboxAccessToken.trim().isNotEmpty;
    final pad = MediaQuery.paddingOf(context);

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null ||
          previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.radiusKm != next.radiusKm ||
          previous.city != next.city) {
        if (mounted) setState(() => _selected = null);
        unawaited(_flyTo(next));
        unawaited(_renderAnnotations());
      }
    });
    ref.listen(mapListingsProvider, (_, __) => unawaited(_renderAnnotations()));
    ref.listen(mapProfilesProvider, (_, __) => unawaited(_renderAnnotations()));

    if (!tokenReady) {
      return Material(
        color: const Color(0xFF0D1015),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.public_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'MAPBOX IS NOT CONFIGURED',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Build Swipess with MAPBOX_ACCESS_TOKEN so the map can load.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: widget.onClose ??
                        () => context.go(AppPaths.clientDashboard),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final listingCount = listingsAsync.value?.length ?? 0;
    final peopleCount = profilesAsync.value?.length ?? 0;
    final loading = listingsAsync.isLoading || profilesAsync.isLoading;
    final failed = listingsAsync.hasError || profilesAsync.hasError;
    final pins = <MapPin>[
      if (_layer != 'people')
        for (final listing in listingsAsync.value ?? const [])
          _listingPin(listing, loc),
      if (_layer != 'listings')
        for (final profile in profilesAsync.value ?? const [])
          _profilePin(profile, loc),
    ];

    return Material(
      color: Colors.black,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: MapWidget(
                key: const ValueKey('swipess-stable-mapbox'),
                styleUri: isLight ? _lightStyle : _darkStyle,
                cameraOptions: CameraOptions(
                  center: _point(loc.latitude, loc.longitude),
                  zoom: _approachZoom(loc.radiusKm),
                  pitch: 0,
                  bearing: 0,
                ),
                onMapCreated: _onMapCreated,
                onMapLoadedListener: (_) => _onMapLoaded(),
              ),
            ),
            if (loading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Color(0xFF60A5FA),
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
                      _MapIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: widget.onClose ??
                            () => context.go(AppPaths.clientDashboard),
                      ),
                      const SizedBox(width: 7),
                      _MapLabelButton(
                        icon: Icons.location_city_rounded,
                        label: 'CITIES',
                        selected: _citiesOpen,
                        onTap: () => setState(() {
                          _citiesOpen = !_citiesOpen;
                        }),
                      ),
                      const Spacer(),
                      _LayerPill(
                        value: _layer,
                        listingCount: listingCount,
                        peopleCount: peopleCount,
                        onChanged: (value) {
                          AppHaptics.selection();
                          setState(() {
                            _layer = value;
                            _selected = null;
                          });
                          unawaited(_renderAnnotations());
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: pad.top + 58,
              left: 12,
              child: _RangePill(
                radiusKm: loc.radiusKm,
                onLocal: () => _setRange(5),
                onRegion: () => _setRange(100),
                onWorld: () => _setRange(20000),
              ),
            ),
            if (_citiesOpen)
              Positioned(
                left: 0,
                right: 0,
                top: pad.top + 104,
                child: MapCityChips(
                  activeCity: loc.city,
                  onSelect: (city) {
                    final notifier =
                        ref.read(discoveryLocationProvider.notifier);
                    notifier.setCoordinates(
                      city: city.name,
                      country: city.country,
                      latitude: city.lat,
                      longitude: city.lng,
                    );
                    if (loc.radiusKm > 500) notifier.setRadiusKm(25);
                    setState(() => _citiesOpen = false);
                  },
                ),
              ),
            Positioned(
              right: 12,
              bottom: pad.bottom + 88,
              child: Column(
                children: [
                  _MapIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom in',
                    onTap: () => _changeZoom(1),
                  ),
                  const SizedBox(height: 7),
                  _MapIconButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom out',
                    onTap: () => _changeZoom(-1),
                  ),
                  const SizedBox(height: 7),
                  _MapIconButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Selected location',
                    onTap: () => _flyTo(loc),
                  ),
                ],
              ),
            ),
            if (_selected == null && pins.isNotEmpty)
              Positioned(
                left: 12,
                right: 62,
                bottom: pad.bottom + 18,
                child: _ResultStrip(
                  pins: pins,
                  onSelect: (pin) {
                    setState(() => _selected = pin);
                    _selectNearest(pin.lat, pin.lng,
                        listingOnly: pin.isListing,
                        peopleOnly: !pin.isListing);
                  },
                  onOpen: _openPin,
                ),
              ),
            if (_selected != null)
              Positioned(
                left: 12,
                right: 62,
                bottom: pad.bottom + 18,
                child: _SelectedCard(
                  pin: _selected!,
                  onOpen: () => _openPin(_selected!),
                  onClose: () => setState(() => _selected = null),
                ),
              ),
            if (failed)
              Positioned(
                left: 12,
                bottom: pad.bottom + 82,
                child: _RetryButton(
                  onTap: () {
                    ref.invalidate(mapListingsProvider);
                    ref.invalidate(mapProfilesProvider);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xB311141A),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withAlpha(70), width: .7),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}

class _MapLabelButton extends StatelessWidget {
  const _MapLabelButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? const Color(0xFF111318) : Colors.white;
    return Material(
      color: selected ? const Color(0xE6FFFFFF) : const Color(0xB311141A),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withAlpha(selected ? 210 : 70),
              width: .7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: foreground,
                  fontSize: 9.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.radiusKm,
    required this.onLocal,
    required this.onRegion,
    required this.onWorld,
  });

  final int radiusKm;
  final VoidCallback onLocal;
  final VoidCallback onRegion;
  final VoidCallback onWorld;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xA611141A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(54), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RangeChoice(
            label: 'LOCAL',
            active: radiusKm <= 25,
            onTap: onLocal,
          ),
          _RangeChoice(
            label: 'REGION',
            active: radiusKm > 25 && radiusKm < 5000,
            onTap: onRegion,
          ),
          _RangeChoice(
            label: 'WORLD',
            active: radiusKm >= 5000,
            onTap: onWorld,
          ),
        ],
      ),
    );
  }
}

class _RangeChoice extends StatelessWidget {
  const _RangeChoice({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white.withAlpha(42) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 8.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .55,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerPill extends StatelessWidget {
  const _LayerPill({
    required this.value,
    required this.listingCount,
    required this.peopleCount,
    required this.onChanged,
  });

  final String value;
  final int listingCount;
  final int peopleCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xB311141A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(54), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LayerChoice(
            label: 'ALL',
            active: value == 'all',
            onTap: () => onChanged('all'),
          ),
          _LayerChoice(
            label: 'LISTINGS $listingCount',
            active: value == 'listings',
            onTap: () => onChanged('listings'),
          ),
          _LayerChoice(
            label: 'USERS $peopleCount',
            active: value == 'people',
            onTap: () => onChanged('people'),
          ),
        ],
      ),
    );
  }
}

class _LayerChoice extends StatelessWidget {
  const _LayerChoice({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white.withAlpha(46) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 8.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultStrip extends StatelessWidget {
  const _ResultStrip({
    required this.pins,
    required this.onSelect,
    required this.onOpen,
  });

  final List<MapPin> pins;
  final ValueChanged<MapPin> onSelect;
  final ValueChanged<MapPin> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: pins.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final pin = pins[index];
          final title = pin.isListing
              ? (pin.listing?.title ?? 'Listing')
              : (pin.profile?.displayName ?? 'Member');
          final subtitle = pin.isListing
              ? (pin.listing?.formattedPrice ?? '')
              : (pin.profile?.city ?? 'Nearby');
          return Material(
            color: const Color(0xD911141A),
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(pin),
              onDoubleTap: () => onOpen(pin),
              child: Container(
                width: 145,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withAlpha(58),
                    width: .7,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pin.isListing
                            ? const Color(0xFF111318)
                            : Colors.white,
                        border: Border.all(
                          color: pin.isListing
                              ? Colors.white
                              : const Color(0xFF111318),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        pin.isListing
                            ? Icons.home_work_rounded
                            : Icons.person_rounded,
                        color: pin.isListing
                            ? Colors.white
                            : const Color(0xFF111318),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(165),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.pin,
    required this.onOpen,
    required this.onClose,
  });

  final MapPin pin;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = pin.isListing
        ? (pin.listing?.title ?? 'Listing')
        : (pin.profile?.displayName ?? 'Member');
    final subtitle = pin.isListing
        ? (pin.listing?.formattedLocation ?? 'Nearby listing')
        : (pin.profile?.city ?? 'Nearby member');

    return Material(
      color: const Color(0xEB11141A),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: 58,
          padding: const EdgeInsets.fromLTRB(10, 7, 5, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(64), width: .7),
          ),
          child: Row(
            children: [
              Icon(
                pin.isListing
                    ? Icons.home_work_rounded
                    : Icons.person_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(165),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withAlpha(170),
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD911141A),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 5),
              Text(
                'RETRY MAP DATA',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
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
