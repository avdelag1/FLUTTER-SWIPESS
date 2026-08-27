import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_place_search.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

bool _webMapboxOpenedThisSession = false;

/// Persistent browser Mapbox discovery.
///
/// Mapbox remains mounted from the globe intro through local discovery. Pins,
/// popup cards, search and the tray are normal Flutter chrome above the map so
/// their z-order is deterministic and a selected popup can never sit behind a
/// later marker.
class WebDiscoveryMapboxV3 extends ConsumerStatefulWidget {
  const WebDiscoveryMapboxV3({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<WebDiscoveryMapboxV3> createState() =>
      _WebDiscoveryMapboxV3State();
}

enum _Kind {
  event,
  property,
  service,
  dining,
  jet,
  yacht,
  motorcycle,
  bicycle,
  roommate,
  seeker,
  buyer,
  renter,
  person,
}

extension _KindUi on _Kind {
  Color get color => switch (this) {
        _Kind.event => const Color(0xFF8B5CF6),
        _Kind.property => const Color(0xFF14B8A6),
        _Kind.service => const Color(0xFFF43F5E),
        _Kind.dining => const Color(0xFFF97316),
        _Kind.jet => const Color(0xFF0EA5E9),
        _Kind.yacht => const Color(0xFF2563EB),
        _Kind.motorcycle => const Color(0xFFFF7A18),
        _Kind.bicycle => const Color(0xFF22C55E),
        _Kind.roommate => const Color(0xFF06B6D4),
        _Kind.seeker => const Color(0xFFEAB308),
        _Kind.buyer => const Color(0xFF2563EB),
        _Kind.renter => const Color(0xFF10B981),
        _Kind.person => const Color(0xFF6366F1),
      };

  IconData get icon => switch (this) {
        _Kind.event => Icons.celebration_rounded,
        _Kind.property => Icons.home_rounded,
        _Kind.service => Icons.handyman_rounded,
        _Kind.dining => Icons.restaurant_rounded,
        _Kind.jet => Icons.flight_rounded,
        _Kind.yacht => Icons.sailing_rounded,
        _Kind.motorcycle => Icons.two_wheeler_rounded,
        _Kind.bicycle => Icons.pedal_bike_rounded,
        _Kind.roommate => Icons.group_rounded,
        _Kind.seeker => Icons.travel_explore_rounded,
        _Kind.buyer => Icons.shopping_bag_rounded,
        _Kind.renter => Icons.key_rounded,
        _Kind.person => Icons.person_rounded,
      };

  String get label => switch (this) {
        _Kind.event => 'EVENT',
        _Kind.property => 'PROPERTY',
        _Kind.service => 'SERVICE',
        _Kind.dining => 'DINING',
        _Kind.jet => 'JET',
        _Kind.yacht => 'YACHT',
        _Kind.motorcycle => 'MOTO',
        _Kind.bicycle => 'BIKE',
        _Kind.roommate => 'ROOMMATE',
        _Kind.seeker => 'SEEKER',
        _Kind.buyer => 'BUYER',
        _Kind.renter => 'RENTER',
        _Kind.person => 'PEOPLE',
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
    required this.detail,
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
  final String detail;
  final Listing? listing;
  final Profile? profile;
  final Event? event;

  String get key => '${kind.name}:$id';
}

class _FilterDef {
  const _FilterDef(this.id, this.title, this.icon);
  final String id;
  final String title;
  final IconData icon;
}

const _filters = <_FilterDef>[
  _FilterDef('all', 'All', Icons.grid_view_rounded),
  _FilterDef('events', 'Events', Icons.celebration_outlined),
  _FilterDef('properties', 'Properties', Icons.home_outlined),
  _FilterDef('services', 'Services', Icons.handyman_outlined),
  _FilterDef('dining', 'Dining', Icons.restaurant_rounded),
  _FilterDef('jets', 'Jets', Icons.flight_rounded),
  _FilterDef('yachts', 'Yachts', Icons.sailing_rounded),
  _FilterDef('motorcycles', 'Motos', Icons.two_wheeler_rounded),
  _FilterDef('bicycles', 'Bikes', Icons.pedal_bike_rounded),
  _FilterDef('roommates', 'Roommates', Icons.group_rounded),
  _FilterDef('seekers', 'Seekers', Icons.travel_explore_rounded),
  _FilterDef('buyers', 'Buyers', Icons.shopping_bag_rounded),
  _FilterDef('renters', 'Renters', Icons.key_rounded),
  _FilterDef('people', 'People', Icons.person_rounded),
];

class _WebDiscoveryMapboxV3State extends ConsumerState<WebDiscoveryMapboxV3> {
  static const _lightStyle =
      'mapbox://styles/avdelag123/cmshyf3kh00gw01s9gu3yelwz';

  MapboxMap? _map;
  Timer? _openingTimer;
  bool _mapLoaded = false;
  bool _projectionScheduled = false;
  bool _projecting = false;
  bool _projectionQueued = false;
  bool _openingFlight = false;
  bool _menuOpen = false;
  bool _searchOpen = false;
  bool _searchingPlace = false;
  bool _controlsVisible = true;
  String _filter = 'all';
  String _query = '';
  String? _selectedKey;
  int _trayLevel = 0;
  double? _gpsLat;
  double? _gpsLng;
  Offset? _locationPixel;
  double? _radiusPixels;
  Map<String, Offset> _pixels = const {};

  final _searchController = TextEditingController();
  final _cards = ScrollController();
  final Set<String> _sessionHidden = <String>{};

  double get _trayHeight => switch (_trayLevel) {
        -1 => 0,
        0 => 52,
        _ => 188,
      };

  @override
  void initState() {
    super.initState();
    _openingFlight = !_webMapboxOpenedThisSession;
    _webMapboxOpenedThisSession = true;
    unawaited(_loadGps(silent: true));
  }

  @override
  void dispose() {
    _openingTimer?.cancel();
    _searchController.dispose();
    _cards.dispose();
    super.dispose();
  }

  Point _point(double lat, double lng) =>
      Point(coordinates: Position(lng, lat));

  double _zoomFor(int km) {
    if (km <= 5) return 13.4;
    if (km <= 10) return 12.7;
    if (km <= 25) return 11.7;
    if (km <= 50) return 10.7;
    if (km <= 100) return 9.7;
    if (km <= 250) return 8.3;
    if (km <= 1000) return 6.0;
    if (km <= 5000) return 3.2;
    return 1.45;
  }

  Future<void> _setupMap(MapboxMap map) async {
    _map = map;
    final loc = ref.read(discoveryLocationProvider);
    if (_openingFlight) {
      await map.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(-25, 18)),
          zoom: 1.15,
          pitch: 0,
          bearing: -8,
        ),
      );
    } else {
      await map.setCamera(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: _zoomFor(loc.radiusKm),
          pitch: loc.radiusKm <= 100 ? 46 : 24,
          bearing: -12,
        ),
      );
    }
  }

  Future<void> _flyTo(DiscoveryLocation loc, {int duration = 1700}) async {
    final map = _map;
    if (map == null) return;
    try {
      await map.flyTo(
        CameraOptions(
          center: _point(loc.latitude, loc.longitude),
          zoom: _zoomFor(loc.radiusKm),
          pitch: loc.radiusKm <= 100 ? 46 : 24,
          bearing: -12,
        ),
        MapAnimationOptions(duration: duration, startDelay: 0),
      );
    } catch (_) {}
    _scheduleProjection();
  }

  Future<void> _loadGps({required bool silent}) async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) return;
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied && !silent) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        return;
      }
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.best,
        ),
      );
      if (!mounted) return;
      setState(() {
        _gpsLat = position.latitude;
        _gpsLng = position.longitude;
      });
      _scheduleProjection();
      if (!silent) {
        ref.read(discoveryLocationProvider.notifier).setCoordinates(
              city: 'My Location',
              country: '',
              latitude: position.latitude,
              longitude: position.longitude,
            );
        ref.read(discoveryLocationProvider.notifier).setRadiusKm(10);
      }
    } catch (_) {}
  }

  ({double lat, double lng}) _spread(
    String id,
    double lat,
    double lng, {
    double baseMeters = 80,
  }) {
    var hash = 137;
    for (final unit in id.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final meters = baseMeters + ((hash ~/ 360) % 8) * 55;
    final latD = meters / 111320.0;
    final cosLat = math.cos(lat * math.pi / 180).abs();
    final lngD = meters / (111320.0 * (cosLat < .25 ? .25 : cosLat));
    return (
      lat: lat + math.sin(angle) * latD,
      lng: lng + math.cos(angle) * lngD,
    );
  }

  _Kind _listingKind(Listing listing) {
    final category = (listing.category ?? '').trim().toLowerCase();
    if (category.contains('jet')) return _Kind.jet;
    if (category.contains('restaurant') ||
        category.contains('dining') ||
        category.contains('food')) {
      return _Kind.dining;
    }
    if (category.contains('worker') ||
        category.contains('service') ||
        category.contains('professional') ||
        category.contains('massage') ||
        category.contains('cleaning')) {
      return _Kind.service;
    }
    if (category.contains('motorcycle') || category.contains('moto')) {
      return _Kind.motorcycle;
    }
    if (category.contains('bicycle') || category.contains('bike')) {
      return _Kind.bicycle;
    }
    if (category.contains('yacht') || category.contains('boat')) {
      return _Kind.yacht;
    }
    if (category.contains('roommate')) return _Kind.roommate;
    if (category.contains('seeker') || category.contains('request')) {
      return _Kind.seeker;
    }
    if (category.contains('buyer')) return _Kind.buyer;
    if (category.contains('renter')) return _Kind.renter;
    return _Kind.property;
  }

  _Item _listingItem(Listing listing, DiscoveryLocation loc) {
    final point = listing.latitude != null && listing.longitude != null
        ? _spread(listing.id, listing.latitude!, listing.longitude!)
        : _spread(listing.id, loc.latitude, loc.longitude, baseMeters: 360);
    return _Item(
      id: listing.id,
      kind: _listingKind(listing),
      lat: point.lat,
      lng: point.lng,
      title: (listing.title ?? '').trim().isEmpty
          ? 'Swipess listing'
          : listing.title!.trim(),
      subtitle: listing.formattedLocation,
      image: listing.primaryImage ?? '',
      detail: listing.formattedPrice,
      listing: listing,
    );
  }

  _Item _profileItem(Profile profile, DiscoveryLocation loc) {
    final point = profile.latitude != null && profile.longitude != null
        ? _spread(profile.id, profile.latitude!, profile.longitude!)
        : _spread(profile.id, loc.latitude, loc.longitude, baseMeters: 420);
    return _Item(
      id: profile.id,
      kind: _Kind.person,
      lat: point.lat,
      lng: point.lng,
      title: profile.displayName,
      subtitle: profile.city ?? 'Nearby',
      image: profile.avatarUrl ?? '',
      detail: profile.role ?? 'Swipess member',
      profile: profile,
    );
  }

  _Item _eventItem(Event event, DiscoveryLocation loc) {
    final point = _spread(
      'event:${event.id}',
      loc.latitude,
      loc.longitude,
      baseMeters: 260,
    );
    return _Item(
      id: event.id,
      kind: _Kind.event,
      lat: point.lat,
      lng: point.lng,
      title: event.title,
      subtitle: event.location ?? event.locationDetail ?? loc.city,
      image: event.imageUrl ??
          (event.imageUrls.isNotEmpty ? event.imageUrls.first : ''),
      detail: event.price,
      event: event,
    );
  }

  bool _matches(_Item item) {
    final typeMatch = switch (_filter) {
      'events' => item.kind == _Kind.event,
      'properties' => item.kind == _Kind.property,
      'services' => item.kind == _Kind.service,
      'dining' => item.kind == _Kind.dining,
      'jets' => item.kind == _Kind.jet,
      'yachts' => item.kind == _Kind.yacht,
      'motorcycles' => item.kind == _Kind.motorcycle,
      'bicycles' => item.kind == _Kind.bicycle,
      'roommates' => item.kind == _Kind.roommate,
      'seekers' => item.kind == _Kind.seeker,
      'buyers' => item.kind == _Kind.buyer,
      'renters' => item.kind == _Kind.renter,
      'people' => item.kind == _Kind.person,
      _ => true,
    };
    if (!typeMatch) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return item.title.toLowerCase().contains(q) ||
        item.subtitle.toLowerCase().contains(q) ||
        item.kind.label.toLowerCase().contains(q);
  }

  List<_Item> _buildItems({
    required DiscoveryLocation loc,
    required List<Listing> listings,
    required List<Profile> profiles,
    required List<Event> events,
    required Set<String> likedListings,
    required Set<String> likedPeople,
    required Set<String> likedEvents,
  }) {
    final all = <_Item>[
      for (final listing in listings)
        if (!likedListings.contains(listing.id)) _listingItem(listing, loc),
      for (final profile in profiles)
        if (!likedPeople.contains(profile.id)) _profileItem(profile, loc),
      for (final event in events)
        if (!likedEvents.contains(event.id)) _eventItem(event, loc),
    ];
    return all
        .where((item) => !_sessionHidden.contains(item.key) && _matches(item))
        .toList(growable: false);
  }

  List<_Item> _currentItems() {
    final loc = ref.read(discoveryLocationProvider);
    return _buildItems(
      loc: loc,
      listings: ref.read(mapListingsProvider).value ?? const <Listing>[],
      profiles: ref.read(mapProfilesProvider).value ?? const <Profile>[],
      events: ref.read(eventsListProvider).value ?? const <Event>[],
      likedListings:
          ref.read(likedListingIdsProvider).value ?? const <String>{},
      likedPeople: ref.read(likedPeopleIdsProvider).value ?? const <String>{},
      likedEvents: ref.read(likedEventIdsProvider).value ?? const <String>{},
    );
  }

  void _scheduleProjection() {
    if (!_mapLoaded || _map == null || _projectionScheduled) return;
    _projectionScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 26), () async {
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
      final items = _currentItems();
      final points = <Point>[
        _point(_gpsLat ?? loc.latitude, _gpsLng ?? loc.longitude),
        if (loc.radiusKm <= 250)
          _point(loc.latitude + loc.radiusKm / 111.32, loc.longitude),
        for (final item in items) _point(item.lat, item.lng),
      ];
      final projected = await map.pixelsForCoordinates(points);
      if (!mounted || projected.isEmpty) return;

      var cursor = 0;
      final location = projected[cursor++];
      final locationPixel = Offset(location.x, location.y);
      double? radius;
      if (loc.radiusKm <= 250 && cursor < projected.length) {
        final edge = projected[cursor++];
        radius = (Offset(edge.x, edge.y) - locationPixel).distance;
        if (!radius.isFinite || radius < 2 || radius > 1800) radius = null;
      }

      final next = <String, Offset>{};
      for (final item in items) {
        if (cursor >= projected.length) break;
        final point = projected[cursor++];
        next[item.key] = Offset(point.x, point.y);
      }
      setState(() {
        _locationPixel = locationPixel;
        _radiusPixels = radius;
        _pixels = next;
      });
    } catch (_) {
      // A transient projection frame should never blank the map.
    } finally {
      _projecting = false;
      if (_projectionQueued && mounted) {
        _projectionQueued = false;
        _scheduleProjection();
      }
    }
  }

  void _select(_Item item, List<_Item> items) {
    AppHaptics.selection();
    setState(() => _selectedKey = item.key);
    final index = items.indexWhere((candidate) => candidate.key == item.key);
    if (index >= 0 && _cards.hasClients) {
      _cards.animateTo(
        index * 204.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _dismissSelection() {
    if (_selectedKey == null && !_menuOpen) return;
    setState(() {
      _selectedKey = null;
      _menuOpen = false;
    });
  }

  void _open(_Item item) {
    AppHaptics.medium();
    if (item.event != null) {
      context.push(AppPaths.exploreEvent(item.id));
    } else if (item.listing != null) {
      context.push(AppPaths.listing(item.id));
    } else {
      context.push(AppPaths.profile(item.id));
    }
  }

  Future<void> _like(_Item item) async {
    if (_sessionHidden.contains(item.key)) return;
    AppHaptics.medium();
    setState(() {
      _sessionHidden.add(item.key);
      if (_selectedKey == item.key) _selectedKey = null;
    });
    _scheduleProjection();
    try {
      final repo = ref.read(likesRepositoryProvider);
      if (item.listing != null) {
        await repo.likeListing(item.id);
        ref.invalidate(likedListingIdsProvider);
        ref.invalidate(mapListingsProvider);
      } else if (item.profile != null) {
        await repo.likePerson(item.id);
        ref.invalidate(likedPeopleIdsProvider);
        ref.invalidate(mapProfilesProvider);
      } else if (item.event != null) {
        await repo.likeEvent(item.id);
        ref.invalidate(likedEventIdsProvider);
        ref.invalidate(eventsListProvider);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _sessionHidden.remove(item.key));
      _scheduleProjection();
    }
  }

  Future<void> _submitSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2 || _searchingPlace) return;
    setState(() => _searchingPlace = true);
    try {
      final results = await MapboxPlaceSearch.search(query);
      if (!mounted || results.isEmpty) return;
      final result = results.first;
      final location = ref.read(discoveryLocationProvider.notifier);
      location.setCoordinates(
        city: result.name,
        country: result.country,
        latitude: result.latitude,
        longitude: result.longitude,
      );
      location.setRadiusKm(result.suggestedRadiusKm);
      setState(() {
        _query = '';
        _selectedKey = null;
      });
      FocusManager.instance.primaryFocus?.unfocus();
    } finally {
      if (mounted) setState(() => _searchingPlace = false);
    }
  }

  void _changeTray(int delta) {
    setState(() => _trayLevel = (_trayLevel + delta).clamp(-1, 1));
  }

  void _closeMap() {
    final close = widget.onClose;
    if (close != null) {
      close();
    } else {
      context.go(AppPaths.clientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenReady = AppConfig.mapboxAccessToken.trim().isNotEmpty;
    final loc = ref.watch(discoveryLocationProvider);
    final listings = ref.watch(mapListingsProvider).value ?? const <Listing>[];
    final profiles = ref.watch(mapProfilesProvider).value ?? const <Profile>[];
    final events = ref.watch(eventsListProvider).value ?? const <Event>[];
    final likedListings =
        ref.watch(likedListingIdsProvider).value ?? const <String>{};
    final likedPeople =
        ref.watch(likedPeopleIdsProvider).value ?? const <String>{};
    final likedEvents = ref.watch(likedEventIdsProvider).value ?? const <String>{};
    final pad = MediaQuery.paddingOf(context);

    final items = _buildItems(
      loc: loc,
      listings: listings,
      profiles: profiles,
      events: events,
      likedListings: likedListings,
      likedPeople: likedPeople,
      likedEvents: likedEvents,
    );
    _Item? selected;
    if (_selectedKey != null) {
      for (final item in items) {
        if (item.key == _selectedKey) {
          selected = item;
          break;
        }
      }
    }

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null) return;
      if (previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.radiusKm != next.radiusKm) {
        setState(() => _selectedKey = null);
        unawaited(_flyTo(next));
      }
    });
    ref.listen(mapListingsProvider, (_, _) => _scheduleProjection());
    ref.listen(mapProfilesProvider, (_, _) => _scheduleProjection());
    ref.listen(eventsListProvider, (_, _) => _scheduleProjection());
    ref.listen(likedListingIdsProvider, (_, _) => _scheduleProjection());
    ref.listen(likedPeopleIdsProvider, (_, _) => _scheduleProjection());
    ref.listen(likedEventIdsProvider, (_, _) => _scheduleProjection());

    if (!tokenReady) {
      return const Material(
        color: Color(0xFFF3F8FB),
        child: Center(child: Text('Mapbox is not configured')),
      );
    }

    return Material(
      color: const Color(0xFFF3F8FB),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool onScreen(Offset point, {double margin = 100}) =>
              point.dx >= -margin &&
              point.dy >= -margin &&
              point.dx <= constraints.maxWidth + margin &&
              point.dy <= constraints.maxHeight + margin;

          final selectedPixel = selected == null ? null : _pixels[selected.key];

          return Stack(
            fit: StackFit.expand,
            children: [
              MapWidget(
                key: const ValueKey('swipess-persistent-mapbox-web-v3'),
                styleUri: _lightStyle,
                onMapCreated: _setupMap,
                onMapLoadedListener: (_) {
                  _mapLoaded = true;
                  _scheduleProjection();
                  if (_openingFlight) {
                    _openingTimer = Timer(const Duration(milliseconds: 900), () {
                      if (!mounted) return;
                      setState(() => _openingFlight = false);
                      unawaited(_flyTo(loc, duration: 2800));
                    });
                  }
                },
                onCameraChangeListener: (_) => _scheduleProjection(),
                onMapIdleListener: (_) => _scheduleProjection(),
              ),

              // When a preview is open, one background tap dismisses it. This
              // temporary layer is below all pins/cards so it cannot steal taps
              // from the selected result. After dismissal normal map gestures
              // immediately pass through to Mapbox again.
              if (_selectedKey != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissSelection,
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),

              if (_locationPixel != null &&
                  _radiusPixels != null &&
                  loc.radiusKm <= 250 &&
                  onScreen(_locationPixel!, margin: _radiusPixels!))
                Positioned(
                  left: _locationPixel!.dx - _radiusPixels!,
                  top: _locationPixel!.dy - _radiusPixels!,
                  child: IgnorePointer(
                    child: Container(
                      width: _radiusPixels! * 2,
                      height: _radiusPixels! * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x10147DFF),
                        border: Border.all(
                          color: const Color(0x50147DFF),
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),

              if (_locationPixel != null && onScreen(_locationPixel!))
                Positioned(
                  left: _locationPixel!.dx - 10,
                  top: _locationPixel!.dy - 10,
                  child: const IgnorePointer(child: _LocationDot()),
                ),

              // Every regular marker paints first.
              for (final item in items)
                if (item.key != _selectedKey)
                  if (_pixels[item.key] case final Offset pixel)
                    if (onScreen(pixel))
                      Positioned(
                        left: pixel.dx - 24,
                        top: pixel.dy - 48,
                        child: _Pin(
                          item: item,
                          selected: false,
                          onTap: () => _select(item, items),
                        ),
                      ),

              // Selected marker is above regular markers.
              if (selected != null &&
                  selectedPixel != null &&
                  onScreen(selectedPixel))
                Positioned(
                  left: selectedPixel.dx - 27,
                  top: selectedPixel.dy - 54,
                  child: _Pin(
                    item: selected,
                    selected: true,
                    onTap: () => _open(selected!),
                  ),
                ),

              // Preview paints after ALL markers. It therefore cannot be hidden
              // behind a cluster of pins, regardless of marker list order.
              if (selected != null && selectedPixel != null)
                Positioned(
                  left: (selectedPixel.dx - 118)
                      .clamp(8.0, math.max(8.0, constraints.maxWidth - 244))
                      .toDouble(),
                  top: (selectedPixel.dy - 150)
                      .clamp(8.0, math.max(8.0, constraints.maxHeight - 104))
                      .toDouble(),
                  child: _Preview(
                    item: selected,
                    onOpen: () => _open(selected!),
                    onLike: () => _like(selected!),
                    onClose: _dismissSelection,
                  ),
                ),

              if (_controlsVisible && !_openingFlight) ...[
                Positioned(
                  top: pad.top + 8,
                  left: 10,
                  child: Row(
                    children: [
                      _FloatingIcon(
                        label: 'Back',
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: _closeMap,
                      ),
                      const SizedBox(width: 8),
                      _FloatingIcon(
                        label: 'Map options',
                        icon: Icons.menu_rounded,
                        onTap: () => setState(() {
                          _menuOpen = !_menuOpen;
                          _searchOpen = false;
                        }),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: pad.top + 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        'SWIPESS',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: pad.top + 8,
                  right: 10,
                  child: _FloatingIcon(
                    label: 'Search',
                    icon: _searchOpen
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    onTap: () => setState(() {
                      _searchOpen = !_searchOpen;
                      _menuOpen = false;
                    }),
                  ),
                ),
                if (_searchOpen)
                  Positioned(
                    top: pad.top + 52,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: _MapSearch(
                          controller: _searchController,
                          busy: _searchingPlace,
                          onChanged: (value) => setState(() {
                            _query = value;
                            _selectedKey = null;
                          }),
                          onSubmit: _submitSearch,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: pad.top + (_searchOpen ? 100 : 52),
                  left: 0,
                  right: 0,
                  child: _FilterRail(
                    active: _filter,
                    onFilter: (value) {
                      setState(() {
                        _filter = value;
                        _selectedKey = null;
                      });
                      _scheduleProjection();
                    },
                  ),
                ),
                if (_menuOpen)
                  Positioned(
                    top: pad.top + 48,
                    left: 48,
                    child: _Menu(
                      trayVisible: _trayLevel >= 0,
                      onMyLocation: () {
                        setState(() => _menuOpen = false);
                        unawaited(_loadGps(silent: false));
                      },
                      onToggleTray: () => setState(() {
                        _trayLevel = _trayLevel >= 0 ? -1 : 0;
                        _menuOpen = false;
                      }),
                      onHideControls: () => setState(() {
                        _controlsVisible = false;
                        _menuOpen = false;
                        _searchOpen = false;
                        _selectedKey = null;
                      }),
                      onClose: _closeMap,
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: _trayHeight + pad.bottom + 18,
                  child: _FloatingIcon(
                    label: 'My location',
                    icon: Icons.my_location_rounded,
                    onTap: () => unawaited(_loadGps(silent: false)),
                  ),
                ),
                if (_trayLevel >= 0)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: pad.bottom + 10,
                    child: _Tray(
                      city: loc.city,
                      items: items,
                      selectedKey: _selectedKey,
                      controller: _cards,
                      level: _trayLevel,
                      height: _trayHeight,
                      onSelect: (item) => _select(item, items),
                      onOpen: _open,
                      onLike: _like,
                      onExpand: () => _changeTray(1),
                      onCollapse: () => _changeTray(-1),
                    ),
                  ),
              ] else if (!_openingFlight)
                Positioned(
                  top: pad.top + 10,
                  right: 10,
                  child: _FloatingIcon(
                    label: 'Show controls',
                    icon: Icons.visibility_rounded,
                    onTap: () => setState(() => _controlsVisible = true),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF147DFF),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x55147DFF), blurRadius: 12, spreadRadius: 3),
          ],
        ),
      );
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: item.title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedScale(
            scale: selected ? 1.16 : 1,
            duration: const Duration(milliseconds: 140),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.kind.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: item.kind.color.withAlpha(selected ? 130 : 70),
                    blurRadius: selected ? 18 : 10,
                    spreadRadius: selected ? 2 : 0,
                  ),
                  const BoxShadow(color: Colors.black26, blurRadius: 7),
                ],
              ),
              child: Icon(item.kind.icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      );
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.item,
    required this.onOpen,
    required this.onLike,
    required this.onClose,
  });

  final _Item item;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 12,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 236,
          height: 94,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: Row(
                    children: [
                      _Image(url: item.image, width: 78),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 9, 48, 9),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.kind.label,
                                style: GoogleFonts.plusJakartaSans(
                                  color: item.kind.color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.black,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.black54,
                                  fontSize: 9.5,
                                ),
                              ),
                              if (item.detail.trim().isNotEmpty)
                                Text(
                                  item.detail,
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
              Positioned(
                top: 7,
                right: 7,
                child: _BareIcon(
                  icon: Icons.close_rounded,
                  label: 'Close preview',
                  onTap: onClose,
                ),
              ),
              Positioned(
                bottom: 7,
                right: 7,
                child: _BareIcon(
                  icon: Icons.favorite_border_rounded,
                  label: 'Like',
                  onTap: onLike,
                ),
              ),
            ],
          ),
        ),
      );
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: Icon(
                icon,
                color: Colors.black87,
                size: 20,
                shadows: const [
                  Shadow(color: Colors.white, blurRadius: 8),
                  Shadow(color: Colors.black26, blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BareIcon extends StatelessWidget {
  const _BareIcon({
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
            width: 30,
            height: 30,
            child: Icon(icon, color: Colors.black87, size: 18),
          ),
        ),
      );
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({required this.active, required this.onFilter});

  final String active;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0x00000000),
              Colors.white,
              Colors.white,
              Color(0x00000000),
            ],
            stops: [0, .05, .95, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final selected = filter.id == active;
              return GestureDetector(
                onTap: () => onFilter(filter.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : Colors.white.withAlpha(242),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        filter.icon,
                        size: 12,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        filter.title,
                        style: GoogleFonts.plusJakartaSans(
                          color: selected ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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

class _MapSearch extends StatelessWidget {
  const _MapSearch({
    required this.controller,
    required this.busy,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(248),
          borderRadius: BorderRadius.circular(21),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmit(),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Search Miami, properties, bikes, people…',
            prefixIcon: const Icon(Icons.search_rounded, size: 17),
            suffixIcon: busy
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 1.7),
                    ),
                  )
                : IconButton(
                    tooltip: 'Search place',
                    onPressed: onSubmit,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
          ),
        ),
      );
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.trayVisible,
    required this.onMyLocation,
    required this.onToggleTray,
    required this.onHideControls,
    required this.onClose,
  });

  final bool trayVisible;
  final VoidCallback onMyLocation;
  final VoidCallback onToggleTray;
  final VoidCallback onHideControls;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, VoidCallback onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 17, color: Colors.black87),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(Icons.my_location_rounded, 'My location', onMyLocation),
          row(
            trayVisible
                ? Icons.visibility_off_rounded
                : Icons.view_carousel_rounded,
            trayVisible ? 'Hide listings' : 'Show listings',
            onToggleTray,
          ),
          row(Icons.visibility_off_rounded, 'Hide controls', onHideControls),
          row(Icons.close_rounded, 'Close map', onClose),
        ],
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.city,
    required this.items,
    required this.selectedKey,
    required this.controller,
    required this.level,
    required this.height,
    required this.onSelect,
    required this.onOpen,
    required this.onLike,
    required this.onExpand,
    required this.onCollapse,
  });

  final String city;
  final List<_Item> items;
  final String? selectedKey;
  final ScrollController controller;
  final int level;
  final double height;
  final ValueChanged<_Item> onSelect;
  final ValueChanged<_Item> onOpen;
  final ValueChanged<_Item> onLike;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 210),
        height: height,
        padding: EdgeInsets.fromLTRB(12, level == 0 ? 5 : 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(248),
          borderRadius: BorderRadius.circular(level == 0 ? 20 : 24),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: level == 0 ? onExpand : onCollapse,
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -80) onExpand();
                if (velocity > 80) onCollapse();
              },
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        level == 0
                            ? '${items.length} places · ${city.trim().isEmpty ? 'nearby' : city}'
                            : 'Discover ${city.trim().isEmpty ? 'nearby' : city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: level == 0 ? 12 : 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      level == 0
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (level > 0)
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'Nothing new here — liked items stay out of discovery.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _MiniCard(
                            item: item,
                            selected: item.key == selectedKey,
                            onTap: () => onSelect(item),
                            onOpen: () => onOpen(item),
                            onLike: () => onLike(item),
                          );
                        },
                      ),
              ),
          ],
        ),
      );
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    required this.onLike,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Container(
          width: 198,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(selected ? 30 : 12),
                blurRadius: selected ? 8 : 3,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              _Image(url: item.image, width: 82),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.kind.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: item.kind.color,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.black87,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _BareIcon(
                            icon: Icons.favorite_border_rounded,
                            label: 'Like',
                            onTap: onLike,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Image extends StatelessWidget {
  const _Image({required this.url, required this.width});

  final String url;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: width,
          color: const Color(0xFFE5E7EB),
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined, color: Colors.black38),
        );
    if (url.trim().isEmpty) return fallback();
    return SizedBox(
      width: width,
      height: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}
