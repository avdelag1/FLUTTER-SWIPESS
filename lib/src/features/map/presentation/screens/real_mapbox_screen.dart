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
  String _activeCategory = 'all';
  bool _citiesOpen = false;
  bool _mapLoaded = false;
  int _annotationGeneration = 0;

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
    const size = 110.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = const ui.Offset(size / 2, size / 2 - 10);

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
      final radius = 22.0;
      final path = ui.Path();
      final width = radius * 2;
      final height = radius * 2.5;
      final left = center.dx - radius;
      final top = center.dy - radius;

      path.moveTo(center.dx, top + height);
      path.quadraticBezierTo(left, top + height * 0.7, left, top + radius);
      path.arcToPoint(
        ui.Offset(left + width, top + radius),
        radius: ui.Radius.circular(radius),
        clockwise: true,
      );
      path.quadraticBezierTo(
        left + width,
        top + height * 0.7,
        center.dx,
        top + height,
      );

      canvas.drawPath(
        path.shift(const ui.Offset(0, 4)),
        ui.Paint()
          ..color = Colors.black.withAlpha(45)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
      );

      canvas.drawPath(
        path,
        ui.Paint()
          ..color = Colors.white
          ..style = ui.PaintingStyle.fill,
      );

      final innerPath = ui.Path();
      final innerRadius = radius - 3.5;
      final innerWidth = innerRadius * 2;
      final innerHeight = height - 6.5;
      final innerLeft = center.dx - innerRadius;
      final innerTop = center.dy - innerRadius + 1.8;

      innerPath.moveTo(center.dx, innerTop + innerHeight);
      innerPath.quadraticBezierTo(
        innerLeft,
        innerTop + innerHeight * 0.7,
        innerLeft,
        innerTop + innerRadius,
      );
      innerPath.arcToPoint(
        ui.Offset(innerLeft + innerWidth, innerTop + innerRadius),
        radius: ui.Radius.circular(innerRadius),
        clockwise: true,
      );
      innerPath.quadraticBezierTo(
        innerLeft + innerWidth,
        innerTop + innerHeight * 0.7,
        center.dx,
        innerTop + innerHeight,
      );

      canvas.drawPath(innerPath, ui.Paint()..color = fill);

      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        ui.Offset(
          center.dx - painter.width / 2,
          top + radius - painter.height / 2,
        ),
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
      icon: Icons.domain_rounded,
      fill: const Color(0xFF14B8A6),
    );
    _peopleIcon ??= await _buildMarkerIcon(
      icon: Icons.person_rounded,
      fill: const Color(0xFF8B5CF6),
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
    final allPins = <MapPin>[];

    for (final listing in listings) {
      final cat = (listing.category ?? '').toLowerCase();
      final pin = _listingPin(listing, loc);
      if (_activeCategory == 'all') {
        allPins.add(pin);
      } else if (_activeCategory == 'events' && cat == 'event') {
        allPins.add(pin);
      } else if (_activeCategory == 'properties' && cat == 'property') {
        allPins.add(pin);
      } else if (_activeCategory == 'services' &&
          (cat == 'service' || cat == 'worker')) {
        allPins.add(pin);
      }
    }

    for (final profile in profiles) {
      final pin = _profilePin(profile, loc);
      if (_activeCategory == 'all' || _activeCategory == 'people') {
        allPins.add(pin);
      }
    }

    return allPins;
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
    if (_selected?.id == best.id && _selected?.isListing == best.isListing) {
      _openSelected();
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);

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
    ref.listen(mapListingsProvider, (_, __) => _renderAnnotations());
    ref.listen(mapProfilesProvider, (_, __) => _renderAnnotations());

    final visiblePins = _visiblePins();

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('swipess-real-mapbox'),
              styleUri: _lightStyle,
              onMapCreated: _setupMap,
              onMapLoadedListener: (_) async {
                _mapLoaded = true;
                await _prepareAnnotationManagers();
                await _renderAnnotations();
                _refreshDeviceLocation();
                await Future<void>.delayed(const Duration(milliseconds: 120));
                if (mounted) await _flyTo(ref.read(discoveryLocationProvider));
              },
            ),
          ),

          // Faded gradient behind top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withAlpha(240),
                      Colors.white.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircularIconButton(
                        icon: Icons.menu_rounded,
                        onTap:
                            widget.onClose ??
                            () => context.go(AppPaths.clientDashboard),
                      ),
                      Text(
                        'SWIPESS',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      _CircularIconButton(
                        icon: Icons.search_rounded,
                        onTap: () => setState(() => _citiesOpen = !_citiesOpen),
                      ),
                    ],
                  ),
                ),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        active: _activeCategory == 'all',
                        onTap: () {
                          setState(() {
                            _activeCategory = 'all';
                            _selected = null;
                          });
                          _renderAnnotations();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Events',
                        icon: Icons.music_note_rounded,
                        active: _activeCategory == 'events',
                        onTap: () {
                          setState(() {
                            _activeCategory = 'events';
                            _selected = null;
                          });
                          _renderAnnotations();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Properties',
                        icon: Icons.domain_rounded,
                        active: _activeCategory == 'properties',
                        onTap: () {
                          setState(() {
                            _activeCategory = 'properties';
                            _selected = null;
                          });
                          _renderAnnotations();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Services',
                        icon: Icons.room_service_rounded,
                        active: _activeCategory == 'services',
                        onTap: () {
                          setState(() {
                            _activeCategory = 'services';
                            _selected = null;
                          });
                          _renderAnnotations();
                        },
                      ),
                    ],
                  ),
                ),
              ],
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
            bottom: MediaQuery.paddingOf(context).bottom + 320,
            child: Column(
              children: [
                _GlassMapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'My location',
                  onTap: _flyToDevice,
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomListingSheet(
              pins: visiblePins,
              city: loc.city,
              selectedPin: _selected,
              onPinTap: (pin) {
                AppHaptics.medium();
                context.push(
                  pin.isListing ? '/listing/${pin.id}' : '/profile/${pin.id}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  const _CircularIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Icon(icon, color: Colors.black, size: 22),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(active ? 40 : 15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: active ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomListingSheet extends StatefulWidget {
  const _BottomListingSheet({
    required this.pins,
    required this.city,
    this.selectedPin,
    required this.onPinTap,
  });
  final List<MapPin> pins;
  final String city;
  final MapPin? selectedPin;
  final void Function(MapPin) onPinTap;

  @override
  State<_BottomListingSheet> createState() => _BottomListingSheetState();
}

class _BottomListingSheetState extends State<_BottomListingSheet> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _BottomListingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPin != null &&
        widget.selectedPin != oldWidget.selectedPin) {
      final idx = widget.pins.indexOf(widget.selectedPin!);
      if (idx != -1 && _scrollController.hasClients) {
        _scrollController.animateTo(
          idx * 280.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discover ${widget.city.isEmpty ? 'Nearby' : widget.city}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'See all',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF147DFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.pins.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 120, top: 40),
                child: Text(
                  'No results found.',
                  style: GoogleFonts.plusJakartaSans(color: Colors.black54),
                ),
              )
            else
              SizedBox(
                height: 250,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.pins.length,
                  itemBuilder: (context, i) {
                    final pin = widget.pins[i];
                    return _ListingCard(
                      pin: pin,
                      selected: pin == widget.selectedPin,
                      onTap: () => widget.onPinTap(pin),
                    );
                  },
                ),
              ),
            const SizedBox(height: 80), // Padding for the floating dock
          ],
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.pin,
    required this.selected,
    required this.onTap,
  });
  final MapPin pin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String imageUrl = '';
    String title = '';
    String subtitle = '';
    String price = '';
    String tag = 'PROPERTY';
    Color tagColor = const Color(0xFF14B8A6);

    if (pin.isListing && pin.listing != null) {
      title = pin.listing!.title ?? '';
      subtitle = pin.listing!.city ?? '';
      price = pin.listing!.formattedPrice;
      if (pin.listing!.images.isNotEmpty) {
        imageUrl = pin.listing!.images.first;
      }
      final cat = (pin.listing!.category ?? '').toLowerCase();
      if (cat == 'event') {
        tag = 'EVENT';
        tagColor = const Color(0xFF8B5CF6);
      } else if (cat == 'worker' || cat == 'service') {
        tag = 'SERVICE';
        tagColor = const Color(0xFFF43F5E);
      } else {
        tag = 'PROPERTY';
      }
    } else if (pin.profile != null) {
      title = pin.profile!.displayName;
      subtitle = pin.profile!.city ?? '';
      imageUrl = pin.profile!.avatarUrl ?? '';
      tag = 'PERSON';
      tagColor = const Color(0xFF8B5CF6);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 200,
        margin: const EdgeInsets.only(right: 16, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(selected ? 30 : 10),
              blurRadius: selected ? 15 : 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: selected ? Border.all(color: Colors.black, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            Container(color: Colors.grey[200]),
                      )
                    else
                      Container(color: Colors.grey[200]),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Colors.black54,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
