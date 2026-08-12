import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

final videoToursProvider = FutureProvider<List<Listing>>((ref) async {
  final client = Supabase.instance.client;
  try {
    final withVideo = await client
        .from('listings')
        .select()
        .eq('is_active', true)
        .not('video_url', 'is', null)
        .order('created_at', ascending: false)
        .limit(40);
    final videoList = (withVideo as List)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .where((l) => l.videoUrl != null && l.videoUrl!.trim().isNotEmpty)
        .toList();
    if (videoList.isNotEmpty) return videoList;
  } catch (_) {}

  final fallback = await client
      .from('listings')
      .select()
      .eq('is_active', true)
      .not('images', 'is', null)
      .order('created_at', ascending: false)
      .limit(30);
  return (fallback as List)
      .map((row) => Listing.fromJson(row as Map<String, dynamic>))
      .where((l) => l.images.isNotEmpty)
      .toList();
});
