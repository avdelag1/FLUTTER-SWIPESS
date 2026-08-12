import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

final mapListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final client = Supabase.instance.client;
  try {
    final data = await client
        .from('listings')
        .select(
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, status, is_active',
        )
        .eq('is_active', true)
        .eq('status', 'active')
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .limit(120);
    return (data as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();
  } catch (_) {
    final data = await client
        .from('listings')
        .select(
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, is_active',
        )
        .eq('is_active', true)
        .not('latitude', 'is', null)
        .limit(120);
    return (data as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();
  }
});
