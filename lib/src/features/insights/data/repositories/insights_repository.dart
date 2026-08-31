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

  /// Local Intel is backed by the same real Local Brain directory used by the
  /// concierge. The old screen queried `local_intel_posts`, a table that does
  /// not exist in production, which made this destination look frozen/broken.
  Future<List<LocalIntelPost>> fetchLocalIntel() async {
    final rows = await _client
        .from('local_brain_entries')
        .select(
          'id, name, description, recommendation_note, category, neighborhood, photo_url, source_url, updated_at, is_featured, is_verified, priority',
        )
        .eq('is_active', true)
        .order('is_featured', ascending: false)
        .order('is_verified', ascending: false)
        .order('priority', ascending: false)
        .order('updated_at', ascending: false)
        .limit(120)
        .timeout(const Duration(seconds: 8));

    return (rows as List).map((raw) {
      final row = raw as Map<String, dynamic>;
      final note = row['recommendation_note']?.toString().trim() ?? '';
      final description = row['description']?.toString().trim() ?? '';
      final category = row['category']?.toString() ?? '';
      return LocalIntelPost(
        id: row['id']?.toString() ?? '',
        title: row['name']?.toString().trim().isNotEmpty == true
            ? row['name'].toString().trim()
            : 'Local place',
        content: note.isNotEmpty ? note : description,
        category: _intelCategory(category),
        neighborhood: row['neighborhood']?.toString(),
        imageUrl: row['photo_url']?.toString(),
        sourceUrl: row['source_url']?.toString(),
        publishedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      );
    }).toList();
  }

  /// Current Market Prices are calculated from active Swipess property asking
  /// prices. This intentionally does not use the old seeded `price_history`
  /// table, because that data has no live source/provenance and must not be
  /// presented as current market movement.
  Future<List<PricePoint>> fetchPriceHistory() async {
    final rows = await _client
        .from('listings')
        .select('neighborhood, city, price, currency')
        .eq('category', 'property')
        .eq('is_active', true)
        .eq('status', 'active')
        .not('price', 'is', null)
        .limit(1000)
        .timeout(const Duration(seconds: 8));

    final aggregates = <String, _PriceAggregate>{};
    for (final raw in rows as List) {
      final row = raw as Map<String, dynamic>;
      final price = (row['price'] as num?)?.toDouble() ?? 0;
      if (price <= 0) continue;

      final neighborhood = row['neighborhood']?.toString().trim() ?? '';
      final city = row['city']?.toString().trim() ?? '';
      final zone = neighborhood.isNotEmpty
          ? neighborhood
          : (city.isNotEmpty ? city : 'Other');
      final currency = row['currency']?.toString().trim().toUpperCase() ?? '';
      final safeCurrency = currency.isEmpty ? 'USD' : currency;
      final key = '${zone.toLowerCase()}|$safeCurrency';
      final aggregate = aggregates.putIfAbsent(
        key,
        () => _PriceAggregate(zone: zone, currency: safeCurrency),
      );
      aggregate.total += price;
      aggregate.count += 1;
    }

    final now = DateTime.now();
    final points = aggregates.values
        .where((a) => a.count > 0)
        .map(
          (a) => PricePoint(
            neighborhood: a.zone,
            month: now.month,
            year: now.year,
            avgPrice: a.total / a.count,
            listingCount: a.count,
            currency: a.currency,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byZone = a.neighborhood.compareTo(b.neighborhood);
        return byZone != 0 ? byZone : a.currency.compareTo(b.currency);
      });
    return points;
  }

  String _intelCategory(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('restaurant') ||
        value.contains('restaurante') ||
        value.contains('cafe') ||
        value.contains('cafeter') ||
        value.contains('food') ||
        value.contains('comida')) {
      return 'dining';
    }
    if (value.contains('cowork') || value.contains('office')) {
      return 'coworking';
    }
    if (value.contains('event') ||
        value.contains('nightlife') ||
        value.contains('club')) {
      return 'events';
    }
    if (value.contains('police') ||
        value.contains('hospital') ||
        value.contains('clinic') ||
        value.contains('clínica') ||
        value.contains('pharmac') ||
        value.contains('farmacia') ||
        value.contains('emergency') ||
        value.contains('seguridad')) {
      return 'safety';
    }
    if (value.contains('public') ||
        value.contains('administr') ||
        value.contains('transport') ||
        value.contains('infra')) {
      return 'infrastructure';
    }
    return 'general';
  }
}

class _PriceAggregate {
  _PriceAggregate({required this.zone, required this.currency});

  final String zone;
  final String currency;
  double total = 0;
  int count = 0;
}
