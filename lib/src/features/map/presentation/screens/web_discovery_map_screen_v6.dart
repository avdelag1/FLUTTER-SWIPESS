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

class WebDiscoveryMapScreenV5 extends ConsumerStatefulWidget {
  const WebDiscoveryMapScreenV5({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<WebDiscoveryMapScreenV5> createState() => _WebDiscoveryMapState();
}

enum _Kind {
  event,
  property,
  service,
  dining,
  motorcycle,
  bicycle,
  yacht,
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
        _Kind.motorcycle => const Color(0xFFFF7A18),
        _Kind.bicycle => const Color(0xFF22C55E),
        _Kind.yacht => const Color(0xFF3B82F6),
        _Kind.roommate => const Color(0xFF06B6D4),
        _Kind.seeker => const Color(0xFFEAB308),
        _Kind.buyer => const Color(0xFF2563EB),
        _Kind.renter => const Color(0xFF10B981),
        _Kind.person => const Color(0xFF6366F1),
      };

  IconData get icon => switch (this) {
        _Kind.event => Icons.music_note_rounded,
        _Kind.property => Icons.home_rounded,
        _Kind.service => Icons.room_service_rounded,
        _Kind.dining => Icons.restaurant_rounded,
        _Kind.motorcycle => Icons.two_wheeler_rounded,
        _Kind.bicycle => Icons.pedal_bike_rounded,
        _Kind.yacht => Icons.sailing_rounded,
        _Kind.roommate => Icons.group_rounded,
        _Kind.seeker => Icons.travel_explore_rounded,
        _Kind.buyer => Icons.sell_rounded,
        _Kind.renter => Icons.key_rounded,
        _Kind.person => Icons.person_rounded,
      };

  String get label => switch (this) {
        _Kind.event => 'EVENT',
        _Kind.property => 'PROPERTY',
        _Kind.service => 'SERVICE',
        _Kind.dining => 'DINING',
        _Kind.motorcycle => 'MOTO',
        _Kind.bicycle => 'BIKE',
        _Kind.yacht => 'YACHT',
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

class _Filter {
  const _Filter(this.id, this.title, this.icon);
  final String id;
  final String title;
  final IconData icon;
}

const _allFilters = <_Filter>[
  _Filter('all', 'All', Icons.grid_view_rounded),
  _Filter('events', 'Events', Icons.local_activity_outlined),
  _Filter('properties', 'Properties', Icons.home_outlined),
  _Filter('services', 'Services', Icons.room_service_outlined),
  _Filter('dining', 'Dining', Icons.restaurant_rounded),
  _Filter('yachts', 'Yachts', Icons.sailing_rounded),
  _Filter('motorcycles', 'Motos', Icons.two_wheeler_rounded),
  _Filter('bicycles', 'Bikes', Icons.pedal_bike_rounded),
  _Filter('roommates', 'Roommates', Icons.group_outlined),
  _Filter('seekers', 'Seekers', Icons.travel_explore_rounded),
  _Filter('buyers', 'Buyers', Icons.sell_outlined),
  _Filter('renters', 'Renters', Icons.key_rounded),
  _Filter('people', 'People', Icons.person_outline_rounded),
];

class _WebDiscoveryMapState extends ConsumerState<WebDiscoveryMapScreenV5>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  final _cards = ScrollController();
  late final AnimationController _flight;

  bool _ready = false;
  bool _citiesOpen = false;
  bool _flying = false;
  String _filter = 'all';
  String _query = '';
  String? _selected;
  double _zoom = 11.2;
  double _fromLat = 0;
  double _fromLng = 0;
  double _toLat = 0;
  double _toLng = 0;
  double _fromZoom = 2;
  double _toZoom = 11.2;

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
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

  double _zoomFor(int km) {
    if (km <= 5) return 13.2;
    if (km <= 10) return 12.3;
    if (km <= 25) return 11.2;
    if (km <= 50) return 10.2;
    if (km <= 100) return 9.2;
    if (km <= 250) return 8.0;
    if (km <= 1000) return 5.8;
    if (km <= 5000) return 3.2;
    return 2;
  }

  double _wrap(double value) {
    var v = value;
    while (v > 180) {
      v -= 360;
    }
    while (v < -180) {
      v += 360;
    }
    return v;
  }

  double _lngDelta(double from, double to) {
    var d = to - from;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d;
  }

  void _tickFlight() {
    if (!_ready) return;
    final raw = _flight.value;
    final moveT = Curves.easeInOutCubic.transform(raw);
    final zoomT = Curves.easeInOutCubic.transform(
      ((raw - .08) / .92).clamp(0.0, 1.0),
    );
    final lat = _fromLat + (_toLat - _fromLat) * moveT;
    final lng = _wrap(_fromLng + _lngDelta(_fromLng, _toLng) * moveT);
    final zoom = _fromZoom + (_toZoom - _fromZoom) * zoomT;
    final rotation = -22 * (1 - moveT) + math.sin(math.pi * raw) * 3.5;
    try {
      _map.moveAndRotate(LatLng(lat, lng), zoom, rotation);
      _zoom = zoom;
    } catch (_) {}
  }

  void _startFlight(DiscoveryLocation loc) {
    if (!_ready) return;
    _flight.stop();
    _selected = null;
    _fromLat = (loc.latitude - 23).clamp(-58.0, 58.0).toDouble();
    _fromLng = _wrap(loc.longitude - 78);
    _toLat = loc.latitude;
    _toLng = loc.longitude;
    _fromZoom = 2;
    _toZoom = _zoomFor(loc.radiusKm);
    try {
      _map.moveAndRotate(LatLng(_fromLat, _fromLng), 2, -22);
    } catch (_) {}
    if (mounted) setState(() => _flying = true);
    _flight.forward(from: 0);
  }

  void _moveTo(DiscoveryLocation loc) {
    if (!_ready) return;
    _flight.stop();
    try {
      _map.moveAndRotate(
        LatLng(loc.latitude, loc.longitude),
        _zoomFor(loc.radiusKm),
        0,
      );
      _zoom = _zoomFor(loc.radiusKm);
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
    final c = (listing.category ?? '').toLowerCase();
    if (c.contains('restaurant') || c.contains('dining') || c.contains('food')) {
      return _Kind.dining;
    }
    if (c.contains('worker') || c.contains('service') || c.contains('professional')) {
      return _Kind.service;
    }
    if (c.contains('motorcycle') || c.contains('moto')) return _Kind.motorcycle;
    if (c.contains('bicycle') || c.contains('bike')) return _Kind.bicycle;
    if (c.contains('yacht') || c.contains('boat') || c.contains('jet')) return _Kind.yacht;
    if (c.contains('roommate') || c.contains('room')) return _Kind.roommate;
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
      title: (listing.title ?? '').trim().isEmpty ? 'Swipess listing' : listing.title!.trim(),
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
    final location = '${event.location ?? ''} ${event.locationDetail ?? ''}'.trim();
    final known = ListingLocations.resolve(location) ?? ListingLocations.resolve(event.location ?? '');
    final p = _spread(
      'event:${event.id}',
      known?.lat ?? loc.latitude,
      known?.lng ?? loc.longitude,
      baseMeters: 180,
    );
    final image = event.imageUrl ?? (event.imageUrls.isNotEmpty ? event.imageUrls.first : '');
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
    final byType = switch (_filter) {
      'events' => item.kind == _Kind.event,
      'properties' => item.kind == _Kind.property,
      'services' => item.kind == _Kind.service,
      'dining' => item.kind == _Kind.dining,
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
    if (!byType) return false;
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
    setState(() => _selected = item.key);
    try {
      final targetZoom = math.max(_zoom, 13.2).toDouble();
      _map.move(
        LatLng(item.lat, item.lng),
        targetZoom,
        offset: const Offset(0, 86),
      );
      _zoom = targetZoom;
    } catch (_) {}
    final index = items.indexWhere((e) => e.key == item.key);
    if (index >= 0 && _cards.hasClients) {
      _cards.animateTo(
        index * 232.0,
        duration: const Duration(milliseconds: 200),
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
          if (mounted) _startFlight(next);
        });
      } else if (previous.radiusKm != next.radiusKm) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _moveTo(next);
        });
      }
    });

    final items = _items(loc, listings, profiles, events);
    _Item? selected;
    for (final item in items) {
      if (item.key == _selected) {
        selected = item;
        break;
      }
    }

    return Material(
      color: const Color(0xFFF2F7FA),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: LatLng(
                (loc.latitude - 23).clamp(-58.0, 58.0).toDouble(),
                _wrap(loc.longitude - 78),
              ),
              initialZoom: 2,
              initialRotation: -22,
              minZoom: 2,
              maxZoom: 18,
              backgroundColor: const Color(0xFFF2F7FA),
              onMapReady: () {
                _ready = true;
                _zoom = 2;
                Future<void>.delayed(const Duration(milliseconds: 350), () {
                  if (mounted) _startFlight(loc);
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
                      color: const Color(0x143B82F6),
                      borderColor: const Color(0x99147DFF),
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
                      width: item.key == _selected ? 58 : 50,
                      height: item.key == _selected ? 68 : 60,
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
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Colors.white.withAlpha(45), Colors.transparent],
                  ),
                ),
              ),
            ),
          Positioned(
            top: pad.top + 12,
            left: 16,
            right: 16,
            child: _Header(
              filter: _filter,
              citiesOpen: _citiesOpen,
              onMenu: widget.onClose ?? () => context.go(AppPaths.clientDashboard),
              onCities: () => setState(() => _citiesOpen = !_citiesOpen),
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
                    ref.read(discoveryLocationProvider.notifier).setRadiusKm(25);
                  }
                  setState(() => _citiesOpen = false);
                },
              ),
            ),
          Positioned(
            right: 18,
            bottom: (selected == null ? 244 : 218) + pad.bottom,
            child: Column(
              children: [
                _CircleAction(
                  icon: Icons.my_location_rounded,
                  onTap: () => _moveTo(loc),
                ),
                SizedBox(height: 12),
                _CircleAction(
                  icon: Icons.near_me_rounded,
                  dark: true,
                  onTap: () => _startFlight(loc),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: pad.bottom + 16,
            child: selected == null
                ? _Tray(
                    city: loc.city,
                    items: items,
                    controller: _cards,
                    selectedKey: _selected,
                    onTap: (item) => _select(item, items),
                    onOpen: _open,
                    onSeeAll: _seeAll,
                  )
                : _FocusedCard(
                    item: selected,
                    onClose: () => setState(() => _selected = null),
                    onOpen: () => _open(selected!),
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
    required this.citiesOpen,
    required this.onMenu,
    required this.onCities,
    required this.onSearch,
    required this.onFilter,
  });

  final String filter;
  final bool citiesOpen;
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
                _HeaderCircle(icon: Icons.menu_rounded, onTap: onMenu),
                SizedBox(width: 10),
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
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.black54),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.black87),
                        contentPadding: EdgeInsets.symmetric(vertical: 17),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                _HeaderCircle(
                  icon: Icons.tune_rounded,
                  dark: true,
                  active: citiesOpen,
                  onTap: onCities,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _allFilters.length,
            separatorBuilder: (_, __) => SizedBox(width: 8),
            itemBuilder: (context, index) {
              final f = _allFilters[index];
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
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.icon, size: 16, color: active ? Colors.white : Colors.black87),
                        SizedBox(width: 6),
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

BoxDecoration _whitePanel(double radius) => BoxDecoration(
      color: const Color(0xF8FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 8)),
      ],
    );

