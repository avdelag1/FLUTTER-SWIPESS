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
import 'package:flutter_swipes/src/features/map/data/mapbox_place_search.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin_cluster.dart';
import 'package:flutter_swipes/src/features/map/domain/map_presence_status.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_friends_tray.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_status_sheet.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_visibility_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/utils/map_photo_pin_bitmap.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_chips.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_visibility_pill.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_visibility_sheet.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:geolocator/geolocator.dart' hide Position, LocationSettings;
import 'package:geolocator/geolocator.dart' as geo show LocationSettings;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

const _swipessBuildSha = String.fromEnvironment(
  'SWIPESS_BUILD_SHA',
  defaultValue: 'unknown',
);
const _swipessBuildNumber = String.fromEnvironment(
  'SWIPESS_BUILD_NUMBER',
  defaultValue: 'unknown',
);
const _swipessBuildChannel = String.fromEnvironment(
  'SWIPESS_BUILD_CHANNEL',
  defaultValue: 'local',
);

/// Native Mapbox discovery UI for iOS/Android.
/// Compact, borderless, searchable and state-preserving.
class RealMapboxScreenV3 extends ConsumerStatefulWidget {
  const RealMapboxScreenV3({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
    this.onMapReady,
    this.playIntro = false,
    this.onIntroComplete,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;
  final VoidCallback? onMapReady;
  final bool playIntro;
  final VoidCallback? onIntroComplete;

  @override
  ConsumerState<RealMapboxScreenV3> createState() => _RealMapboxScreenV3State();
}

enum _Kind { event, property, service, moto, bike, yacht, person }

extension _KindUi on _Kind {
  Color get color => switch (this) {
    _Kind.event => const Color(0xFF8B5CF6),
    _Kind.property => const Color(0xFF0F9F8F),
    _Kind.service => const Color(0xFFE84D68),
    _Kind.moto => const Color(0xFFFF7A18),
    _Kind.bike => const Color(0xFF20A85A),
    _Kind.yacht => const Color(0xFF147DFF),
    _Kind.person => const Color(0xFF6557E8),
  };

  IconData get icon => switch (this) {
    _Kind.event => Icons.music_note_rounded,
    _Kind.property => Icons.home_rounded,
    _Kind.service => Icons.room_service_rounded,
    _Kind.moto => Icons.two_wheeler_rounded,
    _Kind.bike => Icons.pedal_bike_rounded,
    _Kind.yacht => Icons.sailing_rounded,
    _Kind.person => Icons.person_rounded,
  };

  String get label => switch (this) {
    _Kind.event => 'EVENT',
    _Kind.property => 'PROPERTY',
    _Kind.service => 'SERVICE',
    _Kind.moto => 'MOTO',
    _Kind.bike => 'BIKE',
    _Kind.yacht => 'YACHT',
    _Kind.person => 'PERSON',
  };

  String get aliases => switch (this) {
    _Kind.event => 'event events party music nightlife',
    _Kind.property => 'property properties home house apartment rent sale',
    _Kind.service =>
      'service services worker chef massage cleaning dining restaurant',
    _Kind.moto => 'motorcycle motorbike moto scooter',
    _Kind.bike => 'bicycle bike bikes ebike',
    _Kind.yacht => 'yacht yachts boat',
    _Kind.person => 'person people profile member roommate',
  };
}

class _Item {
  const _Item({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.price,
    this.listing,
    this.profile,
    this.event,
  });

  final String id;
  final _Kind kind;
  final double lat;
  final double lng;
  final String title;
  final String subtitle;
  final String image;
  final String price;
  final Listing? listing;
  final Profile? profile;
  final Event? event;

  String get key => '${kind.name}:$id';
}

class _RealMapboxScreenV3State extends ConsumerState<RealMapboxScreenV3> {
  MapboxMap? _map;
  PointAnnotationManager? _pins;
  PointAnnotationManager? _userPin;
  PolygonAnnotationManager? _radius;
  final Map<_Kind, Uint8List> _pinImages = {};
  final Map<String, Uint8List> _itemPinImages = {};
  Uint8List? _userImage;

  bool _loaded = false;
  bool _uiReady = false;
  late bool _introComplete;
  bool _introFlightStarted = false;
  Completer<void>? _introFlightIdle;
  bool _readySent = false;
  bool _menu = false;
  bool _search = false;
  bool _cities = false;
  bool _controls = true;
  int _tray = 0; // -1 hidden, 0 compact, 1 expanded
  String _filter = 'all';
  String _query = '';
  String? _selected;
  double? _userLat;
  double? _userLng;
  int _renderGeneration = 0;
  Timer? _renderDebounce;
  final Set<String> _hidden = {};
  Set<String>? _clusterFilterKeys;
  final Map<String, MapPinCluster<_Item>> _clusterByHeadKey = {};

  @override
  void dispose() {
    _renderDebounce?.cancel();
    super.dispose();
  }

  void _scheduleRender() {
    _renderDebounce?.cancel();
    _renderDebounce = Timer(const Duration(milliseconds: 140), () {
      if (mounted) unawaited(_render());
    });
  }

  @override
  void initState() {
    super.initState();
    _introComplete = !widget.playIntro;
    _cities = widget.showCitiesOnOpen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshGps());
    });
  }

  Point _point(double lat, double lng) =>
      Point(coordinates: Position(lng, lat));

  double _zoom(int km) {
    if (km <= 5) return 13.8;
    if (km <= 10) return 12.9;
    if (km <= 25) return 11.8;
    if (km <= 50) return 10.8;
    if (km <= 100) return 9.8;
    if (km <= 250) return 8.6;
    if (km <= 1000) return 6;
    if (km <= 5000) return 3.4;
    return 1.6;
  }

  double _pitch(int km) =>
      km <= 10 ? 42 : (km <= 50 ? 30 : (km <= 250 ? 16 : 0));

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    final loc = ref.read(discoveryLocationProvider);
    try {
      await map.setCamera(
        CameraOptions(
          center: widget.playIntro
              ? _point(20, -20)
              : _point(loc.latitude, loc.longitude),
          zoom: widget.playIntro ? .48 : _zoom(loc.radiusKm),
          pitch: widget.playIntro ? 0 : _pitch(loc.radiusKm),
          bearing: widget.playIntro ? -12 : (loc.radiusKm <= 50 ? 10 : 0),
        ),
      );
    } catch (_) {}
  }

  Future<void> _playIntro() async {
    if (!widget.playIntro || _introComplete) return;
    final map = _map;
    if (map == null) return;

    // Let the fully rendered round Earth breathe before the cinematic zoom.
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;

    final loc = ref.read(discoveryLocationProvider);
    try {
      _introFlightIdle = Completer<void>();
      _introFlightStarted = true;
      await map.flyTo(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: _zoom(loc.radiusKm),
          pitch: _pitch(loc.radiusKm),
          bearing: loc.radiusKm <= 50 ? 10 : 0,
        ),
        MapAnimationOptions(duration: 7800, startDelay: 0),
      );
      await _introFlightIdle!.future.timeout(
        const Duration(milliseconds: 8600),
        onTimeout: () {},
      );
    } catch (_) {
      try {
        await map.setCamera(
          CameraOptions(
            center: _point(loc.latitude, loc.longitude),
            zoom: _zoom(loc.radiusKm),
            pitch: _pitch(loc.radiusKm),
            bearing: loc.radiusKm <= 50 ? 10 : 0,
          ),
        );
      } catch (_) {}
    }

    if (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  void _onMapIdle() {
    final arrival = _introFlightIdle;
    if (_introFlightStarted && arrival != null && !arrival.isCompleted) {
      arrival.complete();
    }
  }

  Future<void> _onLoaded() async {
    if (mounted) {
      setState(() => _loaded = true);
    } else {
      _loaded = true;
    }
    final map = _map;
    if (map == null) return;
    final intro = _playIntro();
    _radius ??= await map.annotations.createPolygonAnnotationManager();
    _pins ??= await map.annotations.createPointAnnotationManager();
    _userPin ??= await map.annotations.createPointAnnotationManager();
    for (final kind in _Kind.values) {
      _pinImages[kind] ??= await _makePin(kind);
    }
    _userImage ??= await _makeUserPin();
    _pins?.tapEvents(
      onTap: (annotation) {
        final p = annotation.geometry.coordinates;
        _selectNearest(p.lat.toDouble(), p.lng.toDouble());
      },
    );
    await intro;
    if (!mounted) return;
    final completedIntroNow = !_introComplete;
    setState(() {
      _introComplete = true;
      _uiReady = true;
    });
    if (completedIntroNow) {
      widget.onIntroComplete?.call();
    }
    if (!_readySent) {
      _readySent = true;
      widget.onMapReady?.call();
    }
    await _render();
    if (mounted) unawaited(_refreshGps());
  }

  Future<void> _refreshGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      await _render();
    } catch (_) {}
  }

  Future<void> _recenter() async {
    if (_userLat == null || _userLng == null) await _refreshGps();
    final map = _map;
    if (map == null || _userLat == null || _userLng == null) return;
    try {
      await map.flyTo(
        CameraOptions(
          center: _point(_userLat!, _userLng!),
          zoom: 14.7,
          pitch: 42,
          bearing: 12,
        ),
        MapAnimationOptions(duration: 520, startDelay: 0),
      );
    } catch (_) {}
  }

  Future<void> _flyToLocation(DiscoveryLocation loc) async {
    final map = _map;
    if (map == null) return;
    try {
      await map.flyTo(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: _zoom(loc.radiusKm),
          pitch: _pitch(loc.radiusKm),
          bearing: loc.radiusKm <= 50 ? 10 : 0,
        ),
        MapAnimationOptions(duration: 900, startDelay: 0),
      );
    } catch (_) {}
  }

  Future<Uint8List> _makePin(_Kind kind) async {
    // Render at 192px (@1.5x the previous 128px) so pins stay crisp and
    // readable on iPhone Retina at the wide zoom levels used by the globe.
    const size = 192.0;
    const center = ui.Offset(96, 84);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawCircle(
      center.translate(0, 7),
      64,
      ui.Paint()
        ..color = kind.color.withAlpha(58)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14),
    );
    canvas.drawCircle(center, 60, ui.Paint()..color = Colors.white);
    canvas.drawCircle(center, 52, ui.Paint()..color = kind.color);
    canvas.drawCircle(
      center.translate(-15, -16),
      19,
      ui.Paint()..color = Colors.white.withAlpha(42),
    );

    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(kind.icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 43,
          fontWeight: FontWeight.w600,
          fontFamily: kind.icon.fontFamily,
          package: kind.icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      ui.Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  }

  Future<Uint8List> _makeUserPin() async {
    const size = 114.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const c = ui.Offset(57, 57);
    canvas.drawCircle(c, 40, ui.Paint()..color = const Color(0x24147DFF));
    canvas.drawCircle(c, 25, ui.Paint()..color = Colors.white);
    canvas.drawCircle(c, 18, ui.Paint()..color = const Color(0xFF147DFF));
    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  }

  ({double lat, double lng}) _spread(
    String key,
    double lat,
    double lng, {
    double meters = 100,
  }) {
    var hash = 137;
    for (final unit in key.codeUnits) hash = 0x1fffffff & (hash * 31 + unit);
    final angle = (hash % 360) * math.pi / 180;
    final distance = meters + ((hash ~/ 360) % 7) * 36;
    final latDelta = distance / 111320;
    final cosLat = math.cos(lat * math.pi / 180).abs();
    final lngDelta = distance / (111320 * (cosLat < .25 ? .25 : cosLat));
    return (
      lat: lat + math.sin(angle) * latDelta,
      lng: lng + math.cos(angle) * lngDelta,
    );
  }

  ({double lat, double lng}) _cityPoint(
    String key,
    String? city,
    DiscoveryLocation loc,
  ) {
    final cityLoc = ListingLocations.resolve(city ?? '');
    return _spread(
      key,
      cityLoc?.lat ?? loc.latitude,
      cityLoc?.lng ?? loc.longitude,
      meters: 350,
    );
  }

  _Kind _listingKind(Listing listing) {
    switch ((listing.category ?? '').toLowerCase().trim()) {
      case 'worker':
      case 'service':
      case 'restaurant':
      case 'dining':
        return _Kind.service;
      case 'motorcycle':
      case 'moto':
        return _Kind.moto;
      case 'bicycle':
      case 'bike':
        return _Kind.bike;
      case 'yacht':
      case 'boat':
        return _Kind.yacht;
      default:
        return _Kind.property;
    }
  }

  _Item _listingItem(Listing listing, DiscoveryLocation loc) {
    final p = listing.latitude != null && listing.longitude != null
        ? _spread(listing.id, listing.latitude!, listing.longitude!)
        : _cityPoint(listing.id, listing.city, loc);
    return _Item(
      id: listing.id,
      kind: _listingKind(listing),
      lat: p.lat,
      lng: p.lng,
      title: (listing.title ?? '').trim().isEmpty
          ? 'Swipess listing'
          : listing.title!.trim(),
      subtitle: listing.formattedLocation,
      image: listing.primaryImage ?? '',
      price: listing.formattedPrice,
      listing: listing,
    );
  }

  _Item _profileItem(Profile profile, DiscoveryLocation loc) {
    final p = profile.latitude != null && profile.longitude != null
        ? _spread(profile.id, profile.latitude!, profile.longitude!)
        : _cityPoint(profile.id, profile.city, loc);
    return _Item(
      id: profile.id,
      kind: _Kind.person,
      lat: p.lat,
      lng: p.lng,
      title: profile.displayName,
      subtitle: profile.city ?? 'Nearby',
      image: profile.avatarUrl ?? '',
      price: profile.role ?? '',
      profile: profile,
    );
  }

  _Item _eventItem(Event event, DiscoveryLocation loc) {
    final ({double lat, double lng}) point;
    if (event.latitude != null && event.longitude != null) {
      point = (lat: event.latitude!, lng: event.longitude!);
    } else {
      final resolved = ListingLocations.resolve(event.location ?? '');
      point = _spread(
        'event:${event.id}',
        resolved?.lat ?? loc.latitude,
        resolved?.lng ?? loc.longitude,
        meters: 180,
      );
    }
    return _Item(
      id: event.id,
      kind: _Kind.event,
      lat: point.lat,
      lng: point.lng,
      title: event.title,
      subtitle: event.location ?? event.locationDetail ?? loc.city,
      image:
          event.imageUrl ??
          (event.imageUrls.isNotEmpty ? event.imageUrls.first : ''),
      price: event.price,
      event: event,
    );
  }

  bool _eventInCity(Event event, DiscoveryLocation loc) {
    if (loc.radiusKm >= 500) return true;
    final city = loc.city.trim().toLowerCase();
    if (city.isEmpty || city == 'near you') return true;
    final text = '${event.location ?? ''} ${event.locationDetail ?? ''}'
        .toLowerCase();
    return text.trim().isEmpty || text.contains(city);
  }

  bool _filterItem(_Item item) {
    final categoryMatch = switch (_filter) {
      'events' => item.kind == _Kind.event,
      'properties' => item.kind == _Kind.property,
      'services' => item.kind == _Kind.service,
      'yachts' => item.kind == _Kind.yacht,
      'motos' => item.kind == _Kind.moto,
      'bikes' => item.kind == _Kind.bike,
      'people' => item.kind == _Kind.person,
      _ => true,
    };
    if (!categoryMatch) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final text =
        '${item.title} ${item.subtitle} ${item.price} ${item.kind.label} ${item.kind.aliases}'
            .toLowerCase();
    return q
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .every(text.contains);
  }

  List<_Item> _items() {
    final loc = ref.read(discoveryLocationProvider);
    final listings = ref.read(mapListingsProvider).value ?? const <Listing>[];
    final profiles = ref.read(mapProfilesProvider).value ?? const <Profile>[];
    final events = ref.read(eventsListProvider).value ?? const <Event>[];
    final listingExclusions = ref.read(mapExcludedListingIdsProvider);
    final peopleExclusions = ref.read(mapExcludedPeopleIdsProvider);
    final eventExclusions = ref.read(mapExcludedEventIdsProvider);

    return <_Item>[
          for (final l in listings)
            if (!listingExclusions.unresolved &&
                !listingExclusions.ids.contains(l.id))
              _listingItem(l, loc),
          for (final p in profiles)
            if (!peopleExclusions.unresolved &&
                !peopleExclusions.ids.contains(p.id))
              _profileItem(p, loc),
          for (final e in events)
            if (!eventExclusions.unresolved &&
                _eventInCity(e, loc) &&
                !eventExclusions.ids.contains(e.id))
              _eventItem(e, loc),
        ]
        .where((i) => !_hidden.contains(i.key) && _filterItem(i))
        .toList(growable: false);
  }

  List<_Item> _trayItems(List<_Item> source) {
    final keys = _clusterFilterKeys;
    if (keys == null || keys.isEmpty) return source;
    return source.where((item) => keys.contains(item.key)).toList(growable: false);
  }

  List<MapPinCluster<_Item>> _clustersFor(List<_Item> items) {
    _clusterByHeadKey.clear();
    final clusters = MapPinClustering.cluster(
      items: items,
      latOf: (item) => item.lat,
      lngOf: (item) => item.lng,
    );
    for (final cluster in clusters) {
      _clusterByHeadKey[cluster.head.key] = cluster;
    }
    return clusters;
  }

  void _openFriendsTray(List<_Item> items) {
    final profiles = items
        .map((item) => item.profile)
        .whereType<Profile>()
        .toList(growable: false);
    MapFriendsTray.show(
      context,
      profiles: profiles,
      onSelect: (profile) {
        for (final item in items) {
          if (item.profile?.id == profile.id) {
            _selectNearest(item.lat, item.lng);
            return;
          }
        }
      },
      onShareBack: () {
        unawaited(ref.read(mapVisibilityProvider.notifier).setVisible(true));
      },
    );
  }

  Polygon _radiusPolygon(DiscoveryLocation loc) {
    final latDelta = loc.radiusKm / 111.32;
    final cosLat = math.cos(loc.latitude * math.pi / 180).abs();
    final lngDelta = loc.radiusKm / (111.32 * (cosLat < .25 ? .25 : cosLat));
    final ring = <Position>[];
    for (var i = 0; i <= 64; i++) {
      final a = 2 * math.pi * i / 64;
      ring.add(
        Position(
          loc.longitude + math.cos(a) * lngDelta,
          loc.latitude + math.sin(a) * latDelta,
        ),
      );
    }
    return Polygon(coordinates: [ring]);
  }

  Future<void> _render() async {
    if (!_uiReady || _pins == null || _userPin == null || _radius == null)
      return;
    final generation = ++_renderGeneration;
    final items = _items();
    final clusters = _clustersFor(items);
    final loc = ref.read(discoveryLocationProvider);
    try {
      await Future.wait([
        _pins!.deleteAll(),
        _userPin!.deleteAll(),
        _radius!.deleteAll(),
      ]);
      if (!mounted || generation != _renderGeneration) return;
      if (loc.radiusKm <= 250) {
        await _radius!.create(
          PolygonAnnotationOptions(
            geometry: _radiusPolygon(loc),
            fillColor: const Color(0xFF147DFF).toARGB32(),
            fillOpacity: .07,
            fillOutlineColor: const Color(0xFF147DFF).toARGB32(),
          ),
        );
      }
      if (_userLat != null && _userLng != null && _userImage != null) {
        await _userPin!.create(
          PointAnnotationOptions(
            geometry: _point(_userLat!, _userLng!),
            image: _userImage,
            iconSize: 1.2,
            symbolSortKey: 10000,
          ),
        );
      }
      final annotations = <PointAnnotationOptions>[];
      for (final cluster in clusters) {
        final item = cluster.head;
        final selected = item.key == _selected;
        final pinCacheKey = '${item.key}|${cluster.extraCount}|$selected';
        final status = item.profile?.mapStatus;
        final statusIcon = MapPresenceStatus.resolve(status)?.icon;
        _itemPinImages[pinCacheKey] ??= await MapPhotoPinBitmap.build(
          cacheKey: item.key,
          imageUrl: item.image.trim().isEmpty ? null : item.image,
          ringColor: item.kind.color,
          fallbackIcon: item.kind.icon,
          selected: selected,
          extraCount: cluster.extraCount,
          statusIcon: statusIcon,
        );
        annotations.add(
          PointAnnotationOptions(
            geometry: _point(cluster.lat, cluster.lng),
            image: _itemPinImages[pinCacheKey],
            iconSize: selected ? 1.62 : 1.42,
            symbolSortKey: selected ? 9000 : 5000,
          ),
        );
      }
      if (annotations.isNotEmpty) await _pins!.createMulti(annotations);
    } catch (_) {}
  }

  _Item? get _selectedItem {
    if (_selected == null) return null;
    for (final item in _items()) {
      if (item.key == _selected) return item;
    }
    return null;
  }

  void _dismissOverlays() {
    if (!_menu && !_cities && !_search && _selected == null && _tray != 1) {
      return;
    }
    setState(() {
      _menu = false;
      _cities = false;
      _search = false;
      _selected = null;
      if (_tray == 1) _tray = 0;
    });
    unawaited(_render());
  }

  void _selectNearest(double lat, double lng) {
    final items = _items();
    final clusters = _clustersFor(items);
    MapPinCluster<_Item>? bestCluster;
    var bestDistance = double.infinity;
    for (final cluster in clusters) {
      final d =
          math.pow(cluster.lat - lat, 2) + math.pow(cluster.lng - lng, 2);
      if (d < bestDistance) {
        bestDistance = d.toDouble();
        bestCluster = cluster;
      }
    }
    final best = bestCluster?.head;
    if (best == null || bestCluster == null) return;
    if (_selected == best.key && bestCluster.extraCount > 0) {
      AppHaptics.selection();
      setState(() {
        _clusterFilterKeys = bestCluster!.items.map((e) => e.key).toSet();
        _tray = 1;
      });
      return;
    }
    if (_selected == best.key) {
      _openItem(best);
      return;
    }
    AppHaptics.selection();
    setState(() {
      _selected = best.key;
      _clusterFilterKeys = null;
      _menu = false;
      _cities = false;
      if (_tray < 0) _tray = 0;
    });
    unawaited(_render());
    unawaited(
      _map?.easeTo(
        CameraOptions(
          center: _point(best.lat, best.lng),
          zoom: 14.4,
          pitch: 40,
          bearing: 10,
          padding: MbxEdgeInsets(bottom: 190, left: 0, top: 0, right: 0),
        ),
        MapAnimationOptions(duration: 520, startDelay: 0),
      ),
    );
  }

  void _openItem(_Item item) {
    AppHaptics.medium();
    if (item.event != null) {
      context.push(AppPaths.exploreEvent(item.id));
    } else if (item.listing != null) {
      context.push(AppPaths.listing(item.id));
    } else {
      context.push(AppPaths.profile(item.id));
    }
  }

  Future<void> _save(_Item item) async {
    try {
      final repo = ref.read(likesRepositoryProvider);
      if (item.listing != null) {
        await repo.likeListing(item.id);
        ref.invalidate(likedListingsProvider);
        ref.invalidate(likedListingIdsProvider);
        ref.invalidate(mapListingsProvider);
      } else if (item.profile != null) {
        await repo.likePerson(item.id);
        ref.invalidate(likedPeopleProvider);
        ref.invalidate(likedPeopleIdsProvider);
        ref.invalidate(mapProfilesProvider);
      } else {
        await repo.likeEvent(item.id);
        ref.invalidate(likedEventIdsProvider);
      }
      if (!mounted) return;
      setState(() {
        _hidden.add(item.key);
        if (_selected == item.key) _selected = null;
      });
      unawaited(_render());
      ref
          .read(appNotificationsProvider.notifier)
          .show(
            title: 'Saved to Likes',
            message: '${item.title} is now in your Likes.',
            type: AppToastType.like,
          );
    } catch (_) {
      if (mounted) {
        ref
            .read(appNotificationsProvider.notifier)
            .error('Could not save this yet', 'Please try again in a moment.');
      }
    }
  }

  void _setFilter(String value) {
    setState(() {
      _filter = value;
      _selected = null;
    });
    unawaited(_render());
  }

  Future<void> _submitSearch(String value) async {
    final q = value.trim();
    if (q.isEmpty) return;
    final city = ListingLocations.resolve(q);
    if (city != null) {
      ref
          .read(discoveryLocationProvider.notifier)
          .setCoordinates(
            city: q,
            country: city.country,
            latitude: city.lat,
            longitude: city.lng,
          );
      if (ref.read(discoveryLocationProvider).radiusKm > 250) {
        ref.read(discoveryLocationProvider.notifier).setRadiusKm(25);
      }
      if (mounted) setState(() => _search = false);
      return;
    }

    final results = await MapboxPlaceSearch.search(q);
    if (!mounted) return;
    if (results.isNotEmpty) {
      final result = results.first;
      ref
          .read(discoveryLocationProvider.notifier)
          .setCoordinates(
            city: result.name,
            country: result.country,
            latitude: result.latitude,
            longitude: result.longitude,
          );
      ref
          .read(discoveryLocationProvider.notifier)
          .setRadiusKm(result.suggestedRadiusKm);
      setState(() {
        _search = false;
        _query = '';
        _selected = null;
      });
      return;
    }

    setState(() => _query = q);
    await _render();
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
    ref.watch(mapExcludedListingIdsProvider);
    ref.watch(mapExcludedPeopleIdsProvider);
    ref.watch(mapExcludedEventIdsProvider);

    ref.listen(discoveryLocationProvider, (oldValue, next) {
      if (oldValue == null ||
          oldValue.latitude != next.latitude ||
          oldValue.longitude != next.longitude ||
          oldValue.radiusKm != next.radiusKm) {
        _selected = null;
        unawaited(_flyToLocation(next));
        _scheduleRender();
      }
    });
    ref.listen(mapListingsProvider, (_, __) => _scheduleRender());
    ref.listen(mapProfilesProvider, (_, __) => _scheduleRender());
    ref.listen(eventsListProvider, (_, __) => _scheduleRender());
    ref.listen(mapExcludedListingIdsProvider, (_, __) => _scheduleRender());
    ref.listen(mapExcludedPeopleIdsProvider, (_, __) => _scheduleRender());
    ref.listen(mapExcludedEventIdsProvider, (_, __) => _scheduleRender());

    final items = _items();
    final trayItems = _trayItems(items);
    final selected = _selectedItem;
    final pad = MediaQuery.paddingOf(context);
    final height = MediaQuery.sizeOf(context).height;
    final compact = math.min(150.0 + pad.bottom, height * .23);
    final expanded = math.min(295.0 + pad.bottom, height * .42);
    final trayHeight = _tray < 0 ? 0.0 : (_tray == 0 ? compact : expanded);

    return Material(
      color: const Color(0xFF06182B),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          MapWidget(
            key: const ValueKey('swipess-native-mapbox-v3'),
            styleUri: MapboxStyles.STANDARD,
            onMapCreated: _onMapCreated,
            onMapLoadedListener: (_) => unawaited(_onLoaded()),
            onMapIdleListener: (_) => _onMapIdle(),
          ),
          if (!_loaded)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF06182B),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF4D78),
                  ),
                ),
              ),
            ),
          if (_uiReady)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 125,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xDFFFFFFF),
                        Color(0x72FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_uiReady && _controls) ...[
            if (_menu || _cities || _search || _selected != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _dismissOverlays,
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              top: pad.top + 4,
              left: 7,
              right: 7,
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  const SizedBox(width: 2),
                  _IconOnly(
                    icon: _menu ? Icons.close_rounded : Icons.menu_rounded,
                    label: 'Map menu',
                    onTap: () => setState(() {
                      _menu = !_menu;
                      _cities = false;
                    }),
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
                  _IconOnly(
                    icon: _search ? Icons.close_rounded : Icons.search_rounded,
                    label: 'Search map',
                    onTap: () => setState(() {
                      _search = !_search;
                      _menu = false;
                      _cities = false;
                    }),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Positioned(
              top: pad.top + 78,
              left: 0,
              right: 0,
              child: Center(
                child: MapVisibilityPill(
                  onTap: () => MapVisibilitySheet.show(context),
                ),
              ),
            ),
            Positioned(
              top: pad.top + 118,
              left: 0,
              right: 0,
              child: _Filters(active: _filter, onTap: _setFilter),
            ),
            if (_search)
              Positioned(
                top: pad.top + 84,
                left: 12,
                right: 12,
                child: _Search(
                  initial: _query,
                  onChanged: (v) {
                    setState(() {
                      _query = v;
                      _selected = null;
                    });
                    unawaited(_render());
                  },
                  onSubmit: _submitSearch,
                  onClear: () {
                    setState(() => _query = '');
                    unawaited(_render());
                  },
                ),
              ),
            if (_menu)
              Positioned(
                top: pad.top + 39,
                left: 9,
                child: _Menu(
                  trayVisible: _tray >= 0,
                  onCities: () => setState(() {
                    _cities = true;
                    _menu = false;
                    _search = false;
                  }),
                  onGps: () {
                    setState(() => _menu = false);
                    unawaited(_recenter());
                  },
                  onFriends: () {
                    setState(() => _menu = false);
                    _openFriendsTray(items);
                  },
                  onStatus: () {
                    setState(() => _menu = false);
                    MapStatusSheet.show(context);
                  },
                  onVisibility: () {
                    setState(() => _menu = false);
                    MapVisibilitySheet.show(context);
                  },
                  onTray: () => setState(() {
                    _tray = _tray >= 0 ? -1 : 0;
                    _menu = false;
                  }),
                  onHide: () => setState(() {
                    _controls = false;
                    _menu = false;
                  }),
                  onClose: _closeMap,
                ),
              ),
            if (_cities)
              Positioned(
                top: pad.top + 84,
                left: 0,
                right: 0,
                child: MapCityChips(
                  activeCity: loc.city,
                  onSelect: (city) {
                    ref
                        .read(discoveryLocationProvider.notifier)
                        .setCoordinates(
                          city: city.name,
                          country: city.country,
                          latitude: city.lat,
                          longitude: city.lng,
                        );
                    setState(() => _cities = false);
                  },
                ),
              ),
          ] else if (_uiReady)
            Positioned(
              top: pad.top + 7,
              right: 7,
              child: _IconOnly(
                icon: Icons.visibility_rounded,
                label: 'Show controls',
                onTap: () => setState(() => _controls = true),
              ),
            ),
          if (_loaded && !_uiReady) ...[
            Positioned(
              top: pad.top + 4,
              left: 7,
              child: _IconOnly(
                icon: Icons.arrow_back_ios_new_rounded,
                label: 'Back',
                onTap: _closeMap,
              ),
            ),
            Positioned(
              top: pad.top + 78,
              left: 0,
              right: 0,
              child: Center(
                child: MapVisibilityPill(
                  onTap: () => MapVisibilitySheet.show(context),
                ),
              ),
            ),
          ],
          if (_uiReady) ...[
            Positioned(
              top: pad.top + 4,
              left: 7,
              child: _IconOnly(
                icon: Icons.arrow_back_ios_new_rounded,
                label: 'Back',
                onTap: _closeMap,
              ),
            ),
            Positioned(
              left: 7,
              bottom: trayHeight + pad.bottom + 11,
              child: _IconOnly(
                icon: Icons.people_alt_rounded,
                label: 'Nearby friends',
                onTap: () => _openFriendsTray(items),
              ),
            ),
            Positioned(
              right: 7,
              bottom: trayHeight + pad.bottom + 11,
              child: _IconOnly(
                icon: Icons.my_location_rounded,
                label: 'My exact location',
                onTap: _recenter,
              ),
            ),
          ],
          if (_uiReady && selected != null && _tray >= 0)
            Positioned(
              left: 13,
              right: 13,
              bottom: trayHeight + 10,
              child: _Preview(
                item: selected,
                onOpen: () => _openItem(selected),
                onSave: () => unawaited(_save(selected)),
                onClose: () {
                  setState(() => _selected = null);
                  unawaited(_render());
                },
              ),
            ),
          if (_uiReady)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutCubic,
              left: 8,
              right: 8,
              bottom: _tray < 0 ? -220 : 8,
              height: _tray < 0 ? compact : trayHeight,
              child: _Tray(
                items: trayItems,
                city: loc.city,
                selected: _selected,
                expanded: _tray == 1,
                onSelect: (item) => _selectNearest(item.lat, item.lng),
                onOpen: _openItem,
                onSave: (item) => unawaited(_save(item)),
                onUp: () => setState(() => _tray = 1),
                onDown: () => setState(() => _tray = _tray == 1 ? 0 : -1),
                onToggle: () => setState(() => _tray = _tray == 1 ? 0 : 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconOnly extends StatelessWidget {
  const _IconOnly({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 34,
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF111318),
          shadows: const [Shadow(color: Color(0x66FFFFFF), blurRadius: 4)],
        ),
      ),
    ),
  );
}

class _FilterData {
  const _FilterData(this.id, this.text, this.icon);
  final String id;
  final String text;
  final IconData icon;
}

const _filterData = <_FilterData>[
  _FilterData('all', 'All', Icons.grid_view_rounded),
  _FilterData('events', 'Events', Icons.local_activity_rounded),
  _FilterData('properties', 'Properties', Icons.home_rounded),
  _FilterData('services', 'Services', Icons.room_service_rounded),
  _FilterData('yachts', 'Yachts', Icons.sailing_rounded),
  _FilterData('motos', 'Motos', Icons.two_wheeler_rounded),
  _FilterData('bikes', 'Bikes', Icons.pedal_bike_rounded),
  _FilterData('people', 'People', Icons.person_rounded),
];

class _Filters extends StatelessWidget {
  const _Filters({required this.active, required this.onTap});
  final String active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0, .025, .975, 1],
      ).createShader(r),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filterData.length,
        separatorBuilder: (_, __) => const SizedBox(width: 3),
        itemBuilder: (_, i) {
          final f = _filterData[i];
          final selected = f.id == active;
          return GestureDetector(
            onTap: () => onTap(f.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xF2111317)
                    : const Color(0xDFFFFFFF),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 7,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f.icon,
                    size: 12.5,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    f.text,
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

class _Search extends StatefulWidget {
  const _Search({
    required this.initial,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  });
  final String initial;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 43,
    decoration: BoxDecoration(
      color: const Color(0xF5FFFFFF),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x23000000),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit,
      style: GoogleFonts.plusJakartaSans(
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
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: Colors.black54,
        ),
        suffixIcon: GestureDetector(
          onTap: () {
            controller.clear();
            widget.onClear();
          },
          child: const Icon(
            Icons.close_rounded,
            size: 17,
            color: Colors.black45,
          ),
        ),
      ),
    ),
  );
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.trayVisible,
    required this.onCities,
    required this.onGps,
    required this.onFriends,
    required this.onStatus,
    required this.onVisibility,
    required this.onTray,
    required this.onHide,
    required this.onClose,
  });
  final bool trayVisible;
  final VoidCallback onCities;
  final VoidCallback onGps;
  final VoidCallback onFriends;
  final VoidCallback onStatus;
  final VoidCallback onVisibility;
  final VoidCallback onTray;
  final VoidCallback onHide;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    Widget row(
      IconData icon,
      String text,
      VoidCallback tap, {
      required Color accent,
    }) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withAlpha(28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                width: 31,
                height: 31,
                child: Icon(icon, size: 17, color: accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF111318),
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: accent.withAlpha(170),
            ),
          ],
        ),
      ),
    );
    final shortSha = _swipessBuildSha.length > 12
        ? _swipessBuildSha.substring(0, 12)
        : _swipessBuildSha;
    return Container(
      width: 204,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF3F0FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x12000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MAP OPTIONS',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black45,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.15,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          row(
            Icons.location_city_rounded,
            'Choose city',
            onCities,
            accent: const Color(0xFF8B5CF6),
          ),
          row(
            Icons.my_location_rounded,
            'My exact location',
            onGps,
            accent: const Color(0xFF147DFF),
          ),
          row(
            Icons.people_alt_rounded,
            'Nearby friends',
            onFriends,
            accent: const Color(0xFF6557E8),
          ),
          row(
            Icons.emoji_emotions_rounded,
            'Set map status',
            onStatus,
            accent: const Color(0xFF22C55E),
          ),
          row(
            Icons.location_on_rounded,
            'Map visibility',
            onVisibility,
            accent: const Color(0xFF147DFF),
          ),
          row(
            trayVisible
                ? Icons.visibility_off_rounded
                : Icons.view_carousel_rounded,
            trayVisible ? 'Hide discovery tray' : 'Show discovery tray',
            onTray,
            accent: const Color(0xFFE84D68),
          ),
          row(
            Icons.visibility_off_rounded,
            'Hide map controls',
            onHide,
            accent: const Color(0xFFFF7A18),
          ),
          row(
            Icons.close_rounded,
            'Close map',
            onClose,
            accent: const Color(0xFF111318),
          ),
          const Divider(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 2, 11, 7),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$_swipessBuildChannel • build $_swipessBuildNumber • $shortSha',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black45,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.item,
    required this.onOpen,
    required this.onSave,
    required this.onClose,
  });
  final _Item item;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    height: 86,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFAFFFFFF),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x38000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Row(
              children: [
                _Photo(item: item, size: 68),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.kind.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: item.kind.color,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .45,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
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
              ],
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSave,
          child: const SizedBox(
            width: 38,
            height: 58,
            child: Icon(
              Icons.favorite_border_rounded,
              color: Color(0xFFFF375F),
              size: 23,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: const SizedBox(
            width: 34,
            height: 58,
            child: Icon(Icons.close_rounded, color: Colors.black54, size: 18),
          ),
        ),
      ],
    ),
  );
}

