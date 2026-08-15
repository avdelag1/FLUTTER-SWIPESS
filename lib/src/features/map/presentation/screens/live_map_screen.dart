import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/data/map_basemap.dart';
import 'package:flutter_swipes/src/features/map/data/map_camera.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/features/map/data/map_cluster.dart';
import 'package:flutter_swipes/src/features/map/data/map_demo_pins.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_bottom_dock.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_chips.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_sheet.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_gps_dot.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_layer_rail.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_pin_markers.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_perspective_stage.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_preview_card.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_results_rail.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

/// Cap PassportMap / live map — 3D satellite fly-in, listings + people.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({
    super.key,
    this.asOverlay = false,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final bool asOverlay;
  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen>
    with SingleTickerProviderStateMixin {
  String _layer = 'all'; // all | listings | people
  MapPin? _selected;
  bool _radiusOpen = false;
  bool _citiesOpen = false;
  final _mapController = MapController();
  double _zoom = MapCameraMath.openAltitudeZoom;
  late final AnimationController _fly;
  bool _didFly = false;
  bool _mapReady = false;
  bool _hudVisible = true;
  Timer? _hudTimer;

  static const _radiusOptions = [5, 10, 25, 50, 100, 200];

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: MapCameraMath.openGlideMs),
    );
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _fly.stop();
    _fly.dispose();
    _mapController.dispose();
    super.dispose();
  }

  double _zoomForRadius(int km) => MapCameraMath.zoomForRadiusKm(km);

  void _revealHud() {
    _hudTimer?.cancel();
    if (!_hudVisible && mounted) setState(() => _hudVisible = true);
    _hudTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      if (_citiesOpen || _selected != null) {
        _revealHud();
        return;
      }
      setState(() {
        _hudVisible = false;
        _radiusOpen = false;
      });
    });
  }

  void _safeMove(LatLng dest, double zoom) {
    if (!_mapReady) return;
    try {
      _mapController.move(dest, zoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(discoveryLocationProvider);
    ref.listen(discoveryLocationProvider, (prev, next) {
      if (prev == null) return;
      if (prev.latitude == next.latitude &&
          prev.longitude == next.longitude &&
          prev.radiusKm == next.radiusKm) {
        return;
      }
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeMove(
          LatLng(next.latitude, next.longitude),
          _zoomForRadius(next.radiusKm),
        );
      });
    });
    final asyncListings = ref.watch(mapListingsProvider);
    final asyncProfiles = ref.watch(mapProfilesProvider);
    final center = LatLng(location.latitude, location.longitude);
    final radiusKm = location.radiusKm;
    final isLight = ref.watch(isLightThemeProvider);

    final listingsRaw = asyncListings.value ?? [];
    final profiles = asyncProfiles.value ?? [];
    final isLoading = asyncListings.isLoading || asyncProfiles.isLoading;
    final listings = listingsForMap(listingsRaw, center, location.city);
    final people = peopleForMap(profiles, center, location.city);
    const haversine = Distance();
    bool inRadius(double lat, double lng) {
      return haversine.as(
            LengthUnit.Kilometer,
            center,
            LatLng(lat, lng),
          ) <=
          radiusKm;
    }

    final listingPins = [
      if (_layer != 'people')
        ...listings
            .where((l) =>
                l.latitude != null &&
                l.longitude != null &&
                inRadius(l.latitude!, l.longitude!))
            .map(MapPin.listing),
    ];
    final profilePins = [
      if (_layer != 'listings')
        ...people
            .where((p) =>
                p.latitude != null &&
                p.longitude != null &&
                inRadius(p.latitude!, p.longitude!))
            .map(MapPin.profile),
    ];
    final allPins = [...listingPins, ...profilePins];
    final filtered = allPins;
    final clusters = clusterMapPins(filtered, _zoom);
    final pad = MediaQuery.paddingOf(context);

    return Material(
      color: MapBasemap.canvas,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _fly,
              builder: (context, map) => MapPerspectiveStage(
                progress: _didFly ? _fly.value : 0,
                child: map!,
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _zoomForRadius(radiusKm),
                  minZoom: 3,
                  maxZoom: 18,
                  backgroundColor: MapBasemap.canvas,
                  onMapReady: () {
                    _mapReady = true;
                    _didFly = true;
                    _safeMove(center, MapCameraMath.openAltitudeZoom);
                    void flyCamera() {
                      if (!_mapReady) return;
                      final eased = Curves.easeOutCubic.transform(_fly.value);
                      final target = _zoomForRadius(radiusKm);
                      _safeMove(
                        center,
                        MapCameraMath.openAltitudeZoom +
                            (target - MapCameraMath.openAltitudeZoom) * eased,
                      );
                      if (_fly.isCompleted) _fly.removeListener(flyCamera);
                    }
                    _fly.addListener(flyCamera);
                    _fly.forward(from: 0);
                  },
                  onTap: (_, _) => setState(() {
                    _selected = null;
                    _radiusOpen = false;
                  }),
                  onPositionChanged: (pos, _) {
                    final z = pos.zoom;
                    if (_fly.isAnimating) {
                      _zoom = z;
                      return;
                    }
                    if ((z - _zoom).abs() > 0.15) {
                      setState(() => _zoom = z);
                    }
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
                  ),
                  if (MapBasemap.labelsUrl case final labels?)
                    TileLayer(
                      urlTemplate: labels,
                      subdomains: MapBasemap.subdomains,
                      userAgentPackageName: MapBasemap.userAgentPackageName,
                      tileDimension: 256,
                      maxNativeZoom: 20,
                    ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: MapBasemap.radiusFill,
                        borderColor: MapBasemap.radiusStroke,
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const MapGpsDot(),
                      ),
                      for (final c in clusters)
                        if (c.count == 1)
                          _pinMarker(
                            c.pins.first,
                            selected: _selected != null &&
                                _samePin(_selected!, c.pins.first),
                          )
                        else
                          Marker(
                            point: c.point,
                            width: c.count >= 10 ? 56 : 48,
                            height: c.count >= 10 ? 56 : 48,
                            child: GestureDetector(
                              onTap: () {
                                AppHaptics.selection();
                                _safeMove(
                                  c.point,
                                  math.min(_zoom + 1.6, 16),
                                );
                              },
                              child: MapClusterMarker(count: c.count),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
              ),
            ),
          if (isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFFFF4D00),
                backgroundColor: Colors.transparent,
              ),
            ),

          SafeArea(
            child: _MapHudVisibility(
              visible: _hudVisible,
              child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MapHudCircle(
                    icon: Icons.close_rounded,
                    onTap: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  MapHudCircle(
                    icon: Icons.search_rounded,
                    onTap: () => setState(() {
                      _citiesOpen = !_citiesOpen;
                      _radiusOpen = false;
                    }),
                  ),
                  const Spacer(),
                ],
              ),
              ),
            ),
          ),

          Positioned(
            top: pad.top + 56,
            left: 0,
            right: 64,
            child: _MapHudVisibility(
              visible: _hudVisible,
              child: MapCityChips(
              activeCity: location.city,
              onSelect: (city) {
                ref.read(discoveryLocationProvider.notifier).setCoordinates(
                      city: city.name,
                      country: city.country,
                      latitude: city.lat,
                      longitude: city.lng,
                    );
                _didFly = false;
                _safeMove(
                  LatLng(city.lat, city.lng),
                  _zoomForRadius(radiusKm),
                );
                setState(() {
                  _citiesOpen = false;
                  _selected = null;
                });
              },
              ),
            ),
          ),

          Positioned(
            right: 12,
            top: pad.top + 60,
            child: _MapHudVisibility(
              visible: _hudVisible,
              child: MapLayerRail(
              layer: _layer,
              listingCount: listingPins.length,
              peopleCount: profilePins.length,
              onLayer: (layer) => setState(() {
                _layer = layer;
                _selected = null;
              }),
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: pad.bottom + 12,
            child: _MapHudVisibility(
              visible: _hudVisible,
              child: MapBottomDock(
              preview: _selected == null
                  ? null
                  : MapPreviewCard(
                      pin: _selected!,
                      onOpen: _openSelected,
                      onClose: () => setState(() => _selected = null),
                    ),
              rail: MapResultsRail(
                pins: filtered,
                selectedId: _selected?.id,
                onSelect: (pin) {
                  setState(() => _selected = pin);
                  _safeMove(LatLng(pin.lat, pin.lng), math.max(_zoom, 11));
                },
              ),
              hud: MapGpsHud(
                locateButton: GestureDetector(
                  onTap: () {
                    _locateGps();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                ),
                radiusChip: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_radiusOpen)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0A0D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final km in _radiusOptions)
                              GestureDetector(
                                onTap: () {
                                  AppHaptics.selection();
                                  ref
                                      .read(discoveryLocationProvider.notifier)
                                      .setRadiusKm(km);
                                  _safeMove(center, _zoomForRadius(km));
                                  setState(() => _radiusOpen = false);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    '$km km',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: km == radiusKm
                                          ? const Color(0xFFFF4D00)
                                          : Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _radiusOpen = !_radiusOpen;
                      }),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xF2161B27),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white38,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$radiusKm km',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _radiusOpen
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                youAreHere: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xF2161B27),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You are here',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ),

          if (!_hudVisible)
            Positioned(
              top: pad.top + 12,
              right: 12,
              child: BreathingWidget(
                minOpacity: 0.55,
                child: Semantics(
                  button: true,
                  label: 'Show map controls',
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.light();
                      _revealHud();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xEFFFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFFFF4D00), blurRadius: 16),
                        ],
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF111318),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_citiesOpen)
            Positioned(
              left: 12,
              right: 12,
              top: pad.top + 104,
              bottom: pad.bottom + 24,
              child: MapCitySheet(
                onClose: () => setState(() => _citiesOpen = false),
                onPick: (city) {
                  ref.read(discoveryLocationProvider.notifier).setCoordinates(
                        city: city.name,
                        country: city.country,
                        latitude: city.lat,
                        longitude: city.lng,
                      );
                  _didFly = false;
                  _safeMove(
                    LatLng(city.lat, city.lng),
                    _zoomForRadius(radiusKm),
                  );
                  setState(() {
                    _citiesOpen = false;
                    _selected = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  void _openSelected() {
    if (_selected == null) return;
    if (_selected!.isListing) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ListingDetailScreen(listingData: _selected!.listing!),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(userId: _selected!.profile!.id),
        ),
      );
    }
  }

  Future<void> _locateGps() async {
    AppHaptics.medium();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final loc = ref.read(discoveryLocationProvider);
        _safeMove(
          LatLng(loc.latitude, loc.longitude),
          _zoomForRadius(loc.radiusKm),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      ref.read(discoveryLocationProvider.notifier).setCoordinates(
            city: 'Near you',
            country: '',
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      _safeMove(
        LatLng(pos.latitude, pos.longitude),
        _zoomForRadius(ref.read(discoveryLocationProvider).radiusKm),
      );
      ref.invalidate(mapListingsProvider);
      ref.invalidate(mapProfilesProvider);
    } catch (_) {
      final loc = ref.read(discoveryLocationProvider);
      _safeMove(
        LatLng(loc.latitude, loc.longitude),
        _zoomForRadius(loc.radiusKm),
      );
    }
  }

  static bool _samePin(MapPin a, MapPin b) {
    if (a.isListing != b.isListing) return false;
    if (a.isListing) return a.listing?.id == b.listing?.id;
    return a.profile?.id == b.profile?.id;
  }

  Marker _pinMarker(MapPin pin, {required bool selected}) {
    if (pin.isListing) {
      return Marker(
        point: LatLng(pin.lat, pin.lng),
        width: MapListingPinMarker.width,
        height: MapListingPinMarker.height,
        alignment: MapListingPinMarker.anchor,
        child: GestureDetector(
          onTap: () {
            AppHaptics.selection();
            setState(() => _selected = pin);
          },
          child: MapListingPinMarker(
            title: pin.listing?.title ?? 'Listing',
            imageUrl: pin.listing?.primaryImage,
            selected: selected,
          ),
        ),
      );
    }
    return Marker(
      point: LatLng(pin.lat, pin.lng),
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          setState(() => _selected = pin);
        },
        child: MapProfilePinMarker(
          imageUrl: pin.profile?.avatarUrl,
          selected: selected,
        ),
      ),
    );
  }
}

class _MapHudVisibility extends StatelessWidget {
  const _MapHudVisibility({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: visible ? 1 : 0.96,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}
