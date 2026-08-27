import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_locations.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_chips.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:geolocator/geolocator.dart' hide Position, LocationSettings;
import 'package:geolocator/geolocator.dart' as geo show LocationSettings;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Native discovery map rebuilt around a dependable public Mapbox basemap.
///
/// The previous redesign used a custom style that could leave the native
/// platform view blank while Flutter controls still rendered. This version uses
/// Mapbox's public light style, keeps every overlay as Flutter UI, and exposes a
/// ready signal so the mobile bootstrap can fall back instead of ever leaving a
/// user on an empty map.
class RealMapboxScreenV2 extends ConsumerStatefulWidget {
  const RealMapboxScreenV2({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
    this.onMapReady,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;
  final VoidCallback? onMapReady;

  @override
  ConsumerState<RealMapboxScreenV2> createState() =>
      _RealMapboxScreenV2State();
}

enum _MapKind {
  event,
  property,
  service,
  motorcycle,
  bicycle,
  yacht,
  person,
}

extension on _MapKind {
  Color get color {
    switch (this) {
      case _MapKind.event:
        return const Color(0xFF8B5CF6);
      case _MapKind.property:
        return const Color(0xFF14B8A6);
      case _MapKind.service:
        return const Color(0xFFF43F5E);
      case _MapKind.motorcycle:
        return const Color(0xFFFF7A18);
      case _MapKind.bicycle:
        return const Color(0xFF22C55E);
      case _MapKind.yacht:
        return const Color(0xFF3B82F6);
      case _MapKind.person:
        return const Color(0xFF6366F1);
    }
  }

  IconData get icon {
    switch (this) {
      case _MapKind.event:
        return Icons.music_note_rounded;
      case _MapKind.property:
        return Icons.home_rounded;
      case _MapKind.service:
        return Icons.room_service_rounded;
      case _MapKind.motorcycle:
        return Icons.two_wheeler_rounded;
      case _MapKind.bicycle:
        return Icons.pedal_bike_rounded;
      case _MapKind.yacht:
        return Icons.sailing_rounded;
      case _MapKind.person:
        return Icons.person_rounded;
    }
  }

  String get tag {
    switch (this) {
      case _MapKind.event:
        return 'EVENT';
      case _MapKind.property:
        return 'PROPERTY';
      case _MapKind.service:
        return 'SERVICE';
      case _MapKind.motorcycle:
        return 'MOTO';
      case _MapKind.bicycle:
        return 'BIKE';
      case _MapKind.yacht:
        return 'YACHT';
      case _MapKind.person:
        return 'PERSON';
    }
  }
}

class _MapItem {
  const _MapItem({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.price,
    this.listing,
    this.profile,
    this.event,
  });

  final String id;
  final _MapKind kind;
  final double lat;
  final double lng;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String price;
  final Listing? listing;
  final Profile? profile;
  final Event? event;

  String get key => '${kind.name}:$id';
}

class _RealMapboxScreenV2State extends ConsumerState<RealMapboxScreenV2> {
  // Use a Mapbox-owned style rather than a user-owned custom style. Any valid
  // public pk token can load this style, which removes the blank-map failure
  // mode seen in TestFlight when custom style permissions/cache fail.
  static const _styleUri = 'mapbox://styles/mapbox/light-v11';

  MapboxMap? _map;
  PointAnnotationManager? _pinManager;
  PointAnnotationManager? _locationManager;
  PolygonAnnotationManager? _radiusManager;
  final Map<_MapKind, Uint8List> _pinIcons = {};
  Uint8List? _locationIcon;

  double? _deviceLatitude;
  double? _deviceLongitude;
  bool _requestingDeviceLocation = false;
  bool _mapLoaded = false;
  bool _readyReported = false;
  bool _citiesOpen = false;
  String _activeCategory = 'all';
  String? _selectedKey;
  int _annotationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshDeviceLocation());
    });
  }

  Point _point(double lat, double lng) =>
      Point(coordinates: Position(lng, lat));

  double _zoomForRadius(int km) {
    if (km <= 5) return 13.8;
    if (km <= 10) return 12.9;
    if (km <= 25) return 11.8;
    if (km <= 50) return 10.8;
    if (km <= 100) return 9.8;
    if (km <= 250) return 8.6;
    if (km <= 1000) return 6.0;
    if (km <= 5000) return 3.4;
    return 1.6;
  }

  Future<void> _setupMap(MapboxMap map) async {
    _map = map;
    final loc = ref.read(discoveryLocationProvider);
    try {
      await map.setCamera(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: _zoomForRadius(loc.radiusKm),
          pitch: 0,
          bearing: 0,
        ),
      );
    } catch (_) {
      // The style-loading watchdog in the parent handles a genuinely unusable
      // Mapbox view. Camera errors should never crash the map surface.
    }
  }

  Future<void> _flyTo(DiscoveryLocation loc, {double? zoom}) async {
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
        MapAnimationOptions(duration: 620, startDelay: 0),
      );
    } catch (_) {}
  }

  Future<void> _flyToDevice() async {
    if (_deviceLatitude == null || _deviceLongitude == null) {
      await _refreshDeviceLocation();
    }
    final map = _map;
    final lat = _deviceLatitude;
    final lng = _deviceLongitude;
    if (map == null || lat == null || lng == null) return;
    try {
      await map.flyTo(
        CameraOptions(
          center: _point(lat, lng),
          zoom: 14.5,
          pitch: 0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 480, startDelay: 0),
      );
    } catch (_) {}
  }

  Future<void> _refreshDeviceLocation() async {
    if (_requestingDeviceLocation) return;
    _requestingDeviceLocation = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && mounted) {
        _deviceLatitude = cached.latitude;
        _deviceLongitude = cached.longitude;
        unawaited(_renderAnnotations());
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      _deviceLatitude = current.latitude;
      _deviceLongitude = current.longitude;
      await _renderAnnotations();
    } catch (_) {
      // Location is optional. Discovery still works from the selected city.
    } finally {
      _requestingDeviceLocation = false;
    }
  }

  Future<Uint8List> _buildTeardropIcon(_MapKind kind) async {
    const size = 112.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(size / 2, 43);
    const radius = 25.0;
    const tipY = 91.0;

    ui.Path pinPath(double inset) {
      final r = radius - inset;
      final c = ui.Offset(center.dx, center.dy + inset * 0.35);
      final tip = tipY - inset * 1.15;
      final path = ui.Path()
        ..moveTo(c.dx, tip)
        ..cubicTo(
          c.dx - r * 0.42,
          c.dy + r * 0.98,
          c.dx - r,
          c.dy + r * 0.62,
          c.dx - r,
          c.dy,
        )
        ..arcToPoint(
          ui.Offset(c.dx + r, c.dy),
          radius: ui.Radius.circular(r),
          clockwise: true,
        )
        ..cubicTo(
          c.dx + r,
          c.dy + r * 0.62,
          c.dx + r * 0.42,
          c.dy + r * 0.98,
          c.dx,
          tip,
        )
        ..close();
      return path;
    }

    final outer = pinPath(0);
    canvas.drawPath(
      outer.shift(const ui.Offset(0, 4)),
      ui.Paint()
        ..color = Colors.black.withAlpha(58)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
    );
    canvas.drawPath(outer, ui.Paint()..color = Colors.white);
    canvas.drawPath(pinPath(4), ui.Paint()..color = kind.color);

    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(kind.icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontFamily: kind.icon.fontFamily,
          package: kind.icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      ui.Offset(center.dx - painter.width / 2, center.dy - painter.height / 2 - 1),
    );

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _buildLocationIcon() async {
    const size = 94.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(size / 2, size / 2);
    canvas.drawCircle(
      center,
      30,
      ui.Paint()..color = const Color(0x26147DFF),
    );
    canvas.drawCircle(
      center.translate(0, 2),
      21,
      ui.Paint()
        ..color = Colors.black.withAlpha(46)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );
    canvas.drawCircle(center, 18.5, ui.Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      13.5,
      ui.Paint()..color = const Color(0xFF147DFF),
    );
    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _prepareAnnotationManagers() async {
    final map = _map;
    if (map == null || _pinManager != null) return;
    _radiusManager = await map.annotations.createPolygonAnnotationManager();
    _pinManager = await map.annotations.createPointAnnotationManager();
    _locationManager = await map.annotations.createPointAnnotationManager();

    for (final kind in _MapKind.values) {
      _pinIcons[kind] = await _buildTeardropIcon(kind);
    }
    _locationIcon = await _buildLocationIcon();

    _pinManager?.tapEvents(
      onTap: (annotation) {
        final p = annotation.geometry.coordinates;
        _selectNearest(p.lat.toDouble(), p.lng.toDouble());
      },
    );
  }

  ({double lat, double lng}) _spread(
    String key,
    double baseLat,
    double baseLng, {
    double minMeters = 70,
    double stepMeters = 32,
  }) {
    var hash = 137;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final meters = minMeters + ((hash ~/ 360) % 8) * stepMeters;
    final latDelta = meters / 111320.0;
    final cosLat = math.cos(baseLat * math.pi / 180).abs();
    final lngDelta = meters / (111320.0 * (cosLat < .25 ? .25 : cosLat));
    return (
      lat: baseLat + math.sin(angle) * latDelta,
      lng: baseLng + math.cos(angle) * lngDelta,
    );
  }

  ({double lat, double lng}) _cityPoint(
    String key,
    String? city,
    DiscoveryLocation loc,
  ) {
    var baseLat = loc.latitude;
    var baseLng = loc.longitude;
    final resolved = ListingLocations.resolve(city ?? '');
    if (resolved != null) {
      baseLat = resolved.lat;
      baseLng = resolved.lng;
    }
    return _spread(key, baseLat, baseLng, minMeters: 420, stepMeters: 115);
  }

  _MapKind _listingKind(Listing listing) {
    switch ((listing.category ?? '').trim().toLowerCase()) {
      case 'worker':
      case 'service':
        return _MapKind.service;
      case 'motorcycle':
      case 'moto':
        return _MapKind.motorcycle;
      case 'bicycle':
      case 'bike':
        return _MapKind.bicycle;
      case 'yacht':
      case 'boat':
        return _MapKind.yacht;
      case 'property':
      default:
        return _MapKind.property;
    }
  }

  _MapItem _listingItem(Listing listing, DiscoveryLocation loc) {
    final point = listing.latitude != null && listing.longitude != null
        ? _spread(listing.id, listing.latitude!, listing.longitude!)
        : _cityPoint(listing.id, listing.city, loc);
    return _MapItem(
      id: listing.id,
      kind: _listingKind(listing),
      lat: point.lat,
      lng: point.lng,
      title: (listing.title ?? '').trim().isEmpty
          ? 'Swipess listing'
          : listing.title!.trim(),
      subtitle: listing.formattedLocation,
      imageUrl: listing.primaryImage ?? '',
      price: listing.formattedPrice,
      listing: listing,
    );
  }

  _MapItem _profileItem(Profile profile, DiscoveryLocation loc) {
    final point = profile.latitude != null && profile.longitude != null
        ? _spread(profile.id, profile.latitude!, profile.longitude!)
        : _cityPoint(profile.id, profile.city, loc);
    return _MapItem(
      id: profile.id,
      kind: _MapKind.person,
      lat: point.lat,
      lng: point.lng,
      title: profile.displayName,
      subtitle: profile.city ?? 'Nearby',
      imageUrl: profile.avatarUrl ?? '',
      price: profile.role ?? '',
      profile: profile,
    );
  }

  bool _eventMatchesCity(Event event, DiscoveryLocation loc) {
    if (loc.radiusKm >= 500) return true;
    final city = loc.city.trim().toLowerCase();
    if (city.isEmpty || city == 'near you') return true;
    final haystack = '${event.location ?? ''} ${event.locationDetail ?? ''}'
        .toLowerCase();
    // If the event has no location metadata, keep it discoverable at the
    // selected city rather than silently losing it from the map.
    if (haystack.trim().isEmpty) return true;
    return haystack.contains(city);
  }

  _MapItem _eventItem(Event event, DiscoveryLocation loc) {
    final locationText = '${event.location ?? ''} ${event.locationDetail ?? ''}'.trim();
    final resolved = ListingLocations.resolve(locationText) ??
        ListingLocations.resolve(event.location ?? '');
    final baseLat = resolved?.lat ?? loc.latitude;
    final baseLng = resolved?.lng ?? loc.longitude;
    final point = _spread(
      'event:${event.id}',
      baseLat,
      baseLng,
      minMeters: 180,
      stepMeters: 70,
    );
    final image = event.imageUrl ??
        (event.imageUrls.isNotEmpty ? event.imageUrls.first : '');
    return _MapItem(
      id: event.id,
      kind: _MapKind.event,
      lat: point.lat,
      lng: point.lng,
      title: event.title,
      subtitle: event.location ?? event.locationDetail ?? loc.city,
      imageUrl: image,
      price: event.price,
      event: event,
    );
  }

  bool _matchesFilter(_MapItem item) {
    switch (_activeCategory) {
      case 'events':
        return item.kind == _MapKind.event;
      case 'properties':
        return item.kind == _MapKind.property;
      case 'services':
        return item.kind == _MapKind.service;
      default:
        return true;
    }
  }

  List<_MapItem> _visibleItems() {
    final loc = ref.read(discoveryLocationProvider);
    final listings = ref.read(mapListingsProvider).value ?? const <Listing>[];
    final profiles = ref.read(mapProfilesProvider).value ?? const <Profile>[];
    final events = ref.read(eventsListProvider).value ?? const <Event>[];

    final items = <_MapItem>[
      for (final listing in listings) _listingItem(listing, loc),
      for (final profile in profiles) _profileItem(profile, loc),
      for (final event in events)
        if (_eventMatchesCity(event, loc)) _eventItem(event, loc),
    ];
    return items.where(_matchesFilter).toList(growable: false);
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

  Future<void> _renderAnnotations() async {
    if (!_mapLoaded ||
        _pinManager == null ||
        _locationManager == null ||
        _radiusManager == null) {
      return;
    }
    final generation = ++_annotationGeneration;
    final items = _visibleItems();
    final loc = ref.read(discoveryLocationProvider);

    try {
      await Future.wait([
        _pinManager!.deleteAll(),
        _locationManager!.deleteAll(),
        _radiusManager!.deleteAll(),
      ]);
      if (!mounted || generation != _annotationGeneration) return;

      if (loc.radiusKm <= 250) {
        await _radiusManager!.create(
          PolygonAnnotationOptions(
            geometry: _radiusPolygon(loc),
            fillColor: const Color(0xFF3B82F6).toARGB32(),
            fillOpacity: 0.09,
            fillOutlineColor: const Color(0xFF147DFF).toARGB32(),
          ),
        );
      }

      final deviceLat = _deviceLatitude;
      final deviceLng = _deviceLongitude;
      if (deviceLat != null && deviceLng != null && _locationIcon != null) {
        await _locationManager!.create(
          PointAnnotationOptions(
            geometry: _point(deviceLat, deviceLng),
            image: _locationIcon,
            iconSize: 1.0,
            symbolSortKey: 10000,
          ),
        );
      }

      final options = <PointAnnotationOptions>[
        for (final item in items)
          if (_pinIcons[item.kind] != null)
            PointAnnotationOptions(
              geometry: _point(item.lat, item.lng),
              image: _pinIcons[item.kind],
              iconSize: item.key == _selectedKey ? 1.18 : 1.0,
              symbolSortKey: item.key == _selectedKey ? 9000 : 5000,
            ),
      ];
      if (options.isNotEmpty) await _pinManager!.createMulti(options);
    } catch (_) {
      // One optional annotation failure must never blank or replace the basemap.
    }
  }

  void _selectNearest(double lat, double lng) {
    final items = _visibleItems();
    _MapItem? best;
    var bestDistance = double.infinity;
    for (final item in items) {
      final dLat = item.lat - lat;
      final dLng = item.lng - lng;
      final distance = dLat * dLat + dLng * dLng;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = item;
      }
    }
    if (best == null) return;
    AppHaptics.selection();
    setState(() => _selectedKey = best!.key);
    unawaited(_renderAnnotations());
    unawaited(
      _map?.easeTo(
        CameraOptions(
          center: _point(best.lat, best.lng),
          zoom: 14.2,
          pitch: 0,
          bearing: 0,
          padding: MbxEdgeInsets(bottom: 245, left: 0, top: 0, right: 0),
        ),
        MapAnimationOptions(duration: 360, startDelay: 0),
      ),
    );
  }

  void _setCategory(String value) {
    AppHaptics.selection();
    setState(() {
      _activeCategory = value;
      _selectedKey = null;
    });
    unawaited(_renderAnnotations());
  }

  void _openItem(_MapItem item) {
    AppHaptics.medium();
    if (item.event != null) {
      context.push(AppPaths.exploreEvent(item.id));
    } else if (item.listing != null) {
      context.push(AppPaths.listing(item.id));
    } else {
      context.push(AppPaths.profile(item.id));
    }
  }

  void _openAll() {
    switch (_activeCategory) {
      case 'events':
        context.push(AppPaths.exploreEvents);
        return;
      case 'services':
        context.push(AppPaths.exploreServices);
        return;
      default:
        context.push(AppPaths.clientFilters);
    }
  }

  void _reportReady() {
    if (_readyReported) return;
    _readyReported = true;
    widget.onMapReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    ref.watch(mapListingsProvider);
    ref.watch(mapProfilesProvider);
    ref.watch(eventsListProvider);

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null ||
          previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.radiusKm != next.radiusKm ||
          previous.city != next.city) {
        _selectedKey = null;
        unawaited(_flyTo(next));
        unawaited(_renderAnnotations());
      }
    });
    ref.listen(mapListingsProvider, (_, __) => unawaited(_renderAnnotations()));
    ref.listen(mapProfilesProvider, (_, __) => unawaited(_renderAnnotations()));
    ref.listen(eventsListProvider, (_, __) => unawaited(_renderAnnotations()));

    final items = _visibleItems();

    return Material(
      color: const Color(0xFFF1F4F7),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('swipess-real-mapbox-v2'),
              styleUri: _styleUri,
              onMapCreated: _setupMap,
              onMapLoadedListener: (_) async {
                _mapLoaded = true;
                _reportReady();
                await _prepareAnnotationManagers();
                await _renderAnnotations();
                if (mounted) unawaited(_refreshDeviceLocation());
              },
            ),
          ),
          if (!_mapLoaded)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Color(0xFFF1F4F7),
                  child: Center(
                    child: SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 155,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withAlpha(246),
                      Colors.white.withAlpha(214),
                      Colors.white.withAlpha(0),
                    ],
                    stops: const [0, .55, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                  child: Row(
                    children: [
                      _RoundTopButton(
                        icon: Icons.menu_rounded,
                        onTap: widget.onClose ??
                            () => context.go(AppPaths.clientDashboard),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'SWIPESS',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                      ),
                      _RoundTopButton(
                        icon: Icons.search_rounded,
                        onTap: () => setState(() => _citiesOpen = !_citiesOpen),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _QuickChip(
                        label: 'All',
                        icon: Icons.grid_view_rounded,
                        active: _activeCategory == 'all',
                        onTap: () => _setCategory('all'),
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: 'Events',
                        icon: Icons.local_activity_outlined,
                        active: _activeCategory == 'events',
                        onTap: () => _setCategory('events'),
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: 'Properties',
                        icon: Icons.home_outlined,
                        active: _activeCategory == 'properties',
                        onTap: () => _setCategory('properties'),
                      ),
                      const SizedBox(width: 8),
                      _QuickChip(
                        label: 'Services',
                        icon: Icons.room_service_outlined,
                        active: _activeCategory == 'services',
                        onTap: () => _setCategory('services'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_citiesOpen)
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.paddingOf(context).top + 105,
              child: MapCityChips(
                activeCity: loc.city,
                onSelect: (city) {
                  ref.read(discoveryLocationProvider.notifier).setCoordinates(
                    city: city.name,
                    country: city.country,
                    latitude: city.lat,
                    longitude: city.lng,
                  );
                  if (loc.radiusKm > 500) {
                    ref.read(discoveryLocationProvider.notifier).setRadiusKm(25);
                  }
                  setState(() => _citiesOpen = false);
                },
              ),
            ),
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 310,
            child: _MapActionButton(
              icon: Icons.my_location_rounded,
              tooltip: 'My location',
              onTap: _flyToDevice,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _DiscoverTray(
              items: items,
              city: loc.city,
              selectedKey: _selectedKey,
              onOpen: _openItem,
              onSeeAll: _openAll,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundTopButton extends StatelessWidget {
  const _RoundTopButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 22, color: Colors.black),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
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
    return Material(
      color: active ? Colors.black : Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: active ? 3 : 1,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: active ? Colors.white : Colors.black),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: active ? Colors.white : Colors.black,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
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
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: Colors.black, size: 23),
          ),
        ),
      ),
    );
  }
}

