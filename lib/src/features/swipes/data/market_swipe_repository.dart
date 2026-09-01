import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/offline_swipe_queue.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final marketSwipeRepositoryProvider = Provider<MarketSwipeRepository>((ref) {
  return MarketSwipeRepository(ref.watch(supabaseClientProvider));
});

class MarketSwipeRepository {
  MarketSwipeRepository(this._client);

  static const _cachePrefix = 'swipess-discovery-cache-v1';
  static const _cacheMaxAge = Duration(days: 7);

  final SupabaseClient _client;

  Future<List<Listing>> fetch({
    required String category,
    required String marketCity,
    required String marketCountry,
    String? interestType,
    double? minPrice,
    double? maxPrice,
    int? minBeds,
    int? minBaths,
    bool? furnished,
    bool? petFriendly,
    List<String> propertyTypes = const [],
    int limit = 40,
    int offset = 0,
  }) async {
    if (_client.auth.currentUser == null) return const [];

    final cacheKey = _cacheKey(
      category: category,
      city: marketCity,
      country: marketCountry,
      limit: limit,
      offset: offset,
    );

    List<dynamic> rows;
    try {
      // Authenticated discovery intentionally fails closed. A direct listings
      // table fallback would bypass the Super Admin market matrix, so offline
      // mode replays only a previously authorized smart-feed response.
      final data = await _client.rpc(
        'app_get_smart_listings',
        params: {
          'p_category': category,
          'p_city': marketCity,
          'p_country': marketCountry,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      if (data is! List) return const [];
      rows = data;
      await _saveCache(cacheKey, rows);
    } catch (error) {
      if (!OfflineSwipeQueue.isNetworkFailure(error)) rethrow;
      rows = await _readCache(cacheKey) ?? const <dynamic>[];
    }

    final byId = <String, Listing>{};
    for (final row in rows.whereType<Map>()) {
      final listing = Listing.fromJson(Map<String, dynamic>.from(row));
      // A duplicated backend row or stale page boundary must never become two
      // Tinder-style cards. Last payload wins while preserving unique IDs.
      if (listing.id.isNotEmpty) byId[listing.id] = listing;
    }

    // Decisions made while offline are already removed from the visible deck
    // before their RPC reaches Supabase. This prevents a right-saved or passed
    // listing from reappearing after an app restart with no connection.
    final queued = await OfflineSwipeQueue(client: _client).getQueuedSwipes();
    final queuedListingIds = queued
        .where((item) => item.targetType == 'listing')
        .map((item) => item.targetId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final listings = byId.values.where((listing) {
      if (queuedListingIds.contains(listing.id)) return false;
      if (interestType != null &&
          interestType.isNotEmpty &&
          interestType != 'both' &&
          listing.listingType != null &&
          listing.listingType != interestType) {
        return false;
      }
      if (minPrice != null && (listing.price ?? 0) < minPrice) return false;
      if (maxPrice != null && (listing.price ?? 0) > maxPrice) return false;
      final beds = listing.beds ?? listing.bedrooms ?? 0;
      if (minBeds != null && minBeds > 0 && beds < minBeds) return false;
      final baths = (listing.baths ?? listing.bathrooms ?? 0).ceil();
      if (minBaths != null && minBaths > 0 && baths < minBaths) return false;
      if (furnished != null && listing.furnished != furnished) return false;
      if (petFriendly != null && listing.petFriendly != petFriendly) {
        return false;
      }
      if (propertyTypes.isNotEmpty) {
        final type = listing.propertyType;
        if (type == null || !propertyTypes.contains(type)) return false;
      }
      return true;
    }).toList(growable: false);

    return listings;
  }

  String _cacheKey({
    required String category,
    required String city,
    required String country,
    required int limit,
    required int offset,
  }) {
    String clean(String value) => value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final userId = _client.auth.currentUser?.id ?? 'anon';
    return '$_cachePrefix:$userId:${clean(country)}:${clean(city)}:${clean(category)}:$limit:$offset';
  }

  Future<void> _saveCache(String key, List<dynamic> rows) async {
    try {
      final safeRows = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'saved_at': DateTime.now().millisecondsSinceEpoch,
          'rows': safeRows,
        }),
      );
    } catch (_) {
      // Cache writes are an optimization only and must never block discovery.
    }
  }

  Future<List<dynamic>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = (decoded['saved_at'] as num?)?.toInt();
      final rows = decoded['rows'];
      if (savedAt == null || rows is! List) return null;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
      if (age > _cacheMaxAge) {
        await prefs.remove(key);
        return null;
      }
      return rows;
    } catch (_) {
      return null;
    }
  }
}
