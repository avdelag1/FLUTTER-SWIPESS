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

/// Reliability-first browser map.
///
/// It starts directly on the selected discovery location at the correct zoom.
/// There is no HTML/platform Mapbox view and no annotation lifecycle that can
/// prevent the camera, radius, pins or controls from appearing.
class WebDiscoveryMapScreenV2 extends ConsumerStatefulWidget {
  const WebDiscoveryMapScreenV2({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<WebDiscoveryMapScreenV2> createState() =>
      _WebDiscoveryMapScreenV2State();
}

class _WebDiscoveryMapScreenV2State
    extends ConsumerState<WebDiscoveryMapScreenV2> {
  final MapController _mapController = MapController();

  bool _mapReady = false;
  bool _citiesOpen = false;
  String _layer = 'all';
  MapPin? _selected;
  double _zoom = 11.2;

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(mapListingsProvider);
      ref.invalidate(mapProfilesProvider);
    });
  }

  @override
  void dispose() {
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

  void _moveTo(double lat, double lng, {double? zoom}) {
    if (!_mapReady) return;
    final nextZoom = zoom ?? _zoom;
    try {
      _mapController.move(LatLng(lat, lng), nextZoom);
      _zoom = nextZoom;
    } catch (_) {}
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
    final meters = 100 + ((hash ~/ 360) % 8) * 42;
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

  MapPin _listingPin(dynamic listing, double centerLat, double centerLng) {
    if (listing.latitude != null && listing.longitude != null) {
      final p = _spreadPoint(
        listing.id,
        listing.latitude!,
        listing.longitude!,
        listing: true,
      );
      return MapPin.listingAt(listing, p.lat, p.lng);
    }
    final p = _cityPoint(
      listing.id,
      centerLat,
      centerLng,
      listing: true,
    );
    return MapPin.listingAt(listing, p.lat, p.lng);
  }

  MapPin _profilePin(dynamic profile, double centerLat, double centerLng) {
    if (profile.latitude != null && profile.longitude != null) {
      final p = _spreadPoint(
        profile.id,
        profile.latitude!,
        profile.longitude!,
        listing: false,
      );
      return MapPin.profileAt(profile, p.lat, p.lng);
    }
    final p = _cityPoint(
      profile.id,
      centerLat,
      centerLng,
      listing: false,
    );
    return MapPin.profileAt(profile, p.lat, p.lng);
  }

  void _selectPin(MapPin pin) {
    AppHaptics.selection();
    setState(() => _selected = pin);
    _moveTo(pin.lat, pin.lng, zoom: math.max(_zoom, 14.0));
  }

  void _openPin(MapPin pin) {
    AppHaptics.medium();
    context.push(pin.isListing ? '/listing/${pin.id}' : '/profile/${pin.id}');
  }

  void _setRange(int km) {
    ref.read(discoveryLocationProvider.notifier).setRadiusKm(km);
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
      if (previous.latitude == next.latitude &&
          previous.longitude == next.longitude &&
          previous.radiusKm == next.radiusKm &&
          previous.city == next.city) {
        return;
      }
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveTo(
          next.latitude,
          next.longitude,
          zoom: _zoomForRadius(next.radiusKm),
        );
      });
    });

    final listingRows = listingsAsync.value ?? const [];
    final profileRows = profilesAsync.value ?? const [];
    final pins = <MapPin>[
      if (_layer != 'people')
        for (final listing in listingRows)
          _listingPin(listing, loc.latitude, loc.longitude),
      if (_layer != 'listings')
        for (final profile in profileRows)
          _profilePin(profile, loc.latitude, loc.longitude),
    ];

    final center = LatLng(loc.latitude, loc.longitude);
    final loading = listingsAsync.isLoading || profilesAsync.isLoading;
    final failed = listingsAsync.hasError || profilesAsync.hasError;

    return Material(
      color: MapBasemap.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: targetZoom,
              minZoom: 2,
              maxZoom: 18,
              backgroundColor: MapBasemap.canvas,
              onMapReady: () {
                _mapReady = true;
                _zoom = targetZoom;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _moveTo(loc.latitude, loc.longitude, zoom: targetZoom);
                  }
                });
              },
              onTap: (_, _) {
                if (_selected != null) setState(() => _selected = null);
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _zoom = camera.zoom;
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
                      color: const Color(0x153B82F6),
                      borderColor: const Color(0xCC147DFF),
                      borderStrokeWidth: 1.4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 28,
                    height: 28,
                    child: const IgnorePointer(
                      child: _CenterDot(),
                    ),
                  ),
                  for (final pin in pins)
                    Marker(
                      point: LatLng(pin.lat, pin.lng),
                      width: 44,
                      height: 44,
                      child: _PinDot(
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
                    _CircleButton(
                      icon: Icons.close_rounded,
                      onTap: widget.onClose ??
                          () => context.go(AppPaths.clientDashboard),
                    ),
                    const SizedBox(width: 7),
                    _LabelButton(
                      label: 'CITIES',
                      icon: Icons.location_city_rounded,
                      selected: _citiesOpen,
                      onTap: () => setState(() => _citiesOpen = !_citiesOpen),
                    ),
                    const Spacer(),
                    _CountsPill(
                      layer: _layer,
                      listings: listingRows.length,
                      users: profileRows.length,
                      onLayer: (value) {
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
              right: 0,
              top: pad.top + 104,
              child: MapCityChips(
                activeCity: loc.city,
                onSelect: (city) {
                  final notifier = ref.read(discoveryLocationProvider.notifier);
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
                _CircleButton(
                  icon: Icons.add_rounded,
                  onTap: () => _moveTo(
                    _mapController.camera.center.latitude,
                    _mapController.camera.center.longitude,
                    zoom: (_zoom + 1).clamp(2.0, 18.0),
                  ),
                ),
                const SizedBox(height: 7),
                _CircleButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _moveTo(
                    _mapController.camera.center.latitude,
                    _mapController.camera.center.longitude,
                    zoom: (_zoom - 1).clamp(2.0, 18.0),
                  ),
                ),
                const SizedBox(height: 7),
                _CircleButton(
                  icon: Icons.my_location_rounded,
                  onTap: () => _moveTo(
                    loc.latitude,
                    loc.longitude,
                    zoom: targetZoom,
                  ),
                ),
              ],
            ),
          ),
          if (pins.isNotEmpty)
            Positioned(
              left: 12,
              right: 64,
              bottom: pad.bottom + 18,
              child: _ResultsRail(
                pins: pins,
                selected: _selected,
                onSelect: _selectPin,
                onOpen: _openPin,
              ),
            ),
          if (failed)
            Positioned(
              left: 12,
              bottom: pad.bottom + 82,
              child: _RetryButton(
                onTap: () {
                  ref.invalidate(mapListingsProvider);
                  ref.invalidate(mapProfilesProvider);
                },
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
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({required this.pin, required this.selected, required this.onTap});
  final MapPin pin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: selected ? 32 : 27,
            height: selected ? 32 : 27,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pin.isListing ? const Color(0xFF111318) : Colors.white,
              border: Border.all(
                color: pin.isListing ? Colors.white : const Color(0xFF111318),
                width: selected ? 3 : 2,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x44000000), blurRadius: 8),
              ],
            ),
            child: Icon(
              pin.isListing ? Icons.home_work_rounded : Icons.person_rounded,
              size: selected ? 16 : 14,
              color: pin.isListing ? Colors.white : const Color(0xFF111318),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC11141A),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withAlpha(70), width: .7),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _LabelButton extends StatelessWidget {
  const _LabelButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
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
              Icon(icon, color: fg, size: 15),
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
          _MiniChoice(label: 'ALL', active: layer == 'all', onTap: () => onLayer('all')),
          _MiniChoice(label: 'LISTINGS $listings', active: layer == 'listings', onTap: () => onLayer('listings')),
          _MiniChoice(label: 'USERS $users', active: layer == 'people', onTap: () => onLayer('people')),
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
          _MiniChoice(label: 'LOCAL', active: radiusKm <= 25, onTap: onLocal),
          _MiniChoice(label: 'REGION', active: radiusKm > 25 && radiusKm < 5000, onTap: onRegion),
          _MiniChoice(label: 'WORLD', active: radiusKm >= 5000, onTap: onWorld),
        ],
      ),
    );
  }
}

class _MiniChoice extends StatelessWidget {
  const _MiniChoice({required this.label, required this.active, required this.onTap});
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

class _ResultsRail extends StatelessWidget {
  const _ResultsRail({
    required this.pins,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });
  final List<MapPin> pins;
  final MapPin? selected;
  final ValueChanged<MapPin> onSelect;
  final ValueChanged<MapPin> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pins.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final pin = pins[index];
          final title = pin.isListing
              ? (pin.listing?.title ?? 'Listing')
              : (pin.profile?.displayName ?? 'Member');
          final meta = pin.isListing
              ? (pin.listing?.formattedPrice ?? '')
              : (pin.profile?.city ?? 'Nearby');
          final active = selected?.id == pin.id &&
              selected?.isListing == pin.isListing;
          return Material(
            color: const Color(0xE611141A),
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => active ? onOpen(pin) : onSelect(pin),
              child: Container(
                width: 148,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: active ? Colors.white : Colors.white.withAlpha(58),
                    width: active ? 1.4 : .7,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      pin.isListing ? Icons.home_work_rounded : Icons.person_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
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
                          if (meta.isNotEmpty)
                            Text(
                              meta,
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
