import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(discoveryLocationProvider);
    final async = ref.watch(mapListingsProvider);
    final center = LatLng(location.latitude, location.longitude);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(mapListingsProvider),
                child: const Text('Could not load map pins — retry'),
              ),
            ),
            data: (listings) {
              return FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12,
                  minZoom: 3,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.swipess.flutter',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final listing in listings)
                        Marker(
                          point: LatLng(listing.latitude!, listing.longitude!),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ListingDetailScreen(listingData: listing),
                                ),
                              );
                            },
                            child: _Pin(listing: listing),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _GlassCircle(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickCity(context, ref),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withAlpha(40)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppTheme.brandPrimary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                location.label,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.expand_more_rounded, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCity(BuildContext context, WidgetRef ref) async {
    final city = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('CHOOSE CITY', style: AppTheme.displayItalic.copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            for (final city in ListingTaxonomies.popularCities)
              ListTile(
                title: Text(city, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, city),
              ),
          ],
        );
      },
    );
    if (city != null) {
      ref.read(discoveryLocationProvider.notifier).setCity(city);
    }
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.brandPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: AppTheme.brandPrimary.withAlpha(120), blurRadius: 12),
        ],
      ),
      child: Center(
        child: Text(
          listing.price == null
              ? '•'
              : '\$${listing.price!.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
