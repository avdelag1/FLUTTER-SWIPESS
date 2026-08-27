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

/// Premium web discovery map.
///
/// The basemap stays Mapbox-backed and bright. The screen deliberately starts
/// at a world view and flies into the active city. All visible controls have a
/// concrete action; the UI can be hidden for a clean full-map mode.
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
      _WebDiscoveryMapScreenV7State();
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
  _FilterDef('roommates', 'Roommates', Icons.group_outlined),
  _FilterDef('seekers', 'Seekers', Icons.travel_explore_rounded),
  _FilterDef('buyers', 'Buyers', Icons.shopping_bag_outlined),
  _FilterDef('renters', 'Renters', Icons.key_rounded),
  _FilterDef('people', 'People', Icons.person_outline_rounded),
];

class _WebDiscoveryMapScreenV7State
    extends ConsumerState<WebDiscoveryMapScreenV5>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  final ScrollController _cards = ScrollController();
  late final AnimationController _flight;

  bool _ready = false;
  bool _citiesOpen = false;
  bool _menuOpen = false;
  bool _controlsVisible = true;
  bool _flying = false;
  String _filter = 'all';
  String _query = '';
  String? _selected;
  int _trayLevel = 1;
  double _zoom = 11.2;

  double _fromLat = 15;
  double _fromLng = 0;
  double _toLat = 0;
  double _toLng = 0;
  double _fromZoom = 1.55;
  double _toZoom = 11.2;

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )
      ..addListener(_tickFlight)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _flying = false);
        }
      });
  }

  @override
  void dispose() {
    _flight.dispose();
    _cards.dispose();
    _map.dispose();
    super.dispose();
  }

  double get _trayHeight => switch (_trayLevel) {
        0 => 56,
        2 => 330,
        _ => 205,
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

  void _tickFlight() {
    if (!_ready) return;
    final raw = _flight.value;
    final moveT = Curves.easeInOutCubic.transform(raw);
    final zoomT = Curves.easeInOutCubic.transform(
      ((raw - .06) / .94).clamp(0.0, 1.0),
    );
    final lat = _fromLat + (_toLat - _fromLat) * moveT;
    final lng = _wrap(_fromLng + _lngDelta(_fromLng, _toLng) * moveT);
    final zoom = _fromZoom + (_toZoom - _fromZoom) * zoomT;
    final rotation = -14 * (1 - moveT) + math.sin(math.pi * raw) * 2.5;
    try {
      _map.moveAndRotate(LatLng(lat, lng), zoom, rotation);
      _zoom = zoom;
    } catch (_) {}
  }

  void _startWorldFlight(DiscoveryLocation loc) {
    if (!_ready) return;
    _flight.stop();
    _selected = null;
    _fromLat = 15;
    _fromLng = 0;
    _toLat = loc.latitude;
    _toLng = loc.longitude;
    _fromZoom = 1.55;
    _toZoom = _zoomFor(loc.radiusKm);
    try {
      _map.moveAndRotate(const LatLng(15, 0), _fromZoom, -14);
    } catch (_) {}
    if (mounted) setState(() => _flying = true);
    _flight.forward(from: 0);
  }

  void _recenter(DiscoveryLocation loc) {
    if (!_ready) return;
    _flight.stop();
    try {
      final z = _zoomFor(loc.radiusKm);
      _map.moveAndRotate(LatLng(loc.latitude, loc.longitude), z, 0);
      _zoom = z;
    } catch (_) {}
    if (_flying && mounted) setState(() => _flying = false);
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
    if (c.contains('roommate') || c.contains('roommate')) return _Kind.roommate;
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
    if (_selected == item.key) {
      _open(item);
      return;
    }
    setState(() {
      _selected = item.key;
      if (_trayLevel == 0) _trayLevel = 1;
    });
    try {
      final targetZoom = math.max(_zoom, 13.2).toDouble();
      _map.move(
        LatLng(item.lat, item.lng),
        targetZoom,
        offset: const Offset(0, 80),
      );
      _zoom = targetZoom;
    } catch (_) {}
    final index = items.indexWhere((e) => e.key == item.key);
    if (index >= 0 && _cards.hasClients) {
      _cards.animateTo(
        index * 234.0,
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
          if (mounted) _startWorldFlight(next);
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

    return Material(
      color: const Color(0xFFF3F8FB),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: const LatLng(15, 0),
              initialZoom: 1.55,
              initialRotation: -14,
              minZoom: 1.2,
              maxZoom: 18,
              backgroundColor: const Color(0xFFF3F8FB),
              onMapReady: () {
                _ready = true;
                _zoom = 1.55;
                Future<void>.delayed(const Duration(milliseconds: 280), () {
                  if (mounted) _startWorldFlight(loc);
                });
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  _flight.stop();
                  _zoom = camera.zoom;
                  if (_flying && mounted) setState(() => _flying = false);
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
              if (loc.radiusKm <= 250)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(loc.latitude, loc.longitude),
                      radius: loc.radiusKm * 1000.0,
                      useRadiusInMeter: true,
                      color: const Color(0x123B82F6),
                      borderColor: const Color(0x88147DFF),
                      borderStrokeWidth: 1.2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 34,
                    height: 34,
                    rotate: true,
                    child: const _LocationDot(),
                  ),
                  for (final item in items)
                    Marker(
                      point: LatLng(item.lat, item.lng),
                      width: item.key == _selected ? 60 : 52,
                      height: item.key == _selected ? 70 : 62,
                      rotate: true,
                      alignment: Alignment.bottomCenter,
                      child: _Pin(
                        kind: item.kind,
                        selected: item.key == _selected,
                        onTap: () => _select(item, items),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_flying)
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Color(0x28FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
          if (_controlsVisible) ...[
            Positioned(
              top: pad.top + 12,
              left: 16,
              right: 16,
              child: _Header(
                filter: _filter,
                onMenu: () => setState(() => _menuOpen = !_menuOpen),
                onCities: () => setState(() {
                  _citiesOpen = !_citiesOpen;
                  _menuOpen = false;
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
                top: pad.top + 76,
                left: 16,
                child: _MapMenu(
                  onHide: _hideControls,
                  onCities: () => setState(() {
                    _citiesOpen = true;
                    _menuOpen = false;
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
                ),
              ),
            if (_citiesOpen)
              Positioned(
                top: pad.top + 126,
                left: 16,
                right: 16,
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
              right: 18,
              bottom: _trayHeight + pad.bottom + 32,
              child: Column(
                children: [
                  _CircleAction(
                    tooltip: 'Recenter on ${loc.city}',
                    icon: Icons.my_location_rounded,
                    onTap: () => _recenter(loc),
                  ),
                  const SizedBox(height: 12),
                  _CircleAction(
                    tooltip: 'Replay world-to-city flight',
                    icon: Icons.flight_takeoff_rounded,
                    dark: true,
                    onTap: () => _startWorldFlight(loc),
                  ),
                  const SizedBox(height: 12),
                  _CircleAction(
                    tooltip: 'Hide map controls',
                    icon: Icons.visibility_off_rounded,
                    onTap: _hideControls,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: pad.bottom + 16,
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
          ] else
            Positioned(
              top: pad.top + 16,
              right: 16,
              child: _CircleAction(
                tooltip: 'Show map controls',
                icon: Icons.visibility_rounded,
                dark: true,
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
    required this.onMenu,
    required this.onCities,
    required this.onSearch,
    required this.onFilter,
  });

  final String filter;
  final VoidCallback onMenu;
  final VoidCallback onCities;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              children: [
                _HeaderCircle(
                  tooltip: 'Map menu',
                  icon: Icons.menu_rounded,
                  onTap: onMenu,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 54,
                    decoration: _whitePanel(27),
                    child: TextField(
                      onChanged: onSearch,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search events, places...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: Colors.black54,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.black87,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 17),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _HeaderCircle(
                  tooltip: 'Choose city',
                  icon: Icons.location_city_rounded,
                  dark: true,
                  onTap: onCities,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final f = _filters[index];
              final active = f.id == filter;
              return Material(
                color: active ? Colors.black : const Color(0xF8FFFFFF),
                borderRadius: BorderRadius.circular(24),
                elevation: 2,
                shadowColor: Colors.black12,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onFilter(f.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          f.icon,
                          size: 16,
                          color: active ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          f.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: active ? Colors.white : Colors.black,
                            fontSize: 12,
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
  });

  final VoidCallback onHide;
  final VoidCallback onCities;
  final VoidCallback onRecenter;
  final VoidCallback onReplayFlight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 19, color: Colors.black87),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 8,
      shadowColor: Colors.black26,
      child: SizedBox(
        width: 210,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row(Icons.visibility_off_rounded, 'Hide map controls', onHide),
              row(Icons.location_city_rounded, 'Choose city', onCities),
              row(Icons.my_location_rounded, 'Recenter', onRecenter),
              row(Icons.flight_takeoff_rounded, 'Replay globe flight', onReplayFlight),
              const Divider(height: 10),
              row(Icons.close_rounded, 'Close map', onClose),
            ],
          ),
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
          color: Color(0x22000000),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    );

class _HeaderCircle extends StatelessWidget {
  const _HeaderCircle({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? Colors.black : Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Icon(
              icon,
              color: dark ? Colors.white : Colors.black,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF147DFF),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x44000000), blurRadius: 12),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final _Kind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: kind.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.14 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: 52,
            height: 62,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 31,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x30000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: kind.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(kind.icon, color: Colors.white, size: 21),
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

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? Colors.black : Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              icon,
              color: dark ? Colors.white : Colors.black,
              size: 24,
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      decoration: _whitePanel(28),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: level == 0 ? onExpand : onCollapse,
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -60) {
                onExpand();
              } else if (velocity > 60) {
                onCollapse();
              }
            },
            child: SizedBox(
              height: 20,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD0D6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Discover ${city.trim().isEmpty ? 'nearby' : city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (level > 0)
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
              IconButton(
                tooltip: level == 0 ? 'Expand tray' : 'Collapse tray',
                onPressed: level == 0 ? onExpand : onCollapse,
                icon: Icon(
                  level == 0
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
            ],
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
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
      scale: selected ? 1.025 : 1,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: selected ? 4 : 1,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onOpen,
          child: SizedBox(
            width: 224,
            child: Row(
              children: [
                Stack(
                  children: [
                    _Image(url: item.image, width: 94),
                    Positioned(
                      left: 7,
                      top: 7,
                      child: _Badge(kind: item.kind),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(item.kind.icon, size: 15, color: item.kind.color),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                item.kind.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: item.kind.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black54,
                            fontSize: 10.5,
                          ),
                        ),
                        if (item.detail.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black87,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (selected) ...[
                          const SizedBox(height: 7),
                          SizedBox(
                            height: 28,
                            child: TextButton(
                              onPressed: onOpen,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: kind.color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            kind.label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
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
