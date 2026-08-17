import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/domain/map_pin.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_city_chips.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// The real Mapbox-powered live map used by the dashboard overlay.
///
/// This intentionally uses Mapbox's vector renderer rather than `flutter_map`
/// raster tiles so pitch, bearing, 3D buildings/terrain in the Studio style,
/// fluid camera animation, Mapbox attribution and Mapbox logo all come from the
/// official renderer on Android, iOS and the PWA/web preview.
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
  CircleAnnotationManager? _listingManager;
  CircleAnnotationManager? _peopleManager;
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
    return 1.6;
  }

  Future<void> _flyTo(DiscoveryLocation loc, {double? zoom}) async {
    final map = _map;
    if (map == null) return;
    await map.flyTo(
      CameraOptions(
        center: _point(loc.latitude, loc.longitude),
        zoom: zoom ?? _zoomForRadius(loc.radiusKm),
        pitch: (zoom ?? _zoomForRadius(loc.radiusKm)) >= 8 ? 58 : 34,
        bearing: (zoom ?? _zoomForRadius(loc.radiusKm)) >= 8 ? 18 : 0,
      ),
      MapAnimationOptions(duration: 850, startDelay: 0),
    );
  }

  Future<void> _setupMap(MapboxMap map) async {
    _map = map;
    _listingManager = await map.annotations.createCircleAnnotationManager();
    _peopleManager = await map.annotations.createCircleAnnotationManager();

    _listingManager?.tapEvents(onTap: (annotation) {
      final p = annotation.geometry.coordinates;
      _selectNearest(p.lat.toDouble(), p.lng.toDouble(), listingOnly: true);
    });
    _peopleManager?.tapEvents(onTap: (annotation) {
      final p = annotation.geometry.coordinates;
      _selectNearest(p.lat.toDouble(), p.lng.toDouble(), peopleOnly: true);
    });

    final loc = ref.read(discoveryLocationProvider);
    await _flyTo(loc);
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
      final d = dLat * dLat + dLng * dLng;
      if (d < bestDistance) {
        bestDistance = d;
        best = pin;
      }
    }
    if (best == null) return;
    AppHaptics.selection();
    setState(() => _selected = best);
    _map?.easeTo(
      CameraOptions(
        center: _point(best.lat, best.lng),
        zoom: 14.2,
        pitch: 62,
        bearing: 20,
        padding: MbxEdgeInsets(bottom: 150, left: 0, top: 0, right: 0),
      ),
      MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }

  List<MapPin> _visiblePins() {
    final listings = ref.read(mapListingsProvider).value ?? const [];
    final profiles = ref.read(mapProfilesProvider).value ?? const [];
    return [
      if (_layer != 'people')
        for (final l in listings)
          if (l.latitude != null && l.longitude != null) MapPin.listing(l),
      if (_layer != 'listings')
        for (final p in profiles)
          if (p.latitude != null && p.longitude != null) MapPin.profile(p),
    ];
  }

  Future<void> _renderAnnotations() async {
    if (!_mapLoaded || _listingManager == null || _peopleManager == null) return;
    final generation = ++_annotationGeneration;
    final listings = ref.read(mapListingsProvider).value ?? const [];
    final profiles = ref.read(mapProfilesProvider).value ?? const [];

    await _listingManager!.deleteAll();
    await _peopleManager!.deleteAll();
    if (!mounted || generation != _annotationGeneration) return;

    if (_layer != 'people') {
      final options = <CircleAnnotationOptions>[
        for (final l in listings)
          if (l.latitude != null && l.longitude != null)
            CircleAnnotationOptions(
              geometry: _point(l.latitude!, l.longitude!),
              circleRadius: 7.0,
              circleColor: const Color(0xFFFF6338).toARGB32(),
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 1.5,
              circleOpacity: 0.96,
            ),
      ];
      if (options.isNotEmpty) await _listingManager!.createMulti(options);
    }

    if (_layer != 'listings') {
      final options = <CircleAnnotationOptions>[
        for (final p in profiles)
          if (p.latitude != null && p.longitude != null)
            CircleAnnotationOptions(
              geometry: _point(p.latitude!, p.longitude!),
              circleRadius: 6.5,
              circleColor: const Color(0xFFE95B9B).toARGB32(),
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 1.4,
              circleOpacity: 0.94,
            ),
      ];
      if (options.isNotEmpty) await _peopleManager!.createMulti(options);
    }
  }

  void _openSelected() {
    final pin = _selected;
    if (pin == null) return;
    AppHaptics.medium();
    if (pin.isListing) {
      context.push('/listing/${pin.id}');
    } else {
      context.push('/profile/${pin.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(discoveryLocationProvider);
    final listingsAsync = ref.watch(mapListingsProvider);
    final profilesAsync = ref.watch(mapProfilesProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tokenReady = AppConfig.mapboxAccessToken.trim().isNotEmpty;

    ref.listen(discoveryLocationProvider, (previous, next) {
      if (previous == null ||
          previous.latitude != next.latitude ||
          previous.longitude != next.longitude ||
          previous.radiusKm != next.radiusKm) {
        _selected = null;
        _flyTo(next);
      }
    });
    ref.listen(mapListingsProvider, (_, __) => _renderAnnotations());
    ref.listen(mapProfilesProvider, (_, __) => _renderAnnotations());

    if (!tokenReady) {
      return Material(
        color: const Color(0xFF0D1015),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public_rounded, color: Colors.white, size: 42),
                  const SizedBox(height: 14),
                  Text('MAPBOX IS NOT CONFIGURED', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 8),
                  Text('Build Swipess with MAPBOX_ACCESS_TOKEN so the official 3D map can load.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.white70, height: 1.4)),
                  const SizedBox(height: 18),
                  TextButton(onPressed: widget.onClose ?? () => context.go(AppPaths.clientDashboard), child: const Text('Close')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final loading = listingsAsync.isLoading || profilesAsync.isLoading;
    final listingCount = listingsAsync.value?.length ?? 0;
    final peopleCount = profilesAsync.value?.length ?? 0;

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapWidget(
            key: const ValueKey('swipess-real-mapbox'),
            styleUri: isLight ? _lightStyle : _darkStyle,
            cameraOptions: CameraOptions(
              center: _point(loc.latitude, loc.longitude),
              zoom: _zoomForRadius(loc.radiusKm),
              pitch: 58,
              bearing: 18,
            ),
            onMapCreated: _setupMap,
            onMapLoadedListener: (_) async {
              _mapLoaded = true;
              await _renderAnnotations();
            },
            onTapListener: (_) {
              if (_selected != null) setState(() => _selected = null);
            },
          ),

          if (loading)
            const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2, color: Color(0xFFFF5A52), backgroundColor: Colors.transparent)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassMapButton(icon: Icons.close_rounded, onTap: widget.onClose ?? () => context.go(AppPaths.clientDashboard)),
                    const SizedBox(width: 8),
                    _GlassMapButton(icon: Icons.search_rounded, onTap: () => setState(() => _citiesOpen = !_citiesOpen)),
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

          if (_citiesOpen)
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.paddingOf(context).top + 64,
              child: MapCityChips(
                activeCity: loc.city,
                onSelect: (city) {
                  ref.read(discoveryLocationProvider.notifier).setCoordinates(city: city.name, country: city.country, latitude: city.lat, longitude: city.lng);
                  setState(() => _citiesOpen = false);
                },
              ),
            ),

          Positioned(
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 88,
            child: Column(
              children: [
                _GlassMapButton(icon: Icons.add_rounded, onTap: () async {
                  final map = _map;
                  if (map == null) return;
                  final camera = await map.getCameraState();
                  await map.easeTo(CameraOptions(zoom: math.min(camera.zoom + 1, 18), pitch: camera.pitch), MapAnimationOptions(duration: 220, startDelay: 0));
                }),
                const SizedBox(height: 8),
                _GlassMapButton(icon: Icons.remove_rounded, onTap: () async {
                  final map = _map;
                  if (map == null) return;
                  final camera = await map.getCameraState();
                  await map.easeTo(CameraOptions(zoom: math.max(camera.zoom - 1, 1), pitch: camera.pitch), MapAnimationOptions(duration: 220, startDelay: 0));
                }),
                const SizedBox(height: 8),
                _GlassMapButton(icon: Icons.my_location_rounded, onTap: () => _flyTo(loc, zoom: 13.5)),
              ],
            ),
          ),

          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: _SelectedPinCard(pin: _selected!, onOpen: _openSelected, onClose: () => setState(() => _selected = null)),
            ),
        ],
      ),
    );
  }
}

