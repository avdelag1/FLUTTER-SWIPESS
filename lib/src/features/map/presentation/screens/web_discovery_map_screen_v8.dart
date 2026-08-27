import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_locations.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/map/data/map_basemap.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_chips.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

bool _webDiscoveryOpenedThisSession = false;
LatLng? _webSessionCenter;
double? _webSessionZoom;
double _webSessionRotation = 0;

class WebDiscoveryMapScreenV5 extends ConsumerStatefulWidget {
  const WebDiscoveryMapScreenV5({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<WebDiscoveryMapScreenV5> createState() =>
      _WebDiscoveryMapScreenV8State();
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
  _FilterDef('jets', 'Jets', Icons.flight),
  _FilterDef('yachts', 'Yachts', Icons.directions_boat),
  _FilterDef('motorcycles', 'Motos', Icons.motorcycle),
  _FilterDef('bicycles', 'Bikes', Icons.pedal_bike),
  _FilterDef('roommates', 'Roommates', Icons.people),
  _FilterDef('seekers', 'Seekers', Icons.search),
  _FilterDef('buyers', 'Buyers', Icons.shopping_bag),
  _FilterDef('renters', 'Renters', Icons.key),
  _FilterDef('people', 'People', Icons.person),
];

class _WebDiscoveryMapScreenV8State
    extends ConsumerState<WebDiscoveryMapScreenV5>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  final ScrollController _cards = ScrollController();
  late final AnimationController _flight;
  late final bool _playOpeningFlight;
  Timer? _openingTimer;

  bool _ready = false;
  bool _citiesOpen = false;
  bool _menuOpen = false;
  bool _searchOpen = false;
  bool _controlsVisible = true;
  bool _flying = false;
  bool _openingFlight = false;
  String _filter = 'all';
  String _query = '';
  String? _selected;
  int _trayLevel = -1;
  double _zoom = 11.2;

  double _fromLat = 18;
  double _fromLng = -28;
  double _toLat = 0;
  double _toLng = 0;
  double _fromZoom = 1.15;
  double _toZoom = 11.2;
  double _fromRotation = -8;
  double _toRotation = 0;

  // User's real GPS position (separate from discovery browse location)
  double? _userGpsLat;
  double? _userGpsLng;

  @override
  void initState() {
    super.initState();
    _playOpeningFlight = !_webDiscoveryOpenedThisSession;
    _webDiscoveryOpenedThisSession = true;
    _openingFlight = _playOpeningFlight;
    _citiesOpen = widget.showCitiesOnOpen;
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )
      ..addListener(_tickFlight)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _flying = false;
            _openingFlight = false;
          });
        }
      });

    // Auto-fetch the user's real GPS position for the blue dot
    _autoFetchGps();
  }

  @override
  void dispose() {
    _openingTimer?.cancel();
    _flight.dispose();
    _cards.dispose();
    _map.dispose();
    super.dispose();
  }

  double get _trayHeight => switch (_trayLevel) {
        -1 => 0,
        0 => 52,
        2 => 318,
        _ => 198,
      };

  double _zoomFor(int km) {
    if (km <= 5) return 13.2;
    if (km <= 10) return 12.3;
    if (km <= 25) return 11.2;
    if (km <= 50) return 10.2;
    if (km <= 100) return 9.2;
    if (km <= 250) return 8.0;
    if (km <= 1000) return 5.8;
    if (km <= 5000) return 3.2;
    return 2.0;
  }

  double _wrap(double value) {
    var v = value;
    while (v > 180) v -= 360;
    while (v < -180) v += 360;
    return v;
  }

  double _lngDelta(double from, double to) {
    var d = to - from;
    while (d > 180) d -= 360;
    while (d < -180) d += 360;
    return d;
  }

  void _remember(double lat, double lng, double zoom, double rotation) {
    _webSessionCenter = LatLng(lat, lng);
    _webSessionZoom = zoom;
    _webSessionRotation = rotation;
  }

  void _tickFlight() {
    if (!_ready) return;
    final raw = _flight.value;
    final moveT = Curves.easeInOutCubic.transform(raw);
    final zoomT = Curves.easeInOutCubic.transform(
      ((raw - .10) / .90).clamp(0.0, 1.0),
    );
    final lat = _fromLat + (_toLat - _fromLat) * moveT;
    final lng = _wrap(_fromLng + _lngDelta(_fromLng, _toLng) * moveT);
    final zoom = _fromZoom + (_toZoom - _fromZoom) * zoomT;
    final rotation =
        _fromRotation + (_toRotation - _fromRotation) * moveT;
    try {
      _map.moveAndRotate(LatLng(lat, lng), zoom, rotation);
      _zoom = zoom;
      _remember(lat, lng, zoom, rotation);
    } catch (_) {}
  }

  void _startWorldFlight(DiscoveryLocation loc, {bool opening = false}) {
    if (!_ready) return;
    _openingTimer?.cancel();
    _flight.stop();
    _flight.duration = const Duration(milliseconds: 4800);
    _selected = null;
    _fromLat = 18;
    _fromLng = -28;
    _toLat = loc.latitude;
    _toLng = loc.longitude;
    _fromZoom = 1.15;
    _toZoom = _zoomFor(loc.radiusKm);
    _fromRotation = -8;
    _toRotation = 0;
    try {
      _map.moveAndRotate(const LatLng(18, -28), _fromZoom, -8);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _flying = true;
        _openingFlight = opening;
      });
    }
    _flight.forward(from: 0);
  }

  void _flyToLocation(DiscoveryLocation loc) {
    if (!_ready) return;
    _openingTimer?.cancel();
    _flight.stop();
    final from = _webSessionCenter ?? LatLng(loc.latitude, loc.longitude);
    _fromLat = from.latitude;
    _fromLng = from.longitude;
    _toLat = loc.latitude;
    _toLng = loc.longitude;
    _fromZoom = _webSessionZoom ?? _zoom;
    _toZoom = _zoomFor(loc.radiusKm);
    _fromRotation = _webSessionRotation;
    _toRotation = 0;
    _flight.duration = const Duration(milliseconds: 1800);
    if (mounted) {
      setState(() {
        _flying = true;
        _openingFlight = false;
      });
    }
    _flight.forward(from: 0);
  }

  /// Silently fetches the user's real GPS for the blue dot WITHOUT
  /// changing the discovery browse location or moving the map.
  Future<void> _autoFetchGps() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      if (mounted) {
        setState(() {
          _userGpsLat = position.latitude;
          _userGpsLng = position.longitude;
        });
      }
    } catch (_) {
      // GPS unavailable — blue dot falls back to discovery location
    }
  }

  Future<void> _findMyExactLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    
    if (mounted) {
      setState(() {
        _userGpsLat = position.latitude;
        _userGpsLng = position.longitude;
      });
      ref.read(discoveryLocationProvider.notifier).setCoordinates(
        city: 'My Location',
        country: '',
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      // Also zoom in slightly closer for personal location
      ref.read(discoveryLocationProvider.notifier).setRadiusKm(10);
    }
  }

  void _recenter(DiscoveryLocation loc) {
    if (!_ready) return;
    _openingTimer?.cancel();
    _flight.stop();
    try {
      final z = _zoomFor(loc.radiusKm);
      _map.moveAndRotate(LatLng(loc.latitude, loc.longitude), z, 0);
      _zoom = z;
      _remember(loc.latitude, loc.longitude, z, 0);
    } catch (_) {}
    if ((_flying || _openingFlight) && mounted) {
      setState(() {
        _flying = false;
        _openingFlight = false;
      });
    }
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    final close = widget.onClose;
    if (close != null) {
      close();
      return;
    }
    context.go(AppPaths.clientDashboard);
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

  ({double lat, double lng}) _pointFor(
    String id,
    String? city,
    double? lat,
    double? lng,
    DiscoveryLocation loc,
  ) {
    if (lat != null && lng != null) return _spread(id, lat, lng);
    final known = ListingLocations.resolve(city ?? '');
    return _spread(
      id,
      known?.lat ?? loc.latitude,
      known?.lng ?? loc.longitude,
      baseMeters: 360,
    );
  }

  _Kind _listingKind(Listing listing) {
    final c = (listing.category ?? '').trim().toLowerCase();
    if (c.contains('jet')) return _Kind.jet;
    if (c.contains('restaurant') || c.contains('dining') || c.contains('food')) {
      return _Kind.dining;
    }
    if (c.contains('worker') ||
        c.contains('service') ||
        c.contains('professional') ||
        c.contains('massage') ||
        c.contains('cleaning')) {
      return _Kind.service;
    }
    if (c.contains('motorcycle') || c.contains('moto')) {
      return _Kind.motorcycle;
    }
    if (c.contains('bicycle') || c.contains('bike')) return _Kind.bicycle;
    if (c.contains('yacht') || c.contains('boat')) return _Kind.yacht;
    if (c.contains('roommate')) return _Kind.roommate;
    if (c.contains('seeker') || c.contains('request')) return _Kind.seeker;
    if (c.contains('buyer')) return _Kind.buyer;
    if (c.contains('renter')) return _Kind.renter;
    return _Kind.property;
  }

  _Item _listingItem(Listing listing, DiscoveryLocation loc) {
    final p = _pointFor(
      listing.id,
      listing.city,
      listing.latitude,
      listing.longitude,
      loc,
    );
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
      detail: listing.formattedPrice,
      listing: listing,
    );
  }

  _Item _profileItem(Profile profile, DiscoveryLocation loc) {
    final p = _pointFor(
      profile.id,
      profile.city,
      profile.latitude,
      profile.longitude,
      loc,
    );
    return _Item(
      id: profile.id,
      kind: _Kind.person,
      lat: p.lat,
      lng: p.lng,
      title: profile.displayName,
      subtitle: profile.city ?? 'Nearby',
      image: profile.avatarUrl ?? '',
      detail: profile.role ?? 'Swipess member',
      profile: profile,
    );
  }

  _Item _eventItem(Event event, DiscoveryLocation loc) {
    final rawLocation =
        '${event.location ?? ''} ${event.locationDetail ?? ''}'.trim();
    final known = ListingLocations.resolve(rawLocation) ??
        ListingLocations.resolve(event.location ?? '');
    final p = _spread(
      'event:${event.id}',
      known?.lat ?? loc.latitude,
      known?.lng ?? loc.longitude,
      baseMeters: 180,
    );
    final image =
        event.imageUrl ?? (event.imageUrls.isNotEmpty ? event.imageUrls.first : '');
    return _Item(
      id: event.id,
      kind: _Kind.event,
      lat: p.lat,
      lng: p.lng,
      title: event.title,
      subtitle: event.location ?? event.locationDetail ?? loc.city,
      image: image,
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

  List<_Item> _items(
    DiscoveryLocation loc,
    List<Listing> listings,
    List<Profile> profiles,
    List<Event> events,
  ) {
    final all = <_Item>[
      for (final listing in listings) _listingItem(listing, loc),
      for (final profile in profiles) _profileItem(profile, loc),
      for (final event in events) _eventItem(event, loc),
    ];
    return all.where(_matches).toList(growable: false);
  }

  void _select(_Item item, List<_Item> items) {
    AppHaptics.selection();
    setState(() => _selected = item.key);
    final index = items.indexWhere((e) => e.key == item.key);
    if (index >= 0 && _cards.hasClients) {
      _cards.animateTo(
        index * 224.0,
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
      );
    }
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

  void _seeAll() {
    if (_filter == 'events') {
      context.push(AppPaths.exploreEvents);
    } else if (_filter == 'services' || _filter == 'dining') {
      context.push(AppPaths.exploreServices);
    } else {
      context.push(AppPaths.clientFilters);
    }
  }

  void _hideControls() {
    setState(() {
      _controlsVisible = false;
      _menuOpen = false;
      _citiesOpen = false;
      _searchOpen = false;
    });
  }

  void _showControls() => setState(() => _controlsVisible = true);

  void _changeTray(int delta) {
    setState(() => _trayLevel = (_trayLevel + delta).clamp(0, 2));
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    final listings = ref.watch(mapListingsProvider).value ?? const <Listing>[];
    final profiles = ref.watch(mapProfilesProvider).value ?? const <Profile>[];
    final events = ref.watch(eventsListProvider).value ?? const <Event>[];
    final pad = MediaQuery.paddingOf(context);

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null) return;
      final moved = previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.city != next.city;
      if (moved) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _flyToLocation(next);
        });
      } else if (previous.radiusKm != next.radiusKm) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _recenter(next);
        });
      }
    });

    final items = _items(loc, listings, profiles, events);
    if (_selected != null && !items.any((item) => item.key == _selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selected = null);
      });
    }

    final initialCenter = _playOpeningFlight
        ? const LatLng(18, -28)
        : (_webSessionCenter ?? LatLng(loc.latitude, loc.longitude));
    final initialZoom = _playOpeningFlight
        ? 1.15
        : (_webSessionZoom ?? _zoomFor(loc.radiusKm));
    final initialRotation = _playOpeningFlight ? -8.0 : _webSessionRotation;

    return Material(
      color: const Color(0xFFF3F8FB),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              initialRotation: initialRotation,
              minZoom: 1.0,
              maxZoom: 18,
              backgroundColor: const Color(0xFFF3F8FB),
              onMapReady: () {
                _ready = true;
                _zoom = initialZoom;
                _remember(
                  initialCenter.latitude,
                  initialCenter.longitude,
                  initialZoom,
                  initialRotation,
                );
                if (_playOpeningFlight) {
                  _openingTimer = Timer(
                    const Duration(milliseconds: 2200),
                    () {
                      if (mounted) _startWorldFlight(loc, opening: true);
                    },
                  );
                }
              },
              onPositionChanged: (camera, hasGesture) {
                _zoom = camera.zoom;
                _remember(
                  camera.center.latitude,
                  camera.center.longitude,
                  camera.zoom,
                  camera.rotation,
                );
                if (hasGesture) {
                  _openingTimer?.cancel();
                  _flight.stop();
                  if ((_flying || _openingFlight) && mounted) {
                    setState(() {
                      _flying = false;
                      _openingFlight = false;
                    });
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapBasemap.urlTemplate(true),
                subdomains: MapBasemap.subdomains,
                additionalOptions: MapBasemap.additionalOptions,
                userAgentPackageName: MapBasemap.userAgentPackageName,
                tileDimension: 256,
                maxNativeZoom: 19,
                keepBuffer: 5,
                panBuffer: 3,
              ),
              if (!_openingFlight && loc.radiusKm <= 250)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(loc.latitude, loc.longitude),
                      radius: loc.radiusKm * 1000.0,
                      useRadiusInMeter: true,
                      color: const Color(0x10147DFF),
                      borderColor: const Color(0x40147DFF),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              if (!_openingFlight)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _userGpsLat ?? loc.latitude,
                        _userGpsLng ?? loc.longitude,
                      ),
                      width: 48,
                      height: 48,
                      rotate: true,
                      child: const _LocationDot(),
                    ),
                    for (final item in items)
                      Marker(
                        point: LatLng(item.lat, item.lng),
                        width: item.key == _selected ? 250 : 50,
                        height: item.key == _selected ? 158 : 60,
                        rotate: true,
                        alignment: Alignment.bottomCenter,
                        child: _Pin(
                          item: item,
                          selected: item.key == _selected,
                          onTap: () => _select(item, items),
                          onOpen: () => _open(item),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (_controlsVisible && !_openingFlight) ...[
            Positioned(
              top: pad.top + 8,
              left: 0,
              right: 0,
              child: _Header(
                filter: _filter,
                searchOpen: _searchOpen,
                onBack: _goBack,
                onMenu: () => setState(() {
                  _menuOpen = !_menuOpen;
                  _citiesOpen = false;
                }),
                onSearchToggle: () => setState(() {
                  _searchOpen = !_searchOpen;
                  _menuOpen = false;
                  _citiesOpen = false;
                }),
                onSearch: (value) => setState(() {
                  _query = value;
                  _selected = null;
                }),
                onFilter: (value) => setState(() {
                  _filter = value;
                  _selected = null;
                }),
              ),
            ),
            if (_menuOpen)
              Positioned(
                top: pad.top + 50,
                left: 54,
                child: _MapMenu(
                  onHide: _hideControls,
                  onCities: () => setState(() {
                    _citiesOpen = true;
                    _menuOpen = false;
                    _searchOpen = false;
                  }),
                  onRecenter: () {
                    _recenter(loc);
                    setState(() => _menuOpen = false);
                  },
                  onReplayFlight: () {
                    _startWorldFlight(loc);
                    setState(() => _menuOpen = false);
                  },
                  onClose: widget.onClose ??
                      () => context.go(AppPaths.clientDashboard),
                  trayVisible: _trayLevel >= 0,
                  onToggleTray: () {
                    setState(() {
                      if (_trayLevel >= 0) {
                        _trayLevel = -1;
                      } else {
                        _trayLevel = 0;
                      }
                      _menuOpen = false;
                    });
                  },
                ),
              ),
            if (_citiesOpen)
              Positioned(
                top: pad.top + 92,
                left: 12,
                right: 12,
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
                      ref
                          .read(discoveryLocationProvider.notifier)
                          .setRadiusKm(25);
                    }
                    setState(() => _citiesOpen = false);
                  },
                ),
              ),
            Positioned(
              right: 12,
              bottom: _trayHeight + pad.bottom + 18,
              child: _CircleAction(
                label: 'Find My Location',
                icon: Icons.my_location_rounded,
                onTap: _findMyExactLocation,
              ),
            ),
            if (_trayLevel >= 0)
              Positioned(
                left: 12,
                right: 12,
                bottom: pad.bottom + 12,
                child: _Tray(
                  city: loc.city,
                  items: items,
                  controller: _cards,
                  selectedKey: _selected,
                  height: _trayHeight,
                  level: _trayLevel,
                  onTap: (item) => _select(item, items),
                  onOpen: _open,
                  onSeeAll: _seeAll,
                  onExpand: () => _changeTray(1),
                  onCollapse: () => _changeTray(-1),
                ),
              ),
          ] else if (!_openingFlight)
            Positioned(
              top: pad.top + 10,
              right: 12,
              child: _CircleAction(
                label: 'Show map controls',
                icon: Icons.visibility_rounded,
                onTap: _showControls,
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.filter,
    required this.searchOpen,
    required this.onBack,
    required this.onMenu,
    required this.onSearchToggle,
    required this.onSearch,
    required this.onFilter,
  });

  final String filter;
  final bool searchOpen;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
              children: [
                _HeaderCircle(
                  label: 'Back',
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
                const SizedBox(width: 6),
                _HeaderCircle(
                  label: 'Map options',
                  icon: Icons.tune_rounded,
                  onTap: onMenu,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'SWIPESS',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                ),
                _HeaderCircle(
                  label: 'Search map',
                  icon: searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  onTap: onSearchToggle,
                ),
              ],
            ),
            ),
          ),
        ),
        if (searchOpen) ...[
          const SizedBox(height: 7),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                height: 38,
                decoration: _whitePanel(19),
                child: TextField(
                  autofocus: true,
                  onChanged: onSearch,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search events, places...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: Colors.black45,
                      fontSize: 11.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.black54,
                      size: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 7),
        SizedBox(
          height: 34,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: [
                  Color(0x00000000),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.06, 0.94, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
              final f = _filters[index];
              final active = f.id == filter;
              return GestureDetector(
                onTap: () => onFilter(f.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: active ? Colors.black : const Color(0xF8FFFFFF),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          f.icon,
                          size: 12.5,
                          color: active ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          f.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: active ? Colors.white : Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ),
      ],
    );
  }
}

