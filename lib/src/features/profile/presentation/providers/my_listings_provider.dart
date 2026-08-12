import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final myListingsProvider = FutureProvider.family<List<Listing>, String>((ref, status) async {
  ref.watch(authStateProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];

  try {
    var filter = client
        .from('listings')
        .select(
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, status, is_active',
        )
        .eq('owner_id', userId);

    if (status == 'active') {
      filter = filter.eq('is_active', true);
    } else if (status == 'pending') {
      filter = filter.eq('status', 'pending');
    } else if (status == 'sold') {
      filter = filter.or('status.eq.sold,status.eq.closed');
    }

    final rows = await filter.order('created_at', ascending: false).limit(100);
    return (rows as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
  } catch (_) {
    final rows = await client
        .from('listings')
        .select(
          'id, title, description, price, images, city, neighborhood, category, listing_type, latitude, longitude, currency, is_active',
        )
        .eq('owner_id', userId)
        .limit(100);
    final all = (rows as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
    if (status == 'active') return all.where((l) => l.isActive == true).toList();
    return all;
  }
});