class _GlassMapButton extends StatelessWidget {
  const _GlassMapButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.black.withAlpha(64),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(62), width: .7)),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerPill extends StatelessWidget {
  const _LayerPill({required this.value, required this.listingCount, required this.peopleCount, required this.onChanged});
  final String value;
  final int listingCount;
  final int peopleCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.black.withAlpha(60), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withAlpha(52), width: .7)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _LayerChoice(icon: Icons.layers_rounded, active: value == 'all', onTap: () => onChanged('all')),
            _LayerChoice(icon: Icons.home_rounded, active: value == 'listings', badge: listingCount, onTap: () => onChanged('listings')),
            _LayerChoice(icon: Icons.people_alt_rounded, active: value == 'people', badge: peopleCount, onTap: () => onChanged('people')),
          ]),
        ),
      ),
    );
  }
}

class _LayerChoice extends StatelessWidget {
  const _LayerChoice({required this.icon, required this.active, required this.onTap, this.badge});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final int? badge;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 34,
      padding: EdgeInsets.symmetric(horizontal: badge == null ? 9 : 8),
      decoration: BoxDecoration(color: active ? Colors.white.withAlpha(38) : Colors.transparent, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 17),
        if (badge != null) ...[
          const SizedBox(width: 4),
          Text('$badge', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ]),
    ),
  );
}

class _SelectedPinCard extends StatelessWidget {
  const _SelectedPinCard({required this.pin, required this.onOpen, required this.onClose});
  final MapPin pin;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final title = pin.isListing ? (pin.listing?.title ?? 'Listing') : (pin.profile?.name ?? 'Swipess member');
    final subtitle = pin.isListing ? (pin.listing?.city ?? 'Nearby listing') : (pin.profile?.city ?? 'Nearby member');
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(color: Colors.black.withAlpha(122), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withAlpha(52), width: .7)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: (pin.isListing ? const Color(0xFFFF6338) : const Color(0xFFE95B9B)).withAlpha(52), shape: BoxShape.circle), child: Icon(pin.isListing ? Icons.home_rounded : Icons.person_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 10.5)),
            ])),
            IconButton(onPressed: onOpen, icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19)),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18)),
          ]),
        ),
      ),
    );
  }
}