class _MapMenu extends StatelessWidget {
  const _MapMenu({
    required this.onHide,
    required this.onCities,
    required this.onRecenter,
    required this.onReplayFlight,
    required this.onClose,
    required this.onToggleTray,
    required this.trayVisible,
  });

  final VoidCallback onHide;
  final VoidCallback onCities;
  final VoidCallback onRecenter;
  final VoidCallback onReplayFlight;
  final VoidCallback onClose;
  final VoidCallback onToggleTray;
  final bool trayVisible;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, VoidCallback onTap) =>
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 17, color: Colors.black87),
                const SizedBox(width: 8),
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
      width: 188,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(Icons.location_city_rounded, 'Choose city', onCities),
            row(Icons.my_location_rounded, 'My Exact Location', onRecenter),
            row(
              trayVisible
                  ? Icons.visibility_off_rounded
                  : Icons.view_carousel_rounded,
              trayVisible ? 'Hide listings' : 'Show listings',
              onToggleTray,
            ),
            row(Icons.flight_takeoff_rounded, 'Replay world flight',
                onReplayFlight),
            row(Icons.visibility_off_rounded, 'Hide controls', onHide),
            const Divider(height: 8),
            row(Icons.close_rounded, 'Close map', onClose),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _whitePanel(double radius) => BoxDecoration(
      color: const Color(0xF8FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    );

class _HeaderCircle extends StatelessWidget {
  const _HeaderCircle({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.black87, size: 17),
        ),
      ),
    );
  }
}

