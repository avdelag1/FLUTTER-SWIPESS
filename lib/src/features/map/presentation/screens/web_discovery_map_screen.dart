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

/// Browser discovery map.
///
/// The Mapbox Flutter 3.x web implementation is still a public preview and is
/// backed by an HTML platform view. On web we intentionally render the same
/// Swipess Mapbox style through flutter_map instead. That keeps every control,
/// marker and radius inside Flutter's own render tree, so no invisible browser
/// layer can swallow taps and no unsupported annotation API can block the map.
class WebDiscoveryMapScreen extends ConsumerStatefulWidget {
  const WebDiscoveryMapScreen({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<WebDiscoveryMapScreen> createState() =>
      _WebDiscoveryMapScreenState();
}

class _WebDiscoveryMapScreenState
    extends ConsumerState<WebDiscoveryMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _fly;

  bool _mapReady = false;
  bool _initialFlyDone = false;
  bool _citiesOpen = false;
  String _layer = 'all';
  MapPin? _selected;

  double _zoom = 3.0;
  LatLng _flyCenter = const LatLng(20.2114, -87.4654);
  double _flyStartZoom = 3.0;
  double _flyTargetZoom = 11.0;

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onFlyTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(mapListingsProvider);
      ref.invalidate(mapProfilesProvider);
    });
  }

  @override
  void dispose() {
    _fly
      ..removeListener(_onFlyTick)
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

  void _onFlyTick() {
    if (!_mapReady) return;
    final t = Curves.easeOutCubic.transform(_fly.value);
    final z = _flyStartZoom + (_flyTargetZoom - _flyStartZoom) * t;
    try {
      _mapController.move(_flyCenter, z);
      _zoom = z;
    } catch (_) {}
  }

  void _flyTo(DiscoveryLocation loc, {double? zoom, bool fromWorld = false}) {
    if (!_mapReady) return;
    _fly.stop();
    _flyCenter = LatLng(loc.latitude, loc.longitude);
    _flyStartZoom = fromWorld ? 3.0 : _zoom;
    _flyTargetZoom = zoom ?? _zoomForRadius(loc.radiusKm);
    try {
      _mapController.move(_flyCenter, _flyStartZoom);
    } catch (_) {}
    _fly.forward(from: 0);
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
    final meters = 105 + ((hash ~/ 360) % 8) * 46;
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
    DiscoveryLocation loc, {
    required bool listing,
  }) {
    var hash = listing ? 97 : 193;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final ring = 0.008 + ((hash ~/ 360) % 7) * 0.0024;
    final lat = loc.latitude + math.sin(angle) * ring;
    final cosLat = math.cos(loc.latitude * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    final lng = loc.longitude + math.cos(angle) * ring / lngScale;
    return (lat: lat, lng: lng);
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

  void _selectPin(MapPin pin) {
    AppHaptics.selection();
    setState(() => _selected = pin);
    final loc = ref.read(discoveryLocationProvider);
    _flyTo(
      loc.copyWith(latitude: pin.lat, longitude: pin.lng),
      zoom: 14.2,
    );
  }

  void _openPin(MapPin pin) {
    AppHaptics.medium();
    context.push(pin.isListing ? '/listing/${pin.id}' : '/profile/${pin.id}');
  }

  void _setRange(int km) {
    AppHaptics.selection();
    ref.read(discoveryLocationProvider.notifier).setRadiusKm(km);
  }

  void _changeZoom(double delta) {
    if (!_mapReady) return;
    _fly.stop();
    final next = (_zoom + delta).clamp(2.0, 18.0).toDouble();
    try {
      _mapController.move(_mapController.camera.center, next);
      _zoom = next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    final listingsAsync = ref.watch(mapListingsProvider);
    final profilesAsync = ref.watch(mapProfilesProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final pad = MediaQuery.paddingOf(context);

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null) return;
      if (previous.latitude == next.latitude &&
          previous.longitude == next.longitude &&
          previous.radiusKm == next.radiusKm &&
          previous.city == next.city) {
        return;
      }
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flyTo(next);
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

    final listingCount = listingRows.length;
    final peopleCount = profileRows.length;
    final loading = listingsAsync.isLoading || profilesAsync.isLoading;
    final failed = listingsAsync.hasError || profilesAsync.hasError;
    final center = LatLng(loc.latitude, loc.longitude);

    return Material(
      color: MapBasemap.canvas,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 3.0,
                minZoom: 2,
                maxZoom: 18,
                backgroundColor: MapBasemap.canvas,
                onMapReady: () {
                  _mapReady = true;
                  if (!_initialFlyDone) {
                    _initialFlyDone = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _flyTo(loc, fromWorld: true);
                    });
                  }
                },
                onTap: (_, _) {
                  if (_selected != null) setState(() => _selected = null);
                },
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && !_fly.isAnimating) _zoom = camera.zoom;
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
                  keepBuffer: 4,
                  panBuffer: 2,
                ),
                if (loc.radiusKm <= 1000)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: loc.radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: const Color(0x173B82F6),
                        borderColor: const Color(0xCC147DFF),
                        borderStrokeWidth: 1.4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      child: IgnorePointer(
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF147DFF),
                            border: Border.all(color: Colors.white, width: 2.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    for (final pin in pins)
                      Marker(
                        point: LatLng(pin.lat, pin.lng),
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        child: _PinMarker(
                          pin: pin,
                          selected: _selected?.id == pin.id &&
                              _selected?.isListing == pin.isListing,
                          onTap: () => _selectPin(pin),
                        ),
                      ),
                  ],
                ),
              ],
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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WebIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: widget.onClose ??
                            () => context.go(AppPaths.clientDashboard),
                      ),
                      const SizedBox(width: 7),
                      _WebLabelButton(
                        icon: Icons.location_city_rounded,
                        label: 'CITIES',
                        selected: _citiesOpen,
                        onTap: () => setState(() {
                          _citiesOpen = !_citiesOpen;
                        }),
                      ),
                      const Spacer(),
                      _WebLayerPill(
                        value: _layer,
                        listingCount: listingCount,
                        peopleCount: peopleCount,
                        onChanged: (value) {
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
              child: _WebRangePill(
                radiusKm: loc.radiusKm,
                onLocal: () => _setRange(5),
                onRegion: () => _setRange(100),
                onWorld: () => _setRange(20000),
              ),
            ),
            if (_citiesOpen)
              Positioned(
                left: 0,
                right: 0,
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
            Positioned(
              right: 12,
              bottom: pad.bottom + 88,
              child: Column(
                children: [
                  _WebIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom in',
                    onTap: () => _changeZoom(1),
                  ),
                  const SizedBox(height: 7),
                  _WebIconButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom out',
                    onTap: () => _changeZoom(-1),
                  ),
                  const SizedBox(height: 7),
                  _WebIconButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Selected location',
                    onTap: () => _flyTo(loc),
                  ),
                ],
              ),
            ),
            if (_selected == null && pins.isNotEmpty)
              Positioned(
                left: 12,
                right: 62,
                bottom: pad.bottom + 18,
                child: _WebResultStrip(
                  pins: pins,
                  onSelect: _selectPin,
                  onOpen: _openPin,
                ),
              ),
            if (_selected != null)
              Positioned(
                left: 12,
                right: 62,
                bottom: pad.bottom + 18,
                child: _WebSelectedCard(
                  pin: _selected!,
                  onOpen: () => _openPin(_selected!),
                  onClose: () => setState(() => _selected = null),
                ),
              ),
            if (failed)
              Positioned(
                left: 12,
                bottom: pad.bottom + 82,
                child: _WebRetryButton(
                  onTap: () {
                    ref.invalidate(mapListingsProvider);
                    ref.invalidate(mapProfilesProvider);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({
    required this.pin,
    required this.selected,
    required this.onTap,
  });

  final MapPin pin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 37.0 : 31.0;
    final fill = pin.isListing ? const Color(0xFF111318) : Colors.white;
    final ink = pin.isListing ? Colors.white : const Color(0xFF111318);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: selected ? const Color(0xFF60A5FA) : Colors.white,
                width: selected ? 2.6 : 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              pin.isListing ? Icons.home_work_rounded : Icons.person_rounded,
              color: ink,
              size: selected ? 18 : 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _WebIconButton extends StatelessWidget {
  const _WebIconButton({
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
        color: const Color(0xB311141A),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withAlpha(70), width: .7),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}

class _WebLabelButton extends StatelessWidget {
  const _WebLabelButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? const Color(0xFF111318) : Colors.white;
    return Material(
      color: selected ? const Color(0xE8FFFFFF) : const Color(0xB311141A),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withAlpha(selected ? 215 : 70),
              width: .7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ink, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
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

class _WebRangePill extends StatelessWidget {
  const _WebRangePill({
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
        color: const Color(0xA611141A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(54), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WebChoice(
            label: 'LOCAL',
            active: radiusKm <= 25,
            onTap: onLocal,
          ),
          _WebChoice(
            label: 'REGION',
            active: radiusKm > 25 && radiusKm < 5000,
            onTap: onRegion,
          ),
          _WebChoice(
            label: 'WORLD',
            active: radiusKm >= 5000,
            onTap: onWorld,
          ),
        ],
      ),
    );
  }
}

class _WebLayerPill extends StatelessWidget {
  const _WebLayerPill({
    required this.value,
    required this.listingCount,
    required this.peopleCount,
    required this.onChanged,
  });

  final String value;
  final int listingCount;
  final int peopleCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xB311141A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(54), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WebChoice(
            label: 'ALL',
            active: value == 'all',
            onTap: () => onChanged('all'),
          ),
          _WebChoice(
            label: 'LISTINGS $listingCount',
            active: value == 'listings',
            onTap: () => onChanged('listings'),
          ),
          _WebChoice(
            label: 'USERS $peopleCount',
            active: value == 'people',
            onTap: () => onChanged('people'),
          ),
        ],
      ),
    );
  }
}

class _WebChoice extends StatelessWidget {
  const _WebChoice({
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
      color: active ? Colors.white.withAlpha(45) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 8.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebResultStrip extends StatelessWidget {
  const _WebResultStrip({
    required this.pins,
    required this.onSelect,
    required this.onOpen,
  });

  final List<MapPin> pins;
  final ValueChanged<MapPin> onSelect;
  final ValueChanged<MapPin> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: pins.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final pin = pins[index];
          final title = pin.isListing
              ? (pin.listing?.title ?? 'Listing')
              : (pin.profile?.displayName ?? 'Member');
          final subtitle = pin.isListing
              ? (pin.listing?.formattedPrice ?? '')
              : (pin.profile?.city ?? 'Nearby');

          return Material(
            color: const Color(0xD911141A),
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(pin),
              onDoubleTap: () => onOpen(pin),
              child: Container(
                width: 145,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withAlpha(58),
                    width: .7,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      pin.isListing
                          ? Icons.home_work_rounded
                          : Icons.person_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(165),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WebSelectedCard extends StatelessWidget {
  const _WebSelectedCard({
    required this.pin,
    required this.onOpen,
    required this.onClose,
  });

  final MapPin pin;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = pin.isListing
        ? (pin.listing?.title ?? 'Listing')
        : (pin.profile?.displayName ?? 'Member');
    final subtitle = pin.isListing
        ? (pin.listing?.formattedLocation ?? 'Nearby listing')
        : (pin.profile?.city ?? 'Nearby member');

    return Material(
      color: const Color(0xEB11141A),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: 58,
          padding: const EdgeInsets.fromLTRB(10, 7, 5, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(64), width: .7),
          ),
          child: Row(
            children: [
              Icon(
                pin.isListing
                    ? Icons.home_work_rounded
                    : Icons.person_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(165),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withAlpha(170),
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebRetryButton extends StatelessWidget {
  const _WebRetryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD911141A),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
