import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_locations.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
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

/// Premium native Mapbox discovery surface used by iOS and Android.
///
/// Design goals:
/// - real Mapbox SDK, never the browser/FlutterMap fallback on native;
/// - compact borderless chrome;
/// - burger opens a real map menu instead of closing Map;
/// - search is actual discovery search, including known cities;
/// - markers select a compact preview and previews push detail routes;
/// - the bottom tray can collapse, expand, or disappear with a vertical swipe;
/// - map hearts save into the existing Likes system and immediately remove the
///   item from discovery;
/// - navigation uses push, allowing OverlayModalsHost to reveal this exact live
///   map instance when the user presses Back from details.
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
        return const Color(0xFF0F9F8F);
      case _MapKind.service:
        return const Color(0xFFE84D68);
      case _MapKind.motorcycle:
        return const Color(0xFFFF7A18);
      case _MapKind.bicycle:
        return const Color(0xFF20A85A);
      case _MapKind.yacht:
        return const Color(0xFF147DFF);
      case _MapKind.person:
        return const Color(0xFF6557E8);
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

  List<String> get searchAliases {
    switch (this) {
      case _MapKind.event:
        return const ['event', 'events', 'party', 'music', 'what to do'];
      case _MapKind.property:
        return const ['property', 'properties', 'house', 'home', 'apartment', 'rent', 'sale'];
      case _MapKind.service:
        return const ['service', 'services', 'worker', 'chef', 'massage', 'cleaning', 'dining'];
      case _MapKind.motorcycle:
        return const ['motorcycle', 'motorbike', 'moto', 'scooter'];
      case _MapKind.bicycle:
        return const ['bicycle', 'bike', 'bikes', 'e-bike'];
      case _MapKind.yacht:
        return const ['yacht', 'yachts', 'boat'];
      case _MapKind.person:
        return const ['person', 'people', 'profile', 'member', 'roommate'];
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
  static const _styleUri = MapboxStyles.STANDARD;

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
  bool _menuOpen = false;
  bool _citiesOpen = false;
  bool _searchOpen = false;
  bool _controlsVisible = true;
  String _activeCategory = 'all';
  String _query = '';
  String? _selectedKey;
  int _annotationGeneration = 0;
  int _trayLevel = 0; // -1 hidden, 0 compact, 1 expanded
  final Set<String> _locallyHidden = <String>{};

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

  double _pitchForRadius(int km) {
    if (km <= 10) return 42;
    if (km <= 50) return 30;
    if (km <= 250) return 16;
    return 0;
  }

  Future<void> _setupMap(MapboxMap map) async {
    _map = map;
    final loc = ref.read(discoveryLocationProvider);
    try {
      await map.setCamera(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: _zoomForRadius(loc.radiusKm),
          pitch: _pitchForRadius(loc.radiusKm),
          bearing: loc.radiusKm <= 50 ? 10 : 0,
        ),
      );
    } catch (_) {}
  }

  Future<void> _flyTo(DiscoveryLocation loc, {double? zoom}) async {
    final map = _map;
    if (map == null) return;
    try {
      await map.flyTo(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: zoom ?? _zoomForRadius(loc.radiusKm),
          pitch: _pitchForRadius(loc.radiusKm),
          bearing: loc.radiusKm <= 50 ? 10 : 0,
        ),
        MapAnimationOptions(duration: 650, startDelay: 0),
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
          zoom: 14.7,
          pitch: 42,
          bearing: 12,
        ),
        MapAnimationOptions(duration: 520, startDelay: 0),
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
      // GPS is optional; selected-city discovery still works.
    } finally {
      _requestingDeviceLocation = false;
    }
  }

  Future<Uint8List> _buildTeardropIcon(_MapKind kind) async {
    const size = 104.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(size / 2, 40);
    const radius = 23.0;
    const tipY = 85.0;

    ui.Path pinPath(double inset) {
      final r = radius - inset;
      final c = ui.Offset(center.dx, center.dy + inset * .35);
      final tip = tipY - inset * 1.15;
      return ui.Path()
        ..moveTo(c.dx, tip)
        ..cubicTo(c.dx - r * .42, c.dy + r * .98, c.dx - r, c.dy + r * .62, c.dx - r, c.dy)
        ..arcToPoint(ui.Offset(c.dx + r, c.dy), radius: ui.Radius.circular(r), clockwise: true)
        ..cubicTo(c.dx + r, c.dy + r * .62, c.dx + r * .42, c.dy + r * .98, c.dx, tip)
        ..close();
    }

    final outer = pinPath(0);
    canvas.drawPath(
      outer.shift(const ui.Offset(0, 3)),
      ui.Paint()
        ..color = Colors.black.withAlpha(52)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );
    canvas.drawPath(outer, ui.Paint()..color = Colors.white);
    canvas.drawPath(pinPath(3.5), ui.Paint()..color = kind.color);

    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(kind.icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 23,
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

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _buildLocationIcon() async {
    const size = 90.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(size / 2, size / 2);
    canvas.drawCircle(center, 29, ui.Paint()..color = const Color(0x24147DFF));
    canvas.drawCircle(
      center.translate(0, 2),
      20,
      ui.Paint()
        ..color = Colors.black.withAlpha(42)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );
    canvas.drawCircle(center, 18, ui.Paint()..color = Colors.white);
    canvas.drawCircle(center, 13, ui.Paint()..color = const Color(0xFF147DFF));
    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
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
      case 'dining':
      case 'restaurant':
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
      title: (listing.title ?? '').trim().isEmpty ? 'Swipess listing' : listing.title!.trim(),
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
    final haystack = '${event.location ?? ''} ${event.locationDetail ?? ''}'.toLowerCase();
    if (haystack.trim().isEmpty) return true;
    return haystack.contains(city);
  }

  _MapItem _eventItem(Event event, DiscoveryLocation loc) {
    final locationText = '${event.location ?? ''} ${event.locationDetail ?? ''}'.trim();
    final resolved = ListingLocations.resolve(locationText) ?? ListingLocations.resolve(event.location ?? '');
    final point = _spread(
      'event:${event.id}',
      resolved?.lat ?? loc.latitude,
      resolved?.lng ?? loc.longitude,
      minMeters: 180,
      stepMeters: 70,
    );
    final image = event.imageUrl ?? (event.imageUrls.isNotEmpty ? event.imageUrls.first : '');
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

  bool _matchesCategory(_MapItem item) {
    switch (_activeCategory) {
      case 'events':
        return item.kind == _MapKind.event;
      case 'properties':
        return item.kind == _MapKind.property;
      case 'services':
        return item.kind == _MapKind.service;
      case 'yachts':
        return item.kind == _MapKind.yacht;
      case 'motos':
        return item.kind == _MapKind.motorcycle;
      case 'bikes':
        return item.kind == _MapKind.bicycle;
      case 'people':
        return item.kind == _MapKind.person;
      default:
        return true;
    }
  }

  bool _matchesQuery(_MapItem item) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = <String>[
      item.title,
      item.subtitle,
      item.price,
      item.kind.tag,
      ...item.kind.searchAliases,
    ].join(' ').toLowerCase();
    final words = query.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return words.every(haystack.contains);
  }

  List<_MapItem> _visibleItems() {
    final loc = ref.read(discoveryLocationProvider);
    final listings = ref.read(mapListingsProvider).value ?? const <Listing>[];
    final profiles = ref.read(mapProfilesProvider).value ?? const <Profile>[];
    final events = ref.read(eventsListProvider).value ?? const <Event>[];
    final likedEventIds = ref.read(likedEventIdsProvider).value ?? const <String>{};

    final items = <_MapItem>[
      for (final listing in listings) _listingItem(listing, loc),
      for (final profile in profiles) _profileItem(profile, loc),
      for (final event in events)
        if (_eventMatchesCity(event, loc) && !likedEventIds.contains(event.id)) _eventItem(event, loc),
    ];
    return items
        .where((item) => !_locallyHidden.contains(item.key))
        .where(_matchesCategory)
        .where(_matchesQuery)
        .toList(growable: false);
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
    if (!_mapLoaded || _pinManager == null || _locationManager == null || _radiusManager == null) return;
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
            fillOpacity: .075,
            fillOutlineColor: const Color(0xFF147DFF).toARGB32(),
          ),
        );
      }

      if (_deviceLatitude != null && _deviceLongitude != null && _locationIcon != null) {
        await _locationManager!.create(
          PointAnnotationOptions(
            geometry: _point(_deviceLatitude!, _deviceLongitude!),
            image: _locationIcon,
            iconSize: 1,
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
              iconSize: item.key == _selectedKey ? 1.14 : .94,
              symbolSortKey: item.key == _selectedKey ? 9000 : 5000,
            ),
      ];
      if (options.isNotEmpty) await _pinManager!.createMulti(options);
    } catch (_) {
      // Optional annotation failures never replace the basemap.
    }
  }

  _MapItem? get _selectedItem {
    final key = _selectedKey;
    if (key == null) return null;
    for (final item in _visibleItems()) {
      if (item.key == key) return item;
    }
    return null;
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
    setState(() {
      _selectedKey = best!.key;
      if (_trayLevel < 0) _trayLevel = 0;
      _menuOpen = false;
      _citiesOpen = false;
    });
    unawaited(_renderAnnotations());
    unawaited(
      _map?.easeTo(
        CameraOptions(
          center: _point(best.lat, best.lng),
          zoom: 14.4,
          pitch: 40,
          bearing: 10,
          padding: MbxEdgeInsets(bottom: 195, left: 0, top: 0, right: 0),
        ),
        MapAnimationOptions(duration: 380, startDelay: 0),
      ),
    );
  }

  void _setCategory(String value) {
    AppHaptics.selection();
    setState(() {
      _activeCategory = value;
      _selectedKey = null;
      _menuOpen = false;
    });
    unawaited(_renderAnnotations());
  }

  Future<void> _submitSearch(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return;
    final resolved = ListingLocations.resolve(value);
    if (resolved != null) {
      ref.read(discoveryLocationProvider.notifier).setCoordinates(
        city: value,
        country: resolved.country,
        latitude: resolved.lat,
        longitude: resolved.lng,
      );
      if (ref.read(discoveryLocationProvider).radiusKm > 250) {
        ref.read(discoveryLocationProvider.notifier).setRadiusKm(25);
      }
      if (mounted) {
        setState(() {
          _query = '';
          _searchOpen = false;
          _selectedKey = null;
        });
      }
      return;
    }

    setState(() {
      _query = value;
      _selectedKey = null;
    });
    await _renderAnnotations();
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

  Future<void> _likeItem(_MapItem item) async {
    AppHaptics.medium();
    try {
      final repository = ref.read(likesRepositoryProvider);
      if (item.listing != null) {
        await repository.likeListing(item.id);
        ref.invalidate(likedListingsProvider);
        ref.invalidate(mapListingsProvider);
      } else if (item.profile != null) {
        await repository.likePerson(item.id);
        ref.invalidate(likedPeopleProvider);
        ref.invalidate(mapProfilesProvider);
      } else if (item.event != null) {
        await repository.likeEvent(item.id);
        ref.invalidate(likedEventIdsProvider);
      }

      if (!mounted) return;
      setState(() {
        _locallyHidden.add(item.key);
        if (_selectedKey == item.key) _selectedKey = null;
      });
      unawaited(_renderAnnotations());
      ref.read(appNotificationsProvider.notifier).show(
        title: 'Saved to Likes',
        message: '${item.title} is now in your Likes.',
        type: AppToastType.like,
      );
    } catch (_) {
      if (!mounted) return;
      ref.read(appNotificationsProvider.notifier).error(
        'Could not save this yet',
        'Please try again in a moment.',
      );
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

  void _closeMap() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      context.go(AppPaths.clientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    ref.watch(mapListingsProvider);
    ref.watch(mapProfilesProvider);
    ref.watch(eventsListProvider);
    ref.watch(likedEventIdsProvider);

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
    ref.listen(likedEventIdsProvider, (_, __) => unawaited(_renderAnnotations()));

    final items = _visibleItems();
    final selected = _selectedItem;
    final pad = MediaQuery.paddingOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final compactTrayHeight = math.min(154.0 + pad.bottom, screenHeight * .24);
    final expandedTrayHeight = math.min(305.0 + pad.bottom, screenHeight * .43);
    final trayHeight = _trayLevel < 0
        ? 0.0
        : _trayLevel == 0
            ? compactTrayHeight
            : expandedTrayHeight;

    return Material(
      color: const Color(0xFFF1F4F7),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
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

          // Soft atmospheric shade only; no rectangular outline/frame.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 132,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withAlpha(220),
                      Colors.white.withAlpha(115),
                      Colors.white.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_controlsVisible) ...[
            Positioned(
              top: pad.top + 5,
              left: 8,
              right: 8,
              child: _MapHeader(
                menuOpen: _menuOpen,
                searchOpen: _searchOpen,
                onMenu: () => setState(() {
                  _menuOpen = !_menuOpen;
                  _citiesOpen = false;
                }),
                onSearch: () => setState(() {
                  _searchOpen = !_searchOpen;
                  _menuOpen = false;
                  _citiesOpen = false;
                }),
              ),
            ),
            Positioned(
              top: pad.top + 47,
              left: 0,
              right: 0,
              child: _FilterRail(
                active: _activeCategory,
                onSelect: _setCategory,
              ),
            ),
            if (_searchOpen)
              Positioned(
                top: pad.top + 87,
                left: 12,
                right: 12,
                child: _MapSearchBar(
                  initialValue: _query,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                      _selectedKey = null;
                    });
                    unawaited(_renderAnnotations());
                  },
                  onSubmitted: _submitSearch,
                  onClear: () {
                    setState(() {
                      _query = '';
                      _selectedKey = null;
                    });
                    unawaited(_renderAnnotations());
                  },
                ),
              ),
            if (_menuOpen)
              Positioned(
                top: pad.top + 42,
                left: 10,
                child: _MapMenu(
                  city: loc.city,
                  trayVisible: _trayLevel >= 0,
                  onCities: () => setState(() {
                    _citiesOpen = true;
                    _menuOpen = false;
                    _searchOpen = false;
                  }),
                  onRecenter: () {
                    unawaited(_flyToDevice());
                    setState(() => _menuOpen = false);
                  },
                  onToggleTray: () => setState(() {
                    _trayLevel = _trayLevel >= 0 ? -1 : 0;
                    _menuOpen = false;
                  }),
                  onHideControls: () => setState(() {
                    _controlsVisible = false;
                    _menuOpen = false;
                  }),
                  onClose: _closeMap,
                ),
              ),
            if (_citiesOpen)
              Positioned(
                top: pad.top + 88,
                left: 0,
                right: 0,
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
          ] else
            Positioned(
              top: pad.top + 8,
              right: 8,
              child: _BareIconButton(
                icon: Icons.visibility_rounded,
                tooltip: 'Show map controls',
                onTap: () => setState(() => _controlsVisible = true),
              ),
            ),

          Positioned(
            right: 8,
            bottom: trayHeight + pad.bottom + 12,
            child: _BareIconButton(
              icon: Icons.my_location_rounded,
              tooltip: 'My exact location',
              onTap: _flyToDevice,
            ),
          ),

          if (selected != null && _trayLevel >= 0)
            Positioned(
              left: 14,
              right: 14,
              bottom: trayHeight + 12,
              child: _SelectedPreview(
                item: selected,
                onOpen: () => _openItem(selected),
                onLike: () => unawaited(_likeItem(selected)),
                onClose: () {
                  setState(() => _selectedKey = null);
                  unawaited(_renderAnnotations());
                },
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            left: 8,
            right: 8,
            bottom: _trayLevel < 0 ? -210 : 8,
            height: _trayLevel < 0 ? compactTrayHeight : trayHeight,
            child: _DiscoverTray(
              items: items,
              city: loc.city,
              selectedKey: _selectedKey,
              expanded: _trayLevel == 1,
              onSelect: (item) {
                setState(() => _selectedKey = item.key);
                unawaited(_renderAnnotations());
              },
              onOpen: _openItem,
              onLike: (item) => unawaited(_likeItem(item)),
              onSeeAll: _openAll,
              onDragUp: () => setState(() => _trayLevel = 1),
              onDragDown: () => setState(() {
                if (_trayLevel == 1) {
                  _trayLevel = 0;
                } else {
                  _trayLevel = -1;
                }
              }),
              onToggle: () => setState(() => _trayLevel = _trayLevel == 1 ? 0 : 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.menuOpen,
    required this.searchOpen,
    required this.onMenu,
    required this.onSearch,
  });

  final bool menuOpen;
  final bool searchOpen;
  final VoidCallback onMenu;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          _BareIconButton(
            icon: menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            tooltip: 'Map menu',
            onTap: onMenu,
          ),
          Expanded(
            child: Center(
              child: Text(
                'SWIPESS',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: .7,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          _BareIconButton(
            icon: searchOpen ? Icons.close_rounded : Icons.search_rounded,
            tooltip: 'Search map',
            onTap: onSearch,
          ),
        ],
      ),
    );
  }
}

class _BareIconButton extends StatelessWidget {
  const _BareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 34,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF111318),
              shadows: const [
                Shadow(color: Color(0x55FFFFFF), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSpec {
  const _FilterSpec(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const _filterSpecs = <_FilterSpec>[
  _FilterSpec('all', 'All', Icons.grid_view_rounded),
  _FilterSpec('events', 'Events', Icons.local_activity_rounded),
  _FilterSpec('properties', 'Properties', Icons.home_rounded),
  _FilterSpec('services', 'Services', Icons.room_service_rounded),
  _FilterSpec('yachts', 'Yachts', Icons.sailing_rounded),
  _FilterSpec('motos', 'Motos', Icons.two_wheeler_rounded),
  _FilterSpec('bikes', 'Bikes', Icons.pedal_bike_rounded),
  _FilterSpec('people', 'People', Icons.person_rounded),
];

class _FilterRail extends StatelessWidget {
  const _FilterRail({required this.active, required this.onSelect});

  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0, .025, .975, 1],
        ).createShader(rect),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _filterSpecs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 3),
          itemBuilder: (context, index) {
            final spec = _filterSpecs[index];
            final selected = spec.id == active;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(spec.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xF2111317) : const Color(0xDFFFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(color: Color(0x12000000), blurRadius: 7, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(spec.icon, size: 12.5, color: selected ? Colors.white : Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      spec.label,
                      style: GoogleFonts.plusJakartaSans(
                        color: selected ? Colors.white : Colors.black,
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MapSearchBar extends StatefulWidget {
  const _MapSearchBar({
    required this.initialValue,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  State<_MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<_MapSearchBar> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,
      decoration: BoxDecoration(
        color: const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x23000000), blurRadius: 18, offset: Offset(0, 7)),
        ],
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.black,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search property, event, yacht, moto, bike, person or city…',
          hintStyle: GoogleFonts.plusJakartaSans(
            color: Colors.black45,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.black54),
          suffixIcon: GestureDetector(
            onTap: () {
              _controller.clear();
              widget.onClear();
            },
            child: const Icon(Icons.close_rounded, size: 17, color: Colors.black45),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _MapMenu extends StatelessWidget {
  const _MapMenu({
    required this.city,
    required this.trayVisible,
    required this.onCities,
    required this.onRecenter,
    required this.onToggleTray,
    required this.onHideControls,
    required this.onClose,
  });

  final String city;
  final bool trayVisible;
  final VoidCallback onCities;
  final VoidCallback onRecenter;
  final VoidCallback onToggleTray;
  final VoidCallback onHideControls;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, VoidCallback onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 17, color: const Color(0xFF111318)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w750,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFAFFFFFF),
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 9)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(Icons.location_city_rounded, 'Choose city', onCities),
          row(Icons.my_location_rounded, 'My exact location', onRecenter),
          row(
            trayVisible ? Icons.visibility_off_rounded : Icons.view_carousel_rounded,
            trayVisible ? 'Hide discovery tray' : 'Show discovery tray',
            onToggleTray,
          ),
          row(Icons.visibility_off_rounded, 'Hide map controls', onHideControls),
          row(Icons.close_rounded, 'Close map', onClose),
        ],
      ),
    );
  }
}

class _SelectedPreview extends StatelessWidget {
  const _SelectedPreview({
    required this.item,
    required this.onOpen,
    required this.onLike,
    required this.onClose,
  });

  final _MapItem item;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 92),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFAFFFFFF),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x38000000), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 68,
                height: 68,
                child: item.imageUrl.trim().isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _KindPlaceholder(kind: item.kind),
                      )
                    : _KindPlaceholder(kind: item.kind),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.kind.tag,
                    style: GoogleFonts.plusJakartaSans(
                      color: item.kind.color,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onLike,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 38,
                height: 58,
                child: Icon(Icons.favorite_border_rounded, color: Color(0xFFFF375F), size: 23),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 30,
                height: 58,
                child: Icon(Icons.close_rounded, color: Colors.black45, size: 17),
              ),
            ),
          ],
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
    required this.expanded,
    required this.onSelect,
    required this.onOpen,
    required this.onLike,
    required this.onSeeAll,
    required this.onDragUp,
    required this.onDragDown,
    required this.onToggle,
  });

  final List<_MapItem> items;
  final String city;
  final String? selectedKey;
  final bool expanded;
  final ValueChanged<_MapItem> onSelect;
  final ValueChanged<_MapItem> onOpen;
  final ValueChanged<_MapItem> onLike;
  final VoidCallback onSeeAll;
  final VoidCallback onDragUp;
  final VoidCallback onDragDown;
  final VoidCallback onToggle;

  @override
  State<_DiscoverTray> createState() => _DiscoverTrayState();
}

