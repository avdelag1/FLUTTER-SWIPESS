import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/insights/domain/local_intel_post.dart';
import 'package:flutter_swipes/src/features/insights/domain/price_point.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository();
});

class InsightsRepository {
  InsightsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<LocalIntelPost>> fetchLocalIntel() async {
    final rows = await _client
        .from('local_intel_posts')
        .select()
        .eq('is_published', true)
        .order('published_at', ascending: false);
    return (rows as List)
        .map((row) => LocalIntelPost.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<PricePoint>> fetchPriceHistory() async {
    final rows = await _client
        .from('price_history')
        .select('neighborhood, month, year, avg_price, listing_count')
        .order('year')
        .order('month')
        .limit(1000);
    return (rows as List)
        .map((row) => PricePoint.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
