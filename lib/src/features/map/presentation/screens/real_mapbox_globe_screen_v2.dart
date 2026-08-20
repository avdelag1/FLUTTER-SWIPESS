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

/// Web globe renderer that deliberately avoids Mapbox AnnotationManager APIs.
///
/// Mapbox owns only the geographic/globe surface. Listings, people, current
/// location, radius and all controls are regular Flutter widgets projected from
/// geographic coordinates with [MapboxMap.pixelsForCoordinates]. This keeps the
/// real globe while avoiding the web-alpha annotation path that can abort map
/// startup and prevent both pins and the destination camera move.
class RealMapboxGlobeScreenV2 extends ConsumerStatefulWidget {
  const RealMapboxGlobeScreenV2({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<RealMapboxGlobeScreenV2> createState() =>
      _RealMapboxGlobeScreenV2State();
}

class _RealMapboxGlobeScreenV2State
    extends ConsumerState<RealMapboxGlobeScreenV2> {
  MapboxMap? _map;
  bool _mapLoaded = false;
  bool _initialBaseIdle = false;
  bool _initialFlightStarted = false;
  Timer? _initialFlightTimer;
  bool _citiesOpen = false;
  bool _chromeVisible = true;
  bool _projectionScheduled = false;
  bool _projecting = false;
  bool _projectionQueued = false;
  String _layer = 'all';
  MapPin? _selected;
  Map<String, Offset> _pinPixels = const {};
  Offset? _centerPixel;
  double? _radiusPixels;

  static const _darkStyle =
      'mapbox://styles/avdelag123/cmshydgsr00xz01s65m0x6u4n';
  static const _lightStyle =
      'mapbox://styles/avdelag123/cmshyf3kh00gw01s9gu3yelwz';

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
  }

  @override
  void dispose() {
    _initialFlightTimer?.cancel();
    super.dispose();
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

  Future<void> _setupMap(MapboxMap map) async {
    _map = map;
    await map.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(-25, 18)),
        zoom: 1.15,
        pitch: 0,
        bearing: 0,
      ),
    );
  }

  Future<void> _flyTo(
    DiscoveryLocation loc, {
    double? zoom,
    int duration = 1250,
  }) async {
    final map = _map;
    if (map == null) return;
    try {
      await map.flyTo(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: zoom ?? _zoomForRadius(loc.radiusKm),
          pitch: 0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: duration, startDelay: 0),
      );
    } catch (_) {
      // Camera movement must never be coupled to optional marker rendering.
    }
    _scheduleProjection();
  }

  void _queueInitialFlight() {
    if (!_mapLoaded ||
        !_initialBaseIdle ||
        _initialFlightStarted ||
        !mounted) {
      return;
    }

    final listings = ref.read(mapListingsProvider);
    final profiles = ref.read(mapProfilesProvider);
    if (listings.isLoading || profiles.isLoading) return;

    _initialFlightTimer?.cancel();
    _initialFlightTimer = Timer(const Duration(milliseconds: 850), () async {
      if (!mounted || _initialFlightStarted) return;
      _initialFlightStarted = true;

      // Let the real globe and the projected Flutter overlays settle before
      // beginning the flight so the opening reads like Google Earth instead of
      // an immediate camera jump.
      await _refreshProjection();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      await _flyTo(
        ref.read(discoveryLocationProvider),
        duration: 2600,
      );
    });
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
    final meters = 80 + ((hash ~/ 360) % 7) * 35;
    final latDelta = meters / 111320.0;
    final cosLat = math.cos(baseLat * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    final lngDelta = meters / (111320.0 * lngScale);
    return (
      lat: baseLat + math.sin(angle) * latDelta,
      lng: baseLng + math.cos(angle) * lngDelta,
    );
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
    final ring = 0.008 + ((hash ~/ 360) % 7) * 0.0024;
    final cosLat = math.cos(loc.latitude * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    return (
      lat: loc.latitude + math.sin(angle) * ring,
      lng: loc.longitude + math.cos(angle) * ring / lngScale,
    );
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
    final p = _cityPoint(listing.id, loc, listing: true);
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
    final p = _cityPoint(profile.id, loc, listing: false);
    return MapPin.profileAt(profile, p.lat, p.lng);
  }

  List<MapPin> _pinsFor(
    DiscoveryLocation loc,
    List<dynamic> listings,
    List<dynamic> profiles,
  ) {
    return [
      if (_layer != 'people')
        for (final listing in listings) _listingPin(listing, loc),
      if (_layer != 'listings')
        for (final profile in profiles) _profilePin(profile, loc),
    ];
  }

  String _pinKey(MapPin pin) => '${pin.isListing ? 'l' : 'p'}:${pin.id}';

  void _scheduleProjection() {
    if (!_mapLoaded || _map == null || _projectionScheduled) return;
    _projectionScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 32), () async {
      _projectionScheduled = false;
      if (!mounted) return;
      await _refreshProjection();
    });
  }

  Future<void> _refreshProjection() async {
    final map = _map;
    if (!_mapLoaded || map == null || !mounted) return;
    if (_projecting) {
      _projectionQueued = true;
      return;
    }

    _projecting = true;
    try {
      final loc = ref.read(discoveryLocationProvider);
      final listingRows = ref.read(mapListingsProvider).value ?? const [];
      final profileRows = ref.read(mapProfilesProvider).value ?? const [];
      final pins = _pinsFor(loc, listingRows, profileRows);

      final points = <Point>[
        _point(loc.latitude, loc.longitude),
        if (loc.radiusKm <= 250)
          _point(loc.latitude + loc.radiusKm / 111.32, loc.longitude),
        for (final pin in pins) _point(pin.lat, pin.lng),
      ];

      final pixels = await map.pixelsForCoordinates(points);
      if (!mounted || pixels.isEmpty) return;

      var cursor = 0;
      final centerCoordinate = pixels[cursor++];
      Offset? center;
      if (centerCoordinate != null) {
        center = Offset(centerCoordinate.x, centerCoordinate.y);
      }

      double? radius;
      if (loc.radiusKm <= 250 && cursor < pixels.length) {
        final edge = pixels[cursor++];
        if (center != null && edge != null) {
          radius = (Offset(edge.x, edge.y) - center).distance;
          if (!radius.isFinite || radius < 2 || radius > 1800) radius = null;
        }
      }

      final next = <String, Offset>{};
      for (final pin in pins) {
        if (cursor >= pixels.length) break;
        final pixel = pixels[cursor++];
        if (pixel == null) continue;
        final offset = Offset(pixel.x, pixel.y);
        if (!offset.dx.isFinite || !offset.dy.isFinite) continue;
        next[_pinKey(pin)] = offset;
      }

      setState(() {
        _pinPixels = next;
        _centerPixel = center;
        _radiusPixels = radius;
      });
    } catch (_) {
      // Projection is best-effort. A transient camera frame must not blank UI.
    } finally {
      _projecting = false;
      if (_projectionQueued && mounted) {
        _projectionQueued = false;
        _scheduleProjection();
      }
    }
  }

  bool _isSelected(MapPin pin) =>
      _selected?.id == pin.id && _selected?.isListing == pin.isListing;

  void _tapPin(MapPin pin) {
    if (_isSelected(pin)) {
      _openPin(pin);
      return;
    }
    AppHaptics.selection();
    setState(() => _selected = pin);
  }

  void _openPin(MapPin pin) {
    AppHaptics.medium();
    context.push(pin.isListing ? '/listing/${pin.id}' : '/profile/${pin.id}');
  }

  Future<void> _zoomBy(double delta) async {
    final map = _map;
    if (map == null) return;
    try {
      final camera = await map.getCameraState();
      await map.easeTo(
        CameraOptions(
          zoom: (camera.zoom + delta).clamp(1.0, 18.0).toDouble(),
        ),
        MapAnimationOptions(duration: 220, startDelay: 0),
      );
    } catch (_) {}
    _scheduleProjection();
  }

  void _setRange(int km) {
    AppHaptics.selection();
    ref.read(discoveryLocationProvider.notifier).setRadiusKm(km);
  }

  void _toggleChrome() {
    AppHaptics.selection();
    setState(() {
      _chromeVisible = !_chromeVisible;
      if (!_chromeVisible) {
        _citiesOpen = false;
        _selected = null;
      }
    });
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
      if (previous == null) return;
      final destinationChanged = previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.city != next.city;
      final radiusChanged = previous.radiusKm != next.radiusKm;
      if (!destinationChanged && !radiusChanged) return;
      _selected = null;
      if (destinationChanged) {
        if (!_initialFlightStarted) {
          _initialFlightTimer?.cancel();
          _initialFlightStarted = true;
        }
        _flyTo(next);
      } else {
        _flyTo(next, zoom: _zoomForRadius(next.radiusKm), duration: 420);
      }
      _scheduleProjection();
    });
    ref.listen(mapListingsProvider, (_, __) {
      _scheduleProjection();
      _queueInitialFlight();
    });
    ref.listen(mapProfilesProvider, (_, __) {
      _scheduleProjection();
      _queueInitialFlight();
    });

    if (!tokenReady) {
      return const Material(
        color: Color(0xFF0D1015),
        child: Center(
          child: Text(
            'MAPBOX IS NOT CONFIGURED',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    final listingRows = listingsAsync.value ?? const [];
    final profileRows = profilesAsync.value ?? const [];
    final pins = _pinsFor(loc, listingRows, profileRows);
    final loading = listingsAsync.isLoading || profilesAsync.isLoading;
    final failed = listingsAsync.hasError || profilesAsync.hasError;

    return Material(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool onScreen(Offset p, {double margin = 80}) =>
              p.dx >= -margin &&
              p.dy >= -margin &&
              p.dx <= constraints.maxWidth + margin &&
              p.dy <= constraints.maxHeight + margin;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey('swipess-globe-projected-v2'),
                  styleUri: isLight ? _lightStyle : _darkStyle,
                  onMapCreated: _setupMap,
                  onMapLoadedListener: (_) {
                    _mapLoaded = true;
                    _scheduleProjection();
                    _queueInitialFlight();
                  },
                  onCameraChangeListener: (_) => _scheduleProjection(),
                  onMapIdleListener: (_) {
                    _scheduleProjection();
                    if (!_initialFlightStarted) {
                      _initialBaseIdle = true;
                      _queueInitialFlight();
                    }
                  },
                ),
              ),

              // Radius is projected into Flutter instead of using Mapbox web
              // annotations. At local zoom/pitch 0 this remains geographically
              // aligned and cannot block map gestures.
              if (_centerPixel != null &&
                  _radiusPixels != null &&
                  _radiusPixels! > 2 &&
                  onScreen(_centerPixel!, margin: _radiusPixels!))
                Positioned(
                  left: _centerPixel!.dx - _radiusPixels!,
                  top: _centerPixel!.dy - _radiusPixels!,
                  child: IgnorePointer(
                    child: Container(
                      width: _radiusPixels! * 2,
                      height: _radiusPixels! * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x123B82F6),
                        border: Border.all(
                          color: const Color(0xCC147DFF),
                          width: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),

              if (_centerPixel != null && onScreen(_centerPixel!))
                Positioned(
                  left: _centerPixel!.dx - 9,
                  top: _centerPixel!.dy - 9,
                  child: const IgnorePointer(child: _CurrentLocationDot()),
                ),

              for (final pin in pins)
                if (_pinPixels[_pinKey(pin)] case final Offset pixel)
                  if (onScreen(pixel, margin: 110)) ...[
                    Positioned(
                      left: pixel.dx - 62,
                      top: pixel.dy - 74,
                      child: _ProjectedPin(
                        pin: pin,
                        selected: _isSelected(pin),
                        onTap: () => _tapPin(pin),
                      ),
                    ),
                    if (_isSelected(pin) && _chromeVisible)
                      Positioned(
                        left: (pixel.dx - 118)
                            .clamp(8.0, math.max(8.0, constraints.maxWidth - 244))
                            .toDouble(),
                        top: math.max(8, pixel.dy - 134).toDouble(),
                        child: _PinPreview(
                          pin: pin,
                          onOpen: () => _openPin(pin),
                          onClose: () => setState(() => _selected = null),
                        ),
                      ),
                  ],

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

              if (_chromeVisible) ...[
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MapCircleButton(
                            semanticLabel: 'Close map',
                            icon: Icons.close_rounded,
                            onTap: widget.onClose ??
                                () => context.go(AppPaths.clientDashboard),
                          ),
                          const SizedBox(width: 7),
                          _CityButton(
                            selected: _citiesOpen,
                            onTap: () =>
                                setState(() => _citiesOpen = !_citiesOpen),
                          ),
                          const Spacer(),
                          _CountsPill(
                            layer: _layer,
                            listings: listingRows.length,
                            users: profileRows.length,
                            onLayer: (value) {
                              AppHaptics.selection();
                              setState(() {
                                _layer = value;
                                _selected = null;
                              });
                              _scheduleProjection();
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
                    right: 76,
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
                if (failed)
                  Positioned(
                    left: 12,
                    bottom: pad.bottom + 18,
                    child: _RetryButton(
                      onTap: () {
                        ref.invalidate(mapListingsProvider);
                        ref.invalidate(mapProfilesProvider);
                      },
                    ),
                  ),
              ],

              Positioned(
                right: 12,
                bottom: pad.bottom + 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_chromeVisible) ...[
                      _MapCircleButton(
                        semanticLabel: 'Zoom in',
                        glyph: '+',
                        icon: Icons.add,
                        onTap: () => _zoomBy(1),
                      ),
                      const SizedBox(height: 8),
                      _MapCircleButton(
                        semanticLabel: 'Zoom out',
                        glyph: '−',
                        icon: Icons.remove,
                        onTap: () => _zoomBy(-1),
                      ),
                      const SizedBox(height: 8),
                      _MapCircleButton(
                        semanticLabel: 'Recenter',
                        icon: Icons.my_location_rounded,
                        onTap: () => _flyTo(
                          loc,
                          zoom: _zoomForRadius(loc.radiusKm),
                          duration: 420,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _MapCircleButton(
                      semanticLabel:
                          _chromeVisible ? 'Hide controls' : 'Show controls',
                      icon: _chromeVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      onTap: _toggleChrome,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFF147DFF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 8),
        ],
      ),
    );
  }
}

class _ProjectedPin extends StatelessWidget {
  const _ProjectedPin({
    required this.pin,
    required this.selected,
    required this.onTap,
  });

  final MapPin pin;
  final bool selected;
  final VoidCallback onTap;

  static const _accentPalette = <Color>[
    Color(0xFF5B8CFF),
    Color(0xFFFF7289),
    Color(0xFFFFB34D),
    Color(0xFF43C7A1),
    Color(0xFF9A7BFF),
    Color(0xFF35B9D8),
  ];

  Color _accentForPin() {
    var hash = pin.isListing ? 131 : 271;
    for (final unit in pin.id.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    return _accentPalette[hash % _accentPalette.length];
  }

  String _label() {
    final raw = pin.isListing
        ? (pin.listing?.formattedPrice ?? 'Listing')
        : (pin.profile?.displayName ?? 'Member');
    final clean = raw.trim().isEmpty ? (pin.isListing ? 'Listing' : 'Member') : raw.trim();
    if (clean.length <= 17) return clean;
    return '${clean.substring(0, 15)}…';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForPin();
    final fill = pin.isListing
        ? Color.alphaBlend(accent.withAlpha(86), const Color(0xFF111318))
        : Color.alphaBlend(accent.withAlpha(22), Colors.white);
    final markerSize = selected ? 52.0 : 48.0;
    final label = _label();

    return Semantics(
      button: true,
      label: pin.isListing ? 'Listing $label' : 'User $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          hoverColor: Colors.transparent,
          onTap: onTap,
          child: SizedBox(
            width: 124,
            height: 74,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  constraints: const BoxConstraints(maxWidth: 118),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xF211141A)
                        : const Color(0xEFFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? Colors.white : accent.withAlpha(210),
                      width: selected ? 1.4 : 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x48000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: selected ? Colors.white : const Color(0xFF111318),
                      fontSize: pin.isListing ? 10.2 : 9.6,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.1,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: markerSize,
                  height: markerSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: Border.all(
                      color: selected ? Colors.white : accent,
                      width: selected ? 3.2 : 2.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withAlpha(selected ? 145 : 82),
                        blurRadius: selected ? 18 : 12,
                        spreadRadius: selected ? 1.4 : .4,
                      ),
                      const BoxShadow(
                        color: Color(0x52000000),
                        blurRadius: 11,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    pin.isListing ? Icons.home_work_rounded : Icons.person_rounded,
                    size: selected ? 23 : 21,
                    color: pin.isListing ? Colors.white : accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPreview extends StatelessWidget {
  const _PinPreview({
    required this.pin,
    required this.onOpen,
    required this.onClose,
  });

  final MapPin pin;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final listing = pin.listing;
    final profile = pin.profile;
    final image = pin.isListing ? listing?.primaryImage : profile?.avatarUrl;
    final title = pin.isListing
        ? (listing?.title ?? 'Listing')
        : (profile?.displayName ?? 'Member');
    final headline = pin.isListing
        ? (listing?.formattedPrice ?? 'Price TBD')
        : (profile?.role?.trim().isNotEmpty == true
              ? profile!.role!
              : 'Swipess member');
    final detail = pin.isListing
        ? _listingDetail(pin)
        : _profileDetail(pin);

    return Material(
      color: const Color(0xF511141A),
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 236,
        height: 88,
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                hoverColor: Colors.transparent,
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 30, 8),
                  child: Row(
                    children: [
                      _PreviewImage(url: image, listing: pin.isListing),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    headline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: pin.isListing ? 13.2 : 10.3,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (!pin.isListing && profile?.verified == true)
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF60A5FA),
                                    size: 14,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(232),
                                fontSize: 10.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (detail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withAlpha(160),
                                  fontSize: 8.6,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 5,
              right: 5,
              child: Material(
                color: Colors.white.withAlpha(18),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  hoverColor: Colors.transparent,
                  onTap: onClose,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _listingDetail(MapPin pin) {
    final listing = pin.listing;
    if (listing == null) return '';
    final tags = listing.quickTags.take(2).toList();
    if (tags.isNotEmpty) return tags.join(' · ');
    return listing.formattedLocation;
  }

  static String _profileDetail(MapPin pin) {
    final profile = pin.profile;
    if (profile == null) return '';
    final city = profile.city?.trim() ?? '';
    final bio = profile.bio?.trim() ?? '';
    if (city.isNotEmpty && bio.isNotEmpty) return '$city · $bio';
    if (city.isNotEmpty) return city;
    return bio;
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url, required this.listing});

  final String? url;
  final bool listing;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF252A33),
      alignment: Alignment.center,
      child: Icon(
        listing ? Icons.home_work_rounded : Icons.person_rounded,
        color: Colors.white.withAlpha(210),
        size: 22,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: 60,
        height: 60,
        child: url == null || url!.trim().isEmpty
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    this.glyph,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    final child = glyph == null
        ? Icon(icon, color: Colors.white, size: 19)
        : Text(
            glyph!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: .95,
              fontWeight: FontWeight.w500,
            ),
          );

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: const Color(0xD511141A),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withAlpha(70), width: .7),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          hoverColor: Colors.transparent,
          focusColor: Colors.white.withAlpha(10),
          splashColor: Colors.white.withAlpha(24),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _CityButton extends StatelessWidget {
  const _CityButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? const Color(0xFF111318) : Colors.white;
    return Material(
      color: selected ? const Color(0xEFFFFFFF) : const Color(0xD511141A),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        hoverColor: Colors.transparent,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(70), width: .7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_city_rounded, color: fg, size: 15),
              const SizedBox(width: 5),
              Text(
                'CITIES',
                style: GoogleFonts.plusJakartaSans(
                  color: fg,
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

class _CountsPill extends StatelessWidget {
  const _CountsPill({
    required this.layer,
    required this.listings,
    required this.users,
    required this.onLayer,
  });

  final String layer;
  final int listings;
  final int users;
  final ValueChanged<String> onLayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xD511141A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(54), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Choice(label: 'ALL', active: layer == 'all', onTap: () => onLayer('all')),
          _Choice(
            label: 'LISTINGS $listings',
            active: layer == 'listings',
            onTap: () => onLayer('listings'),
          ),
          _Choice(
            label: 'USERS $users',
            active: layer == 'people',
            onTap: () => onLayer('people'),
          ),
        ],
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
        color: const Color(0xD511141A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(54), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Choice(label: 'LOCAL', active: radiusKm <= 25, onTap: onLocal),
          _Choice(
            label: 'REGION',
            active: radiusKm > 25 && radiusKm < 5000,
            onTap: onRegion,
          ),
          _Choice(
            label: 'WORLD',
            active: radiusKm >= 5000,
            onTap: onWorld,
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
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
      color: active ? Colors.white.withAlpha(44) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        hoverColor: Colors.transparent,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 8.2,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
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
      color: const Color(0xE611141A),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        hoverColor: Colors.transparent,
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