class _DiscoverTrayState extends State<_DiscoverTray> {
  final ScrollController _controller = ScrollController();
  double _dragDy = 0;

  @override
  void didUpdateWidget(covariant _DiscoverTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedKey == null || widget.selectedKey == oldWidget.selectedKey) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final index = widget.items.indexWhere((item) => item.key == widget.selectedKey);
      if (index < 0) return;
      final extent = widget.expanded ? 168.0 : 144.0;
      final target = (index * extent).clamp(0.0, _controller.position.maxScrollExtent);
      _controller.animateTo(
        target.toDouble(),
        duration: const Duration(milliseconds: 250),
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
    final label = widget.city.trim().isEmpty ? 'nearby' : widget.city.trim();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) => _dragDy = 0,
      onVerticalDragUpdate: (details) => _dragDy += details.delta.dy,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final signal = velocity.abs() > 180 ? velocity : _dragDy * 14;
        if (signal < -160) widget.onDragUp();
        if (signal > 160) widget.onDragDown();
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFAFFFFFF),
          borderRadius: BorderRadius.circular(21),
          boxShadow: const [
            BoxShadow(color: Color(0x30000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 10, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.items.length} new in $label',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w850,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: widget.onSeeAll,
                        child: Text(
                          'See all',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF147DFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Icon(
                        widget.expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: widget.items.isEmpty
                    ? Center(
                        child: Text(
                          'You have discovered everything here for now.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black45,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w650,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _controller,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                        itemCount: widget.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          return _DiscoveryCard(
                            item: item,
                            selected: item.key == widget.selectedKey,
                            expanded: widget.expanded,
                            onSelect: () => widget.onSelect(item),
                            onOpen: () => widget.onOpen(item),
                            onLike: () => widget.onLike(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    required this.onOpen,
    required this.onLike,
  });

  final _MapItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final width = expanded ? 160.0 : 136.0;
    return GestureDetector(
      onTap: selected ? onOpen : onSelect,
      onDoubleTap: onOpen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF7F8FA) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, 4))]
              : const [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: expanded ? 100 : 68,
                    width: double.infinity,
                    child: item.imageUrl.trim().isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _KindPlaceholder(kind: item.kind),
                          )
                        : _KindPlaceholder(kind: item.kind),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w850,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black45,
                              fontSize: 8.8,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (expanded && item.price.trim().isNotEmpty) ...[
                            const Spacer(),
                            Text(
                              item.price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.black87,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.kind.color.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    item.kind.tag,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 7.2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .35,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 3,
                top: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLike,
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.favorite_border_rounded,
                      color: Colors.white,
                      size: 19,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
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

class _KindPlaceholder extends StatelessWidget {
  const _KindPlaceholder({required this.kind});
  final _MapKind kind;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF0F2F5),
      child: Center(child: Icon(kind.icon, color: kind.color, size: 30)),
    );
  }
}
