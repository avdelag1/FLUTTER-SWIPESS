import 'package:flutter_swipes/src/core/constants/listing_locations.dart';

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_chips.dart';
import 'package:geolocator/geolocator.dart' hide Position, LocationSettings;
import 'package:geolocator/geolocator.dart' as geo show LocationSettings;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class RealMapboxScreen extends ConsumerStatefulWidget {
  const RealMapboxScreen({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<RealMapboxScreen> createState() => _RealMapboxScreenState();
}

class _RealMapboxScreenState extends ConsumerState<RealMapboxScreen> {
  MapboxMap? _map;
  PointAnnotationManager? _listingManager;
  PointAnnotationManager? _peopleManager;
  PointAnnotationManager? _locationManager;
  PolygonAnnotationManager? _radiusManager;

  Uint8List? _listingIcon;
  Uint8List? _peopleIcon;
  Uint8List? _locationIcon;

  double? _deviceLatitude;
  double? _deviceLongitude;
  bool _requestingDeviceLocation = false;

  MapPin? _selected;
  String _layer = 'all';
  bool _citiesOpen = false;
  bool _mapLoaded = false;
  int _annotationGeneration = 0;

  static const _darkStyle =
      'mapbox://styles/avdelag123/cmshydgsr00xz01s65m0x6u4n';
  static const _lightStyle =
      'mapbox://styles/avdelag123/cmshyf3kh00gw01s9gu3yelwz';

  @override
  void initState() {
    super.initState();
    _citiesOpen = widget.showCitiesOnOpen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshDeviceLocation();
    });
  }

  Point _point(double lat, double lng) =>
      Point(coordinates: Position(lng, lat));

  double _zoomForRadius(int km) {
    if (km <= 5) return 13.2;
    if (km <= 10) return 12.3;
    if (km <= 25) return 11.2;
    if (km <= 50) return 10.2;
    if (km <= 100) return 9.2;
    if (km <= 250) return 8.0;
    if (km <= 1000) return 5.8;
    if (km <= 5000) return 3.2;
    return 1.45;
  }

  Future<void> _flyTo(DiscoveryLocation loc, {double? zoom}) async {
    final map = _map;
    if (map == null) return;
    await map.flyTo(
      CameraOptions(
        center: _point(loc.latitude, loc.longitude),
        zoom: zoom ?? _zoomForRadius(loc.radiusKm),
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 900, startDelay: 0),
    );
  }

  Future<void> _flyToDevice() async {
    if (_deviceLatitude == null || _deviceLongitude == null) {
      await _refreshDeviceLocation();
    }
    final map = _map;
    final lat = _deviceLatitude;
    final lng = _deviceLongitude;
    if (map == null || lat == null || lng == null) return;
    await map.flyTo(
      CameraOptions(center: _point(lat, lng), zoom: 14.5, pitch: 0, bearing: 0),
      MapAnimationOptions(duration: 650, startDelay: 0),
    );
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
        await _renderAnnotations();
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
      // Location permission/service is optional. The map remains fully usable;
      // we simply do not fake a blue "you are here" dot at a city centroid.
    } finally {
      _requestingDeviceLocation = false;
    }
  }

  Future<void> _setupMap(MapboxMap map) async {
    _map = map;
    await map.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(-25, 18)),
        zoom: 1.15,
        pitch: 0,
        bearing: 0,
      ),
    );
  }

  Future<Uint8List> _buildMarkerIcon({
    required IconData icon,
    required Color fill,
    bool location = false,
  }) async {
    const size = 88.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = const ui.Offset(size / 2, size / 2);

    if (location) {
      final halo = ui.Paint()..color = const Color(0x33147DFF);
      canvas.drawCircle(center, 31, halo);

      final shadow = ui.Paint()
        ..color = Colors.black.withAlpha(60)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
      canvas.drawCircle(center.translate(0, 2), 21, shadow);

      final whiteRing = ui.Paint()..color = Colors.white;
      canvas.drawCircle(center, 19, whiteRing);

      final blueDot = ui.Paint()..color = const Color(0xFF147DFF);
      canvas.drawCircle(center, 14.5, blueDot);
    } else {
      final shadow = ui.Paint()
        ..color = Colors.black.withAlpha(72)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7);
      canvas.drawCircle(center.translate(0, 3), 31, shadow);

      final outer = ui.Paint()..color = Colors.white;
      canvas.drawCircle(center, 31, outer);

      final inner = ui.Paint()..color = fill;
      canvas.drawCircle(center, 25.5, inner);

      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        ui.Offset((size - painter.width) / 2, (size - painter.height) / 2),
      );
    }

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _prepareAnnotationManagers() async {
    final map = _map;
    if (map == null) return;

    _radiusManager = await map.annotations.createPolygonAnnotationManager();
    _listingManager = await map.annotations.createPointAnnotationManager();
    _peopleManager = await map.annotations.createPointAnnotationManager();
    _locationManager = await map.annotations.createPointAnnotationManager();

    _listingIcon ??= await _buildMarkerIcon(
      icon: Icons.home_work_rounded,
      fill: const Color(0xFFFF6338),
    );
    _peopleIcon ??= await _buildMarkerIcon(
      icon: Icons.person_rounded,
      fill: const Color(0xFFE95B9B),
    );
    _locationIcon ??= await _buildMarkerIcon(
      icon: Icons.my_location_rounded,
      fill: const Color(0xFF147DFF),
      location: true,
    );

    _listingManager?.tapEvents(
      onTap: (annotation) {
        final p = annotation.geometry.coordinates;
        _selectNearest(p.lat.toDouble(), p.lng.toDouble(), listingOnly: true);
      },
    );
    _peopleManager?.tapEvents(
      onTap: (annotation) {
        final p = annotation.geometry.coordinates;
        _selectNearest(p.lat.toDouble(), p.lng.toDouble(), peopleOnly: true);
      },
    );
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
    final meters = 80 + ((hash ~/ 360) % 7) * 35;
    final latDelta = meters / 111320.0;
    final cosLat = math.cos(baseLat * math.pi / 180).abs();
    final lngDelta = meters / (111320.0 * (cosLat < .25 ? .25 : cosLat));
    return (
      lat: baseLat + math.sin(angle) * latDelta,
      lng: baseLng + math.cos(angle) * lngDelta,
    );
  }

  ({double lat, double lng}) _cityLevelPoint(
    dynamic item,
    DiscoveryLocation loc, {
    required bool listing,
  }) {
    final key = (item.id ?? '').toString();
    var hash = listing ? 97 : 193;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final ring = 0.008 + ((hash ~/ 360) % 7) * 0.0024;

    // Base the center on the item's actual city if possible, falling back to loc
    double centerLat = loc.latitude;
    double centerLng = loc.longitude;
    final itemCity = (item.city ?? '').toString().trim();
    if (itemCity.isNotEmpty) {
      final resolved = ListingLocations.resolve(itemCity);
      if (resolved != null) {
        centerLat = resolved.lat;
        centerLng = resolved.lng;
      }
    }

    final lat = centerLat + math.sin(angle) * ring;
    final cosLat = math.cos(centerLat * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    final lng = centerLng + (math.cos(angle) * ring / lngScale);
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
    final point = _cityLevelPoint(listing, loc, listing: true);
    return MapPin.listingAt(listing, point.lat, point.lng);
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
    final point = _cityLevelPoint(profile, loc, listing: false);
    return MapPin.profileAt(profile, point.lat, point.lng);
  }

  List<MapPin> _visiblePins() {
    final loc = ref.read(discoveryLocationProvider);
    final listings = ref.read(mapListingsProvider).value ?? const [];
    final profiles = ref.read(mapProfilesProvider).value ?? const [];
    return [
      if (_layer != 'people')
        for (final listing in listings) _listingPin(listing, loc),
      if (_layer != 'listings')
        for (final profile in profiles) _profilePin(profile, loc),
    ];
  }

  void _selectNearest(
    double lat,
    double lng, {
    bool listingOnly = false,
    bool peopleOnly = false,
  }) {
    final pins = _visiblePins();
    MapPin? best;
    var bestDistance = double.infinity;
    for (final pin in pins) {
      if (listingOnly && !pin.isListing) continue;
      if (peopleOnly && pin.isListing) continue;
      final dLat = pin.lat - lat;
      final dLng = pin.lng - lng;
      final distance = dLat * dLat + dLng * dLng;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = pin;
      }
    }
    if (best == null) return;
    AppHaptics.selection();
    setState(() => _selected = best);
    _map?.easeTo(
      CameraOptions(
        center: _point(best.lat, best.lng),
        zoom: 14.5,
        pitch: 0,
        bearing: 0,
        padding: MbxEdgeInsets(bottom: 155, left: 0, top: 0, right: 0),
      ),
      MapAnimationOptions(duration: 420, startDelay: 0),
    );
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
    if (!_mapLoaded ||
        _listingManager == null ||
        _peopleManager == null ||
        _locationManager == null ||
        _radiusManager == null) {
      return;
    }

    final generation = ++_annotationGeneration;
    final pins = _visiblePins();
    final loc = ref.read(discoveryLocationProvider);

    await Future.wait([
      _listingManager!.deleteAll(),
      _peopleManager!.deleteAll(),
      _locationManager!.deleteAll(),
      _radiusManager!.deleteAll(),
    ]);
    if (!mounted || generation != _annotationGeneration) return;

    if (loc.radiusKm <= 250) {
      await _radiusManager!.create(
        PolygonAnnotationOptions(
          geometry: _radiusPolygon(loc),
          fillColor: const Color(0xFF3B82F6).toARGB32(),
          fillOpacity: 0.12,
          fillOutlineColor: const Color(0xFF147DFF).toARGB32(),
        ),
      );
    }

    final deviceLat = _deviceLatitude;
    final deviceLng = _deviceLongitude;
    if (deviceLat != null && deviceLng != null) {
      await _locationManager!.create(
        PointAnnotationOptions(
          geometry: _point(deviceLat, deviceLng),
          image: _locationIcon,
          iconSize: 1.0,
          symbolSortKey: 10000,
        ),
      );
    }

    final listingOptions = <PointAnnotationOptions>[
      for (final pin in pins)
        if (pin.isListing)
          PointAnnotationOptions(
            geometry: _point(pin.lat, pin.lng),
            image: _listingIcon,
            iconSize: 1.08,
            symbolSortKey: 5000,
          ),
    ];
    if (listingOptions.isNotEmpty) {
      await _listingManager!.createMulti(listingOptions);
    }

    final peopleOptions = <PointAnnotationOptions>[
      for (final pin in pins)
        if (!pin.isListing)
          PointAnnotationOptions(
            geometry: _point(pin.lat, pin.lng),
            image: _peopleIcon,
            iconSize: 1.02,
            symbolSortKey: 6000,
          ),
    ];
    if (peopleOptions.isNotEmpty) {
      await _peopleManager!.createMulti(peopleOptions);
    }
  }

  void _openSelected() {
    final pin = _selected;
    if (pin == null) return;
    AppHaptics.medium();
    context.push(pin.isListing ? '/listing/${pin.id}' : '/profile/${pin.id}');
  }

  void _setRange(int km) {
    AppHaptics.selection();
    ref.read(discoveryLocationProvider.notifier).setRadiusKm(km);
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    final listingsAsync = ref.watch(mapListingsProvider);
    final profilesAsync = ref.watch(mapProfilesProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null ||
          previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.radiusKm != next.radiusKm ||
          previous.city != next.city) {
        _selected = null;
        _flyTo(next);
        _renderAnnotations();
      }
    });
    ref.listen(mapListingsProvider, (_, _) => _renderAnnotations());
    ref.listen(mapProfilesProvider, (_, _) => _renderAnnotations());

    final listingCount = listingsAsync.value?.length ?? 0;
    final peopleCount = profilesAsync.value?.length ?? 0;

    return Material(
      color: Colors.black,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: MapWidget(
                key: const ValueKey('swipess-real-mapbox'),
                styleUri: isLight ? _lightStyle : _darkStyle,
                onMapCreated: _setupMap,
                onMapLoadedListener: (_) async {
                  _mapLoaded = true;
                  await _prepareAnnotationManagers();
                  await _renderAnnotations();
                  _refreshDeviceLocation();
                  await Future<void>.delayed(const Duration(milliseconds: 120));
                  if (mounted) {
                    await _flyTo(ref.read(discoveryLocationProvider));
                  }
                },
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
                      _GlassMapButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap:
                            widget.onClose ??
                            () => context.go(AppPaths.clientDashboard),
                      ),
                      const SizedBox(width: 8),
                      _GlassMapLabelButton(
                        icon: Icons.location_city_rounded,
                        label: 'CITIES',
                        selected: _citiesOpen,
                        onTap: () => setState(() => _citiesOpen = !_citiesOpen),
                      ),
                      const Spacer(),
                      _LayerPill(
                        value: _layer,
                        listingCount: listingCount,
                        peopleCount: peopleCount,
                        onChanged: (value) {
                          AppHaptics.selection();
                          setState(() {
                            _layer = value;
                            _selected = null;
                          });
                          _renderAnnotations();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 58,
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
                top: MediaQuery.paddingOf(context).top + 106,
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
              bottom: MediaQuery.paddingOf(context).bottom + 88,
              child: Column(
                children: [
                  _GlassMapButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom in',
                    onTap: () async {
                      final map = _map;
                      if (map == null) return;
                      final camera = await map.getCameraState();
                      await map.easeTo(
                        CameraOptions(
                          zoom: math.min(camera.zoom + 1, 18),
                          pitch: 0,
                          bearing: 0,
                        ),
                        MapAnimationOptions(duration: 220, startDelay: 0),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _GlassMapButton(
                    icon: Icons.zoom_out_rounded,
                    tooltip: 'Zoom out',
                    onTap: () async {
                      final map = _map;
                      if (map == null) return;
                      final camera = await map.getCameraState();
                      await map.easeTo(
                        CameraOptions(
                          zoom: math.max(camera.zoom - 1, 1),
                          pitch: 0,
                          bearing: 0,
                        ),
                        MapAnimationOptions(duration: 220, startDelay: 0),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _GlassMapButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'My location',
                    onTap: _flyToDevice,
                  ),
                ],
              ),
            ),
            if (_selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
                child: _SelectedPinCard(
                  pin: _selected!,
                  onOpen: _openSelected,
                  onClose: () => setState(() => _selected = null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassMapButton extends StatelessWidget {
  const _GlassMapButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.black.withAlpha(82),
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(76),
                    width: .8,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMapLabelButton extends StatelessWidget {
  const _GlassMapLabelButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: selected
              ? Colors.white.withAlpha(218)
              : Colors.black.withAlpha(82),
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withAlpha(selected ? 225 : 76),
                  width: .8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: selected ? const Color(0xFF111318) : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: selected ? const Color(0xFF111318) : Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(70),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(58), width: .7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RangeChoice(
                icon: Icons.near_me_rounded,
                label: 'LOCAL',
                active: radiusKm <= 25,
                onTap: onLocal,
              ),
              _RangeChoice(
                icon: Icons.travel_explore_rounded,
                label: 'REGION',
                active: radiusKm > 25 && radiusKm < 5000,
                onTap: onRegion,
              ),
              _RangeChoice(
                icon: Icons.public_rounded,
                label: 'WORLD',
                active: radiusKm >= 5000,
                onTap: onWorld,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeChoice extends StatelessWidget {
  const _RangeChoice({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white.withAlpha(46) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerPill extends StatelessWidget {
  const _LayerPill({
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(74),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(58), width: .7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LayerChoice(
                icon: Icons.layers_rounded,
                label: 'ALL',
                active: value == 'all',
                onTap: () => onChanged('all'),
              ),
              _LayerChoice(
                icon: Icons.home_work_rounded,
                label: 'LISTINGS',
                active: value == 'listings',
                badge: listingCount,
                onTap: () => onChanged('listings'),
              ),
              _LayerChoice(
                icon: Icons.people_alt_rounded,
                label: 'USERS',
                active: value == 'people',
                badge: peopleCount,
                onTap: () => onChanged('people'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerChoice extends StatelessWidget {
  const _LayerChoice({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: badge == null ? 9 : 8),
        decoration: BoxDecoration(
          color: active ? Colors.white.withAlpha(46) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12.5),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Text(
                '$badge',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedPinCard extends StatelessWidget {
  const _SelectedPinCard({
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
        : (pin.profile?.displayName ?? 'Swipess member');
    final subtitle = pin.isListing
        ? (pin.listing?.formattedPrice ?? pin.listing?.city ?? 'Nearby listing')
        : (pin.profile?.city ?? 'Nearby member');

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: Colors.black.withAlpha(132),
          child: InkWell(
            onTap: onOpen,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withAlpha(58),
                  width: .7,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          (pin.isListing
                                  ? const Color(0xFFFF6338)
                                  : const Color(0xFFE95B9B))
                              .withAlpha(235),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      pin.isListing
                          ? Icons.home_work_rounded
                          : Icons.person_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
