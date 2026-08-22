import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sparse live context for the top swipe card. Existing Verified/Price Drop
/// signals remain inside CapSwipeCard; this adds only useful discovery context.
class ListingLiveSignals extends ConsumerWidget {
  const ListingLiveSignals({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(discoveryLocationProvider);
    final signals = <String>[];
    final distance = _distanceKm(
      location.latitude,
      location.longitude,
      listing.latitude,
      listing.longitude,
    );
    if (distance != null && distance <= location.radiusKm * 1.5) {
      signals.add(distance < 1 ? '${(distance * 1000).round()} M' : '${distance.toStringAsFixed(distance < 10 ? 1 : 0)} KM');
    }
    final created = listing.createdAt;
    if (created != null && DateTime.now().difference(created).inHours <= 48) {
      signals.add('NEW');
    }
    if (signals.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: [for (final signal in signals.take(2)) _pill(signal)],
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(125),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withAlpha(55)),
        ),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
      );

  static double? _distanceKm(
    double lat1,
    double lon1,
    double? lat2,
    double? lon2,
  ) {
    if (lat2 == null || lon2 == null) return null;
    const earthKm = 6371.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
