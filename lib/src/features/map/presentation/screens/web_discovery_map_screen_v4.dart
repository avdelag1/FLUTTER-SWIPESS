import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/data/map_basemap.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_chips.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Browser discovery map.
///
/// This deliberately keeps the entire interactive map in Flutter's render tree.
/// No browser platform-view is mounted over the controls, and map controls do
/// not create hover Tooltips/OverlayEntries. That keeps Chrome hit-testing and
/// compositing stable while still allowing a cinematic, angled arrival.
class WebDiscoveryMapScreenV4 extends ConsumerStatefulWidget {
  const WebDiscoveryMapScreenV4({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<WebDiscoveryMapScreenV4> createState() =>
      _WebDiscoveryMapScreenV4State();
}

class _WebDiscoveryMapScreenV4State
    extends ConsumerState<WebDiscoveryMapScreenV4>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _flight;

  bool _mapReady = false;
  bool _citiesOpen = false;
  bool _chromeVisible = true;
  bool _flightRunning = false;
  String _layer = 'all';
  MapPin? _selected;
  double _zoom = 11.2;

  double _fromLat = 0;
  double _fromLng = 0;
  double _toLat = 0;
  double _toLng = 0;
  double _fromZoom = 2.05;
  double _toZoom = 11.2;

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    _flight =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 3400),
          )
          ..addListener(_onFlightTick)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _flightRunning = false);
            }
          });

    // Do not invalidate map providers here. They are deliberately kept warm by
    // the dashboard so opening the map can reuse already-fetched data.
  }

  @override
  void dispose() {
    _flight
      ..removeListener(_onFlightTick)
      ..dispose();
    _mapController.dispose();
    super.dispose();
  }

  double _zoomForRadius(int km) {
    if (km <= 5) return 13.2;
    if (km <= 10) return 12.3;
    if (km <= 25) return 11.2;
    if (km <= 50) return 10.2;
    if (km <= 100) return 9.2;
    if (km <= 250) return 8.0;
    if (km <= 1000) return 5.8;
    if (km <= 5000) return 3.2;
    return 2.2;
  }

  double _wrapLng(double value) {
    var v = value;
    while (v > 180) v -= 360;
    while (v < -180) v += 360;
    return v;
  }

  double _shortestLngDelta(double from, double to) {
    var d = to - from;
    while (d > 180) d -= 360;
    while (d < -180) d += 360;
    return d;
  }

  void _onFlightTick() {
    if (!_mapReady) return;

    final raw = _flight.value;
    final travelT = Curves.easeInOutCubic.transform(raw);
    final zoomRaw = ((raw - .10) / .90).clamp(0.0, 1.0);
    final zoomT = Curves.easeInOutCubic.transform(zoomRaw);

    final lat = _fromLat + (_toLat - _fromLat) * travelT;
    final lng = _wrapLng(
      _fromLng + _shortestLngDelta(_fromLng, _toLng) * travelT,
    );
    final zoom = _fromZoom + (_toZoom - _fromZoom) * zoomT;

    // A gentle world turn at the beginning makes the arrival feel like travel,
    // not a camera falling vertically onto a coordinate.
    final rotation = -24.0 * (1 - travelT) + math.sin(math.pi * raw) * 5.0;

    try {
      _mapController.moveAndRotate(LatLng(lat, lng), zoom, rotation);
      _zoom = zoom;
    } catch (_) {}
  }

  void _startFlight(DiscoveryLocation loc) {
    if (!_mapReady) return;
    _selected = null;
    _flight.stop();

    // Approach from behind and to the west/south of the destination so Tulum,
    // Bali, China, Ibiza, etc. all feel like a diagonal flight rather than a
    // straight-down bomb-drop.
    _fromLat = (loc.latitude - 22).clamp(-58.0, 58.0).toDouble();
    _fromLng = _wrapLng(loc.longitude - 74);
    _toLat = loc.latitude;
    _toLng = loc.longitude;
    _fromZoom = 2.05;
    _toZoom = _zoomForRadius(loc.radiusKm);

    try {
      _mapController.moveAndRotate(LatLng(_fromLat, _fromLng), _fromZoom, -24);
    } catch (_) {}

    if (mounted) setState(() => _flightRunning = true);
    _flight.forward(from: 0);
  }

  void _move(double latitude, double longitude, double zoom) {
    if (!_mapReady) return;
    _flight.stop();
    if (_flightRunning && mounted) setState(() => _flightRunning = false);
    final safeZoom = zoom.clamp(2.0, 18.0).toDouble();
    try {
      _mapController.moveAndRotate(LatLng(latitude, longitude), safeZoom, 0);
      _zoom = safeZoom;
    } catch (_) {}
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    try {
      final center = _mapController.camera.center;
      _move(
        center.latitude,
        center.longitude,
        (_zoom + delta).clamp(2.0, 18.0).toDouble(),
      );
    } catch (_) {}
  }

  ({double lat, double lng}) _spreadExact(
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
    final meters = 90 + ((hash ~/ 360) % 8) * 38;
    final latDelta = meters / 111320.0;
    final cosLat = math.cos(baseLat * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    final lngDelta = meters / (111320.0 * lngScale);
    return (
      lat: baseLat + math.sin(angle) * latDelta,
      lng: baseLng + math.cos(angle) * lngDelta,
    );
  }

  ({double lat, double lng}) _spreadCity(
    String key,
    double centerLat,
    double centerLng, {
    required bool listing,
  }) {
    var hash = listing ? 97 : 193;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final ring = 0.008 + ((hash ~/ 360) % 7) * 0.0024;
    final cosLat = math.cos(centerLat * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    return (
      lat: centerLat + math.sin(angle) * ring,
      lng: centerLng + math.cos(angle) * ring / lngScale,
    );
  }

  MapPin _listingPin(dynamic listing, DiscoveryLocation loc) {
    if (listing.latitude != null && listing.longitude != null) {
      final p = _spreadExact(
        listing.id,
        listing.latitude!,
        listing.longitude!,
        listing: true,
      );
      return MapPin.listingAt(listing, p.lat, p.lng);
    }
    final p = _spreadCity(
      listing.id,
      loc.latitude,
      loc.longitude,
      listing: true,
    );
    return MapPin.listingAt(listing, p.lat, p.lng);
  }

  MapPin _profilePin(dynamic profile, DiscoveryLocation loc) {
    if (profile.latitude != null && profile.longitude != null) {
      final p = _spreadExact(
        profile.id,
        profile.latitude!,
        profile.longitude!,
        listing: false,
      );
      return MapPin.profileAt(profile, p.lat, p.lng);
    }
    final p = _spreadCity(
      profile.id,
      loc.latitude,
      loc.longitude,
      listing: false,
    );
    return MapPin.profileAt(profile, p.lat, p.lng);
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
    if (_mapReady) {
      try {
        _mapController.move(
          LatLng(pin.lat, pin.lng),
          math.max(_zoom, 13.0).toDouble(),
          offset: const Offset(0, 86),
        );
        _zoom = math.max(_zoom, 13.0).toDouble();
      } catch (_) {}
    }
  }

  void _openPin(MapPin pin) {
    AppHaptics.medium();
    context.push(pin.isListing ? '/listing/${pin.id}' : '/profile/${pin.id}');
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
    final pad = MediaQuery.paddingOf(context);
    final targetZoom = _zoomForRadius(loc.radiusKm);

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null) return;
      final destinationChanged =
          previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.city != next.city;
      final radiusChanged = previous.radiusKm != next.radiusKm;
      if (!destinationChanged && !radiusChanged) return;
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) return;
        if (destinationChanged) {
          _startFlight(next);
        } else {
          _move(next.latitude, next.longitude, _zoomForRadius(next.radiusKm));
        }
      });
    });

    final listingRows = listingsAsync.value ?? const [];
    final profileRows = profilesAsync.value ?? const [];
    final pins = <MapPin>[
      if (_layer != 'people')
        for (final listing in listingRows) _listingPin(listing, loc),
      if (_layer != 'listings')
        for (final profile in profileRows) _profilePin(profile, loc),
    ];

    final center = LatLng(loc.latitude, loc.longitude);
    final loading = listingsAsync.isLoading || profilesAsync.isLoading;
    final failed = listingsAsync.hasError || profilesAsync.hasError;

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(
          (loc.latitude - 22).clamp(-58.0, 58.0).toDouble(),
          _wrapLng(loc.longitude - 74),
        ),
        initialZoom: 2.05,
        initialRotation: -24,
        minZoom: 2,
        maxZoom: 18,
        backgroundColor: MapBasemap.canvas,
        onMapReady: () {
          _mapReady = true;
          _zoom = 2.05;
          // Give the first world tiles a fraction of a second to paint before
          // the flight begins. The user sees a composed world, not a blank zoom.
          Future<void>.delayed(const Duration(milliseconds: 420), () {
            if (mounted) _startFlight(loc);
          });
        },
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) {
            _flight.stop();
            _zoom = camera.zoom;
            if (_flightRunning && mounted) {
              setState(() => _flightRunning = false);
            }
          }
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
          keepBuffer: 5,
          panBuffer: 3,
        ),
        if (loc.radiusKm <= 1000)
          CircleLayer(
            circles: [
              CircleMarker(
                point: center,
                radius: loc.radiusKm * 1000.0,
                useRadiusInMeter: true,
                color: const Color(0x123B82F6),
                borderColor: const Color(0xC8147DFF),
                borderStrokeWidth: 1.35,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 28,
              height: 28,
              rotate: true,
              child: const IgnorePointer(child: _CenterDot()),
            ),
            for (final pin in pins)
              Marker(
                point: LatLng(pin.lat, pin.lng),
                width: _isSelected(pin) && _chromeVisible ? 252 : 48,
                height: _isSelected(pin) && _chromeVisible ? 146 : 48,
                rotate: true,
                alignment: _isSelected(pin) && _chromeVisible
                    ? Alignment.bottomCenter
                    : Alignment.center,
                child: _MapMarker(
                  pin: pin,
                  selected: _isSelected(pin),
                  showPreview: _isSelected(pin) && _chromeVisible,
                  onTap: () => _tapPin(pin),
                  onOpen: () => _openPin(pin),
                  onClose: () => setState(() => _selected = null),
                ),
              ),
          ],
        ),
      ],
    );

    return Material(
      color: MapBasemap.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A noticeably stronger but still usable drone/bird angle. Tooltips
          // are not allowed above this transformed layer, which prevents the
          // gray Chrome compositor wash that the previous build showed.
          Transform.scale(
            scale: 1.14,
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .00105)
                  ..rotateX(.43),
                child: map,
              ),
            ),
          ),
          if (_flightRunning)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Colors.black.withAlpha(30), Colors.transparent],
                  ),
                ),
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
          if (_chromeVisible) ...[
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CircleButton(
                        icon: Icons.close_rounded,
                        semanticLabel: 'Close map',
                        onTap:
                            widget.onClose ??
                            () => context.go(AppPaths.clientDashboard),
                      ),
                      const SizedBox(width: 7),
                      _LabelButton(
                        label: 'CITIES',
                        selected: _citiesOpen,
                        onTap: () => setState(() => _citiesOpen = !_citiesOpen),
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
                    final notifier = ref.read(
                      discoveryLocationProvider.notifier,
                    );
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
                  _CircleButton(
                    icon: Icons.add_rounded,
                    semanticLabel: 'Zoom in',
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _CircleButton(
                    icon: Icons.remove,
                    glyph: '−',
                    semanticLabel: 'Zoom out',
                    onTap: () => _zoomBy(-1),
                  ),
                  const SizedBox(height: 8),
                  _CircleButton(
                    icon: Icons.my_location_rounded,
                    semanticLabel: 'Recenter',
                    onTap: () => _move(loc.latitude, loc.longitude, targetZoom),
                  ),
                  const SizedBox(height: 8),
                ],
                _CircleButton(
                  icon: _chromeVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  semanticLabel: _chromeVisible
                      ? 'Hide controls'
                      : 'Show controls',
                  onTap: _toggleChrome,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterDot extends StatelessWidget {
  const _CenterDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF147DFF),
          border: Border.all(color: Colors.white, width: 2.3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8)],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.pin,
    required this.selected,
    required this.showPreview,
    required this.onTap,
    required this.onOpen,
    required this.onClose,
  });

  final MapPin pin;
  final bool selected;
  final bool showPreview;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (!showPreview) {
      return Center(
        child: _PinDot(pin: pin, selected: selected, onTap: onTap),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 42,
          child: _PinPreview(pin: pin, onOpen: onOpen, onClose: onClose),
        ),
        Positioned(
          bottom: 0,
          child: _PinDot(pin: pin, selected: true, onTap: onTap),
        ),
      ],
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
    final detail = pin.isListing ? _listingDetail(pin) : _profileDetail(pin);

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: const Color(0xF511141A),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withAlpha(96), width: .8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x57000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
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
                                      fontSize: pin.isListing ? 13.4 : 10.4,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (!pin.isListing && profile?.verified == true)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.verified_rounded,
                                      color: Color(0xFF60A5FA),
                                      size: 14,
                                    ),
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
                                fontSize: 10.2,
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
                                  color: Colors.white.withAlpha(158),
                                  fontSize: 8.7,
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
              right: 5,
              top: 5,
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
                      color: Colors.white,
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
            : CachedNetworkImage(
  imageUrl: url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({
    required this.pin,
    required this.selected,
    required this.onTap,
  });

  final MapPin pin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        hoverColor: Colors.transparent,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: selected ? 34 : 29,
          height: selected ? 34 : 29,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pin.isListing ? const Color(0xFF111318) : Colors.white,
            border: Border.all(
              color: pin.isListing ? Colors.white : const Color(0xFF111318),
              width: selected ? 3 : 2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x4F000000), blurRadius: 9),
            ],
          ),
          child: Icon(
            pin.isListing ? Icons.home_work_rounded : Icons.person_rounded,
            size: selected ? 17 : 15,
            color: pin.isListing ? Colors.white : const Color(0xFF111318),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.glyph,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    final visual = glyph == null
        ? Icon(icon, color: Colors.white, size: 19)
        : Text(
            glyph!,
            textAlign: TextAlign.center,
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
        color: const Color(0xCC11141A),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withAlpha(70), width: .7),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.transparent,
          focusColor: Colors.white.withAlpha(12),
          splashColor: Colors.white.withAlpha(24),
          child: SizedBox(width: 40, height: 40, child: Center(child: visual)),
        ),
      ),
    );
  }
}

class _LabelButton extends StatelessWidget {
  const _LabelButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? const Color(0xFF111318) : Colors.white;
    return Material(
      color: selected ? const Color(0xEFFFFFFF) : const Color(0xCC11141A),
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
                label,
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
        color: const Color(0xCC11141A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(54), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Choice(
            label: 'ALL',
            active: layer == 'all',
            onTap: () => onLayer('all'),
          ),
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
        color: const Color(0xC811141A),
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
          _Choice(label: 'WORLD', active: radiusKm >= 5000, onTap: onWorld),
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