class _DiscoverTray extends StatefulWidget {
  const _DiscoverTray({
    required this.items,
    required this.city,
    required this.selectedKey,
    required this.onOpen,
    required this.onSeeAll,
  });

  final List<_MapItem> items;
  final String city;
  final String? selectedKey;
  final void Function(_MapItem item) onOpen;
  final VoidCallback onSeeAll;

  @override
  State<_DiscoverTray> createState() => _DiscoverTrayState();
}

class _DiscoverTrayState extends State<_DiscoverTray> {
  static const _itemExtent = 198.0;
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant _DiscoverTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedKey == null ||
        widget.selectedKey == oldWidget.selectedKey) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final index = widget.items.indexWhere((item) => item.key == widget.selectedKey);
      if (index < 0) return;
      final wanted = index * _itemExtent;
      final target = wanted.clamp(0.0, _controller.position.maxScrollExtent);
      _controller.animateTo(
        target.toDouble(),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.city.trim().isEmpty ? 'Nearby' : widget.city.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(32),
            blurRadius: 24,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 9),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 11, 16, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Discover $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onSeeAll,
                    child: Text(
                      'See all',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF147DFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.items.isEmpty)
              SizedBox(
                height: 126,
                child: Center(
                  child: Text(
                    'Nothing nearby yet.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 178,
                child: ListView.builder(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return _DiscoveryCard(
                      item: item,
                      selected: item.key == widget.selectedKey,
                      onTap: () => widget.onOpen(item),
                    );
                  },
                ),
              ),
            const SizedBox(height: 76),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _MapItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 186,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? item.kind.color : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(selected ? 28 : 13),
              blurRadius: selected ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 94,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.imageUrl.trim().isNotEmpty)
                      Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: const Color(0xFFF0F2F5)),
                      )
                    else
                      Container(
                        color: const Color(0xFFF0F2F5),
                        child: Icon(
                          item.kind.icon,
                          color: item.kind.color,
                          size: 34,
                        ),
                      ),
                    Positioned(
                      left: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.kind.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.kind.tag,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 7,
                      right: 7,
                      child: Icon(
                        Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 19,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 5)],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.black54,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.black54,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (item.price.trim().isNotEmpty)
                        Text(
                          item.price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black87,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