class _HeaderCircle extends StatelessWidget {
  const _HeaderCircle({
    required this.icon,
    required this.onTap,
    this.dark = false,
    this.active = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = dark || active;
    return Material(
      color: isDark ? Colors.black : Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 24),
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
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 12)],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.kind, required this.selected, required this.onTap});
  final _Kind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.14 : 1,
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
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(color: Color(0x30000000), blurRadius: 8, offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 46,
                height: 46,
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x30000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: kind.color, shape: BoxShape.circle),
                  child: Icon(kind.icon, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap, this.dark = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
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
          child: Icon(icon, color: dark ? Colors.white : Colors.black, size: 24),
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
    required this.onTap,
    required this.onOpen,
    required this.onSeeAll,
  });
  final String city;
  final List<_Item> items;
  final ScrollController controller;
  final String? selectedKey;
  final ValueChanged<_Item> onTap;
  final ValueChanged<_Item> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 205,
      padding: EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: _whitePanel(28),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Discover ${city.trim().isEmpty ? 'nearby' : city}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onSeeAll, child: Text('See all')),
            ],
          ),
          SizedBox(height: 4),
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
                    separatorBuilder: (_, __) => SizedBox(width: 10),
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
            width: 220,
            child: Row(
              children: [
                Stack(
                  children: [
                    _Image(url: item.image, width: 92),
                    Positioned(left: 7, top: 7, child: _Badge(kind: item.kind)),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        SizedBox(height: 6),
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
                          SizedBox(height: 5),
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

class _FocusedCard extends StatelessWidget {
  const _FocusedCard({required this.item, required this.onClose, required this.onOpen});
  final _Item item;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: _whitePanel(28),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _Image(url: item.image, width: 120),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Badge(kind: item.kind),
                          const Spacer(),
                          IconButton(onPressed: onClose, icon: Icon(Icons.close_rounded)),
                        ],
                      ),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 12),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: onOpen,
                          child: Text('View details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: kind.color, borderRadius: BorderRadius.circular(99)),
      child: Text(
        kind.label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
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
          child: Icon(Icons.image_outlined, color: Colors.black38),
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
