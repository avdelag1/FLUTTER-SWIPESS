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

/// Premium browser map that keeps the stable FlutterMap + Mapbox tile path.
/// The basemap is always bright and the existing world-to-city flight is kept.
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
      _WebDiscoveryMapScreenV5State();
}

enum _WebMapKind {
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

extension _WebMapKindStyle on _WebMapKind {
  Color get color {
    switch (this) {
      case _WebMapKind.event:
        return const Color(0xFF8B5CF6);
      case _WebMapKind.property:
        return const Color(0xFF14B8A6);
      case _WebMapKind.service:
        return const Color(0xFFF43F5E);
      case _WebMapKind.dining:
        return const Color(0xFFF97316);
      case _WebMapKind.motorcycle:
        return const Color(0xFFFF7A18);
      case _WebMapKind.bicycle:
        return const Color(0xFF22C55E);
      case _WebMapKind.yacht:
        return const Color(0xFF3B82F6);
      case _WebMapKind.roommate:
        return const Color(0xFF06B6D4);
      case _WebMapKind.seeker:
        return const Color(0xFFEAB308);
      case _WebMapKind.buyer:
        return const Color(0xFF2563EB);
      case _WebMapKind.renter:
        return const Color(0xFF10B981);
      case _WebMapKind.person:
        return const Color(0xFF6366F1);
    }
  }

  IconData get icon {
    switch (this) {
      case _WebMapKind.event:
        return Icons.music_note_rounded;
      case _WebMapKind.property:
        return Icons.home_rounded;
      case _WebMapKind.service:
        return Icons.room_service_rounded;
      case _WebMapKind.dining:
        return Icons.restaurant_rounded;
      case _WebMapKind.motorcycle:
        return Icons.two_wheeler_rounded;
      case _WebMapKind.bicycle:
        return Icons.pedal_bike_rounded;
      case _WebMapKind.yacht:
        return Icons.sailing_rounded;
      case _WebMapKind.roommate:
        return Icons.group_rounded;
      case _WebMapKind.seeker:
        return Icons.travel_explore_rounded;
      case _WebMapKind.buyer:
        return Icons.sell_rounded;
      case _WebMapKind.renter:
        return Icons.key_rounded;
      case _WebMapKind.person:
        return Icons.person_rounded;
    }
  }

  String get tag {
    switch (this) {
      case _WebMapKind.event:
        return 'EVENT';
      case _WebMapKind.property:
        return 'PROPERTY';
      case _WebMapKind.service:
        return 'SERVICE';
      case _WebMapKind.dining:
        return 'DINING';
      case _WebMapKind.motorcycle:
        return 'MOTO';
      case _WebMapKind.bicycle:
        return 'BIKE';
      case _WebMapKind.yacht:
        return 'YACHT';
      case _WebMapKind.roommate:
        return 'ROOMMATE';
      case _WebMapKind.seeker:
        return 'SEEKER';
      case _WebMapKind.buyer:
        return 'BUYER';
      case _WebMapKind.renter:
        return 'RENTER';
      case _WebMapKind.person:
        return 'PEOPLE';
    }
  }
}

class _WebMapItem {
  const _WebMapItem({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.detail,
    this.listing,
    this.profile,
    this.event,
  });

  final String id;
  final _WebMapKind kind;
  final double lat;
  final double lng;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String detail;
  final Listing? listing;
  final Profile? profile;
  final Event? event;