class _LocationDot extends StatefulWidget {
  const _LocationDot();

  @override
  State<_LocationDot> createState() => _LocationDotState();
}

class _LocationDotState extends State<_LocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final pulse = math.sin(t * math.pi * 2) * 0.5 + 0.5;
        final ringScale = 1.0 + pulse * 1.8;
        final ringOpacity = (0.35 - pulse * 0.30).clamp(0.0, 1.0);

        return Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Breathing outer ring
                Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.fromRGBO(20, 125, 255, ringOpacity),
                    ),
                  ),
                ),
                // Core blue dot
                Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: const Color(0xFF147DFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(20, 125, 255, 0.3 + pulse * 0.2),
                        blurRadius: 8 + pulse * 6,
                        spreadRadius: pulse * 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final kind = item.kind;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutBack,
            child: SizedBox(
              width: 50,
              height: 60,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 30,
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x28000000),
                          blurRadius: 9,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kind.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(kind.icon, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected)
          Positioned(
            bottom: 64,
            child: GestureDetector(
              onTap: onOpen,
              child: Container(
                width: 224,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                    children: [
                      _Image(url: item.image, width: 72),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(kind.icon, size: 12, color: kind.color),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      kind.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: kind.color,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.black,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
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
                      const Padding(
                        padding: EdgeInsets.only(right: 7),
                        child: Icon(Icons.chevron_right_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.black87, size: 17),
        ),
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.city,
    required this.items,
    required this.controller,
    required this.selectedKey,
    required this.height,
    required this.level,
    required this.onTap,
    required this.onOpen,
    required this.onSeeAll,
    required this.onExpand,
    required this.onCollapse,
  });

  final String city;
  final List<_Item> items;
  final ScrollController controller;
  final String? selectedKey;
  final double height;
  final int level;
  final ValueChanged<_Item> onTap;
  final ValueChanged<_Item> onOpen;
  final VoidCallback onSeeAll;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: height,
      padding: EdgeInsets.fromLTRB(
        14,
        level == 0 ? 5 : 7,
        10,
        level == 0 ? 5 : 12,
      ),
      decoration: _whitePanel(level == 0 ? 20 : 26),
      child: Column(
        children: [
          if (level > 0)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCollapse,
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -60) {
                  onExpand();
                } else if (velocity > 60) {
                  onCollapse();
                }
              },
              child: SizedBox(
                height: 18,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD0D6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: level == 0 ? onExpand : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: level == 0 ? 42 : 40,
              child: Row(
                children: [
                  if (level == 0) ...[
                    const Icon(
                      Icons.view_carousel_rounded,
                      size: 18,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      level == 0
                          ? 'View ${items.length} places in ${city.trim().isEmpty ? 'this area' : city}'
                          : 'Discover ${city.trim().isEmpty ? 'nearby' : city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontSize: level == 0 ? 12.5 : 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (level > 0)
                    TextButton(
                      onPressed: onSeeAll,
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 11),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('See all'),
                    ),
                  IconButton(
                    onPressed: level == 0 ? onExpand : onCollapse,
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: Icon(
                      level == 0
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (level > 0) ...[
            const SizedBox(height: 2),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No results in this filter yet.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _MiniCard(
                          item: item,
                          selected: item.key == selectedKey,
                          onTap: () => onTap(item),
                          onOpen: () => onOpen(item),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Container(
          width: 216,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.15 : 0.06),
                blurRadius: selected ? 8 : 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
              children: [
                Stack(
                  children: [
                    _Image(url: item.image, width: 90),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _Badge(kind: item.kind),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(item.kind.icon, size: 14, color: item.kind.color),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.kind.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: item.kind.color,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                        if (item.detail.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (selected) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 26,
                            child: TextButton(
                              onPressed: onOpen,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 9),
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 10),
                              ),
                              child: const Text('View'),
                            ),
                          ),
                        ],
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

class _Badge extends StatelessWidget {
  const _Badge({required this.kind});
  final _Kind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: kind.color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, color: Colors.white, size: 9),
          const SizedBox(width: 3),
          Text(
            kind.label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
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
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}