class _Tray extends StatefulWidget {
  const _Tray({
    required this.items,
    required this.city,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    required this.onOpen,
    required this.onSave,
    required this.onUp,
    required this.onDown,
    required this.onToggle,
  });
  final List<_Item> items;
  final String city;
  final String? selected;
  final bool expanded;
  final ValueChanged<_Item> onSelect;
  final ValueChanged<_Item> onOpen;
  final ValueChanged<_Item> onSave;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onToggle;

  @override
  State<_Tray> createState() => _TrayState();
}

class _TrayState extends State<_Tray> {
  double drag = 0;

  @override
  Widget build(BuildContext context) {
    final city = widget.city.trim().isEmpty ? 'nearby' : widget.city.trim();
    return GestureDetector(
      onVerticalDragStart: (_) => drag = 0,
      onVerticalDragUpdate: (d) => drag += d.delta.dy,
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        final signal = v.abs() > 180 ? v : drag * 14;
        if (signal < -160) widget.onUp();
        if (signal > 160) widget.onDown();
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFAFFFFFF),
          borderRadius: BorderRadius.circular(21),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              GestureDetector(
                onTap: widget.onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 10, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.items.length} new in $city',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Icon(
                        widget.expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
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
                          'Everything here is already discovered.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black45,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                        itemCount: widget.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final item = widget.items[i];
                          return _Card(
                            item: item,
                            selected: item.key == widget.selected,
                            expanded: widget.expanded,
                            onTap: () => item.key == widget.selected
                                ? widget.onOpen(item)
                                : widget.onSelect(item),
                            onSave: () => widget.onSave(item),
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

class _Card extends StatelessWidget {
  const _Card({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
    required this.onSave,
  });
  final _Item item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: expanded ? 160 : 136,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF7F8FA) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
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
                  child: _Photo(item: item),
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
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
                  item.kind.label,
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
                onTap: onSave,
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

class _Photo extends StatelessWidget {
  const _Photo({required this.item, this.size});
  final _Item item;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final child = item.image.trim().isNotEmpty
        ? Image.network(
            item.image,
            fit: BoxFit.cover,
            cacheWidth: ((size ?? MediaQuery.sizeOf(context).width) * 2)
                .round()
                .clamp(320, 1200),
            errorBuilder: (_, __, ___) => ColoredBox(
              color: const Color(0xFFF0F2F5),
              child: Center(
                child: Icon(item.kind.icon, color: item.kind.color, size: 28),
              ),
            ),
          )
        : ColoredBox(
            color: const Color(0xFFF0F2F5),
            child: Center(
              child: Icon(item.kind.icon, color: item.kind.color, size: 28),
            ),
          );
    if (size == null) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}