  String get key => '${kind.name}:$id';
}

class _FilterDef {
  const _FilterDef(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const _filters = <_FilterDef>[
  _FilterDef('all', 'All', Icons.grid_view_rounded),
  _FilterDef('events', 'Events', Icons.local_activity_outlined),
  _FilterDef('properties', 'Properties', Icons.home_outlined),
  _FilterDef('services', 'Services', Icons.room_service_outlined),
  _FilterDef('dining', 'Dining', Icons.restaurant_rounded),
  _FilterDef('yachts', 'Yachts', Icons.sailing_rounded),
  _FilterDef('motorcycles', 'Motos', Icons.two_wheeler_rounded),
  _FilterDef('bicycles', 'Bikes', Icons.pedal_bike_rounded),
  _FilterDef('roommates', 'Roommates', Icons.group_outlined),
  _FilterDef('seekers', 'Seekers', Icons.travel_explore_rounded),
  _FilterDef('buyers', 'Buyers', Icons.sell_outlined),
  _FilterDef('renters', 'Renters', Icons.key_rounded),
  _FilterDef('people', 'People', Icons.person_outline_rounded),
];

class _WebDiscoveryMapScreenV5State
    extends ConsumerState<WebDiscoveryMapScreenV5>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final ScrollController _trayController = ScrollController();
  late final AnimationController _flight;

  bool _mapReady = false;
  bool _citiesOpen = false;
  bool _flightRunning = false;
  String _activeFilter = 'all';
  String _searchQuery = '';
  String? _selectedKey;
  double _zoom = 11.2;

  double _fromLat = 0;
  double _fromLng = 0;
  double _toLat = 0;
  double _toLng = 0;
  double _fromZoom = 2.0;
  double _toZoom = 11.2;

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )
      ..addListener(_onFlightTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _flightRunning = false);
        }
      });
  }

  @override
  void dispose() {
    _flight
      ..removeListener(_onFlightTick)
      ..dispose();
    _trayController.dispose();
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
    return 2.0;
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
    final zoomT = Curves.easeInOutCubic.transform(
      ((raw - .08) / .92).clamp(0.0, 1.0),
    );
    final lat = _fromLat + (_toLat - _fromLat) * travelT;
    final lng = _wrapLng(
      _fromLng + _shortestLngDelta(_fromLng, _toLng) * travelT,
    );
    final zoom = _fromZoom + (_toZoom - _fromZoom) * zoomT;
    final rotation = -22.0 * (1 - travelT) + math.sin(math.pi * raw) * 3.5;
    try {
      _mapController.moveAndRotate(LatLng(lat, lng), zoom, rotation);
      _zoom = zoom;
    } catch (_) {}
  }

  void _startFlight(DiscoveryLocation loc) {
    if (!_mapReady) return;
    _flight.stop();
    _selectedKey = null;
    _fromLat = (loc.latitude - 23).clamp(-58.0, 58.0).toDouble();
    _fromLng = _wrapLng(loc.longitude - 78);
    _toLat = loc.latitude;
    _toLng = loc.longitude;
    _fromZoom = 2.0;
    _toZoom = _zoomForRadius(loc.radiusKm);
    try {
      _mapController.moveAndRotate(LatLng(_fromLat, _fromLng), _fromZoom, -22);
    } catch (_) {}
    if (mounted) setState(() => _flightRunning = true);
    _flight.forward(from: 0);
  }

  void _move(double lat, double lng, double zoom) {
    if (!_mapReady) return;
    _flight.stop();
    final safeZoom = zoom.clamp(2.0, 18.0).toDouble();
    try {
      _mapController.moveAndRotate(LatLng(lat, lng), safeZoom, 0);
      _zoom = safeZoom;
    } catch (_) {}
    if (_flightRunning && mounted) setState(() => _flightRunning = false);
  }

  ({double lat, double lng}) _spread(
    String key,
    double baseLat,
    double baseLng, {
    double minMeters = 80,
    double stepMeters = 35,
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
    var lat = loc.latitude;
    var lng = loc.longitude;
    final resolved = ListingLocations.resolve(city ?? '');
    if (resolved != null) {
      lat = resolved.lat;
      lng = resolved.lng;
    }
    return _spread(key, lat, lng, minMeters: 420, stepMeters: 110);
  }

  _WebMapKind _listingKind(Listing listing) {
    final category = (listing.category ?? '').trim().toLowerCase();
    if (category.contains('restaurant') ||
        category.contains('dining') ||
        category.contains('food')) {
      return _WebMapKind.dining;
    }
    if (category.contains('worker') ||
        category.contains('service') ||
        category.contains('professional')) {
      return _WebMapKind.service;
    }
    if (category.contains('motorcycle') || category == 'moto') {
      return _WebMapKind.motorcycle;
    }
    if (category.contains('bicycle') || category == 'bike') {
      return _WebMapKind.bicycle;
    }
    if (category.contains('yacht') ||
        category.contains('boat') ||
        category.contains('jet')) {
      return _WebMapKind.yacht;
    }
    if (category.contains('roommate') || category.contains('room')) {
      return _WebMapKind.roommate;
    }
    if (category.contains('seeker') || category.contains('request')) {
      return _WebMapKind.seeker;
    }
    if (category.contains('buyer')) return _WebMapKind.buyer;
    if (category.contains('renter')) return _WebMapKind.renter;
    return _WebMapKind.property;
  }

  _WebMapItem _listingItem(Listing listing, DiscoveryLocation loc) {
    final p = listing.latitude != null && listing.longitude != null
        ? _spread(listing.id, listing.latitude!, listing.longitude!)
        : _cityPoint(listing.id, listing.city, loc);
    return _WebMapItem(
      id: listing.id,
      kind: _listingKind(listing),
      lat: p.lat,
      lng: p.lng,
      title: (listing.title ?? '').trim().isEmpty
          ? 'Swipess listing'
          : listing.title!.trim(),
      subtitle: listing.formattedLocation,
      imageUrl: listing.primaryImage ?? '',
      detail: listing.formattedPrice,
      listing: listing,
    );
  }

  _WebMapItem _profileItem(Profile profile, DiscoveryLocation loc) {
    final p = profile.latitude != null && profile.longitude != null
        ? _spread(profile.id, profile.latitude!, profile.longitude!)
        : _cityPoint(profile.id, profile.city, loc);
    return _WebMapItem(
      id: profile.id,
      kind: _WebMapKind.person,
      lat: p.lat,
      lng: p.lng,
      title: profile.displayName,
      subtitle: profile.city ?? 'Nearby',
      imageUrl: profile.avatarUrl ?? '',
      detail: profile.role ?? 'Swipess member',
      profile: profile,
    );
  }

  _WebMapItem _eventItem(Event event, DiscoveryLocation loc) {
    final location = '${event.location ?? ''} ${event.locationDetail ?? ''}'.trim();
    final resolved = ListingLocations.resolve(location) ??
        ListingLocations.resolve(event.location ?? '');
    final p = _spread(
      'event:${event.id}',
      resolved?.lat ?? loc.latitude,
      resolved?.lng ?? loc.longitude,
      minMeters: 180,
      stepMeters: 70,
    );
    final image = event.imageUrl ??
        (event.imageUrls.isNotEmpty ? event.imageUrls.first : '');
    return _WebMapItem(
      id: event.id,
      kind: _WebMapKind.event,
      lat: p.lat,
      lng: p.lng,
      title: event.title,
      subtitle: event.location ?? event.locationDetail ?? loc.city,
      imageUrl: image,
      detail: event.price,
      event: event,
    );
  }

  bool _eventMatchesCity(Event event, DiscoveryLocation loc) {
    if (loc.radiusKm >= 500) return true;
    final city = loc.city.trim().toLowerCase();
    if (city.isEmpty || city == 'near you') return true;
    final text = '${event.location ?? ''} ${event.locationDetail ?? ''}'.toLowerCase();
    return text.trim().isEmpty || text.contains(city);
  }

  bool _matchesFilter(_WebMapItem item) {
    switch (_activeFilter) {
      case 'events':
        return item.kind == _WebMapKind.event;
      case 'properties':
        return item.kind == _WebMapKind.property;
      case 'services':
        return item.kind == _WebMapKind.service;
      case 'dining':
        return item.kind == _WebMapKind.dining;
      case 'yachts':
        return item.kind == _WebMapKind.yacht;
      case 'motorcycles':
        return item.kind == _WebMapKind.motorcycle;
      case 'bicycles':
        return item.kind == _WebMapKind.bicycle;
      case 'roommates':
        return item.kind == _WebMapKind.roommate;
      case 'seekers':
        return item.kind == _WebMapKind.seeker;
      case 'buyers':
        return item.kind == _WebMapKind.buyer;
      case 'renters':
        return item.kind == _WebMapKind.renter;
      case 'people':
        return item.kind == _WebMapKind.person;
      default:
        return true;
    }
  }

  List<_WebMapItem> _visibleItems(
    DiscoveryLocation loc,
    List<Listing> listings,
    List<Profile> profiles,
    List<Event> events,
  ) {
    final items = <_WebMapItem>[
      for (final listing in listings) _listingItem(listing, loc),
      for (final profile in profiles) _profileItem(profile, loc),
      for (final event in events)
        if (_eventMatchesCity(event, loc)) _eventItem(event, loc),
    ];
    final query = _searchQuery.trim().toLowerCase();
    return items.where((item) {
      if (!_matchesFilter(item)) return false;
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query) ||
          item.kind.tag.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  void _setFilter(String value) {
    AppHaptics.selection();
    setState(() {
      _activeFilter = value;
      _selectedKey = null;
    });
  }

  void _tapItem(_WebMapItem item, List<_WebMapItem> items) {
    AppHaptics.selection();
    if (_selectedKey == item.key) {
      _openItem(item);
      return;
    }
    setState(() => _selectedKey = item.key);
    try {
      _mapController.move(
        LatLng(item.lat, item.lng),
        math.max(_zoom, 13.2).toDouble(),
        offset: const Offset(0, 86),
      );
      _zoom = math.max(_zoom, 13.2).toDouble();
    } catch (_) {}
    final index = items.indexWhere((e) => e.key == item.key);
    if (index >= 0 && _trayController.hasClients) {
      _trayController.animateTo(
        index * 236.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openItem(_WebMapItem item) {
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
    switch (_activeFilter) {
      case 'events':
        context.push(AppPaths.exploreEvents);
        return;
      case 'services':
      case 'dining':
        context.push(AppPaths.exploreServices);
        return;
      default:
        context.push(AppPaths.clientFilters);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    final listingsAsync = ref.watch(mapListingsProvider);
    final profilesAsync = ref.watch(mapProfilesProvider);
    final eventsAsync = ref.watch(eventsListProvider);
    final pad = MediaQuery.paddingOf(context);

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null) return;
      if (previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.city != next.city) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startFlight(next);
        });
      } else if (previous.radiusKm != next.radiusKm) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _move(next.latitude, next.longitude, _zoomForRadius(next.radiusKm));
        });
      }
    });

    final listings = listingsAsync.value ?? const <Listing>[];
    final profiles = profilesAsync.value ?? const <Profile>[];
    final events = eventsAsync.value ?? const <Event>[];
    final items = _visibleItems(loc, listings, profiles, events);
    final selected = _selectedKey == null
        ? null
        : items.where((item) => item.key == _selectedKey).firstOrNull;
    final center = LatLng(loc.latitude, loc.longitude);

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(
          (loc.latitude - 23).clamp(-58.0, 58.0).toDouble(),
          _wrapLng(loc.longitude - 78),
        ),
        initialZoom: 2.0,
        initialRotation: -22,
        minZoom: 2,
        maxZoom: 18,
        backgroundColor: const Color(0xFFF2F7FA),
        onMapReady: () {
          _mapReady = true;
          _zoom = 2.0;
          Future<void>.delayed(const Duration(milliseconds: 350), () {
            if (mounted) _startFlight(loc);
          });
        },
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) {
            _flight.stop();
            _zoom = camera.zoom;
            if (_flightRunning && mounted) setState(() => _flightRunning = false);
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
                point: center,
                radius: loc.radiusKm * 1000.0,
                useRadiusInMeter: true,
                color: const Color(0x143B82F6),
                borderColor: const Color(0xAA147DFF),
                borderStrokeWidth: 1.2,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 34,
              height: 34,
              rotate: true,
              child: const _CurrentLocationDot(),
            ),
            for (final item in items)
              Marker(
                point: LatLng(item.lat, item.lng),
                width: item.key == _selectedKey ? 60 : 50,
                height: item.key == _selectedKey ? 70 : 60,
                rotate: true,
                alignment: Alignment.bottomCenter,
                child: _TeardropMarker(
                  kind: item.kind,
                  selected: item.key == _selectedKey,
                  onTap: () => _tapItem(item, items),
                ),
              ),
          ],
        ),
      ],
    );

    return Material(
      color: const Color(0xFFF2F7FA),
      child: Stack(
        fit: StackFit.expand,
        children: [
          map,
          if (_flightRunning)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Colors.white.withAlpha(50), Colors.transparent],
                  ),
                ),
              ),
            ),
          _TopChrome(
            topPadding: pad.top,
            activeFilter: _activeFilter,
            citiesOpen: _citiesOpen,
            onMenu: widget.onClose ?? () => context.go(AppPaths.clientDashboard),
            onCities: () => setState(() => _citiesOpen = !_citiesOpen),
            onFilter: _setFilter,
            onSearch: (value) => setState(() {
              _searchQuery = value;
              _selectedKey = null;
            }),
          ),
          if (_citiesOpen)
            Positioned(
              left: 16,
              right: 16,
              top: pad.top + 126,
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
            bottom: (selected == null ? 245 : 220) + pad.bottom,
            child: Column(
              children: [
                _MapActionButton(
                  icon: Icons.my_location_rounded,
                  dark: false,
                  onTap: () => _move(loc.latitude, loc.longitude, _zoomForRadius(loc.radiusKm)),
                ),
                const SizedBox(height: 12),
                _MapActionButton(
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
            bottom: 16 + pad.bottom,
            child: selected == null
                ? _DiscoveryTray(
                    items: items,
                    city: loc.city,
                    controller: _trayController,
                    selectedKey: _selectedKey,
                    onTap: (item) => _tapItem(item, items),
                    onOpen: _openItem,
                    onSeeAll: _openAll,
                  )
                : _SelectedItemTray(
                    item: selected,
                    onClose: () => setState(() => _selectedKey = null),
                    onOpen: () => _openItem(selected),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.topPadding,
    required this.activeFilter,
    required this.citiesOpen,
    required this.onMenu,
    required this.onCities,
    required this.onFilter,
    required this.onSearch,
  });

  final double topPadding;
  final String activeFilter;
  final bool citiesOpen;
  final VoidCallback onMenu;
  final VoidCallback onCities;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                children: [
                  _RoundButton(icon: Icons.menu_rounded, onTap: onMenu),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xF8FFFFFF),
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 22,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: onSearch,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search events, places...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.black87),
                          contentPadding: const EdgeInsets.symmetric(vertical: 17),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundButton(
                    icon: Icons.tune_rounded,
                    dark: true,
                    active: citiesOpen,
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
                final filter = _filters[index];
                return _FilterChipButton(
                  filter: filter,
                  active: activeFilter == filter.key,
                  onTap: () => onFilter(filter.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
    final bg = dark || active ? Colors.black : const Color(0xF8FFFFFF);
    final fg = dark || active ? Colors.white : Colors.black;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 54, height: 54, child: Icon(icon, color: fg, size: 24)),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.filter,
    required this.active,
    required this.onTap,
  });

  final _FilterDef filter;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.black : const Color(0xF8FFFFFF),
      borderRadius: BorderRadius.circular(23),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(filter.icon, size: 16, color: active ? Colors.white : Colors.black87),
              const SizedBox(width: 6),
              Text(
                filter.label,
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
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

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

class _TeardropMarker extends StatelessWidget {
  const _TeardropMarker({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final _WebMapKind kind;
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
              CustomPaint(
                size: const Size(50, 60),
                painter: _TeardropPainter(color: kind.color),
              ),
              Positioned(
                top: 12,
                child: Icon(kind.icon, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeardropPainter extends CustomPainter {
  const _TeardropPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..cubicTo(19, 49, 7, 38, 7, 25)
      ..arcToPoint(
        Offset(size.width - 7, 25),
        radius: const Radius.circular(18),
        clockwise: true,
      )
      ..cubicTo(size.width - 7, 38, 31, 49, size.width / 2, size.height)
      ..close();
    final shadow = Paint()
      ..color = Colors.black.withAlpha(42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path.shift(const Offset(0, 3)), shadow);
    canvas.drawPath(path, Paint()..color = Colors.white);
    final inner = Path()
      ..moveTo(size.width / 2, size.height - 4)
      ..cubicTo(20, 47, 11, 37, 11, 25)
      ..arcToPoint(
        Offset(size.width - 11, 25),
        radius: const Radius.circular(14),
        clockwise: true,
      )
      ..cubicTo(size.width - 11, 37, 30, 47, size.width / 2, size.height - 4)
      ..close();
    canvas.drawPath(inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter oldDelegate) => oldDelegate.color != color;
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.dark,
    required this.onTap,
  });

  final IconData icon;
  final bool dark;
  final VoidCallback onTap;

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

class _DiscoveryTray extends StatelessWidget {
  const _DiscoveryTray({
    required this.items,
    required this.city,
    required this.controller,
    required this.selectedKey,
    required this.onTap,
    required this.onOpen,
    required this.onSeeAll,
  });

  final List<_WebMapItem> items;
  final String city;
  final ScrollController controller;
  final String? selectedKey;
  final ValueChanged<_WebMapItem> onTap;
  final ValueChanged<_WebMapItem> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 205,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFAFFFFFF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), blurRadius: 28, offset: Offset(0, 10)),
        ],
      ),
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
          const SizedBox(height: 10),
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
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 6),
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

  final _WebMapItem item;
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
        shadowColor: Colors.black26,
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
                    _CardImage(url: item.imageUrl, width: 92),
                    Positioned(
                      left: 7,
                      top: 7,
                      child: _TagBadge(kind: item.kind),
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
                        const SizedBox(height: 6),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black54,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.detail.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
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

class _SelectedItemTray extends StatelessWidget {
  const _SelectedItemTray({
    required this.item,
    required this.onClose,
    required this.onOpen,
  });

  final _WebMapItem item;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFCFFFFFF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
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
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _CardImage(url: item.imageUrl, width: 120),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TagBadge(kind: item.kind),
                          const Spacer(),
                          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
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
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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
                          child: const Text('View details'),
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

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.kind});
  final _WebMapKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kind.color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        kind.tag,
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

class _CardImage extends StatelessWidget {
  const _CardImage({required this.url, required this.width});
  final String url;
  final double width;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.black38),
    );
    if (url.trim().isEmpty) return fallback;
    return SizedBox(
      width: width,
      height: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
