import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

class SwipeRepository {
  final SupabaseClient _supabase;

  SwipeRepository(this._supabase);

  /// Fetch listings for a specific category
  Future<List<Listing>> fetchListings({required String category, int limit = 10}) async {
    try {
      var query = _supabase.from('listings').select('*').eq('is_active', true);
      
      // Filter by category unless 'all' or specific bento items like 'recommended'
      if (category != 'all' && category != 'recommended' && category != 'popular') {
        query = query.eq('category', category);
      }
      
      final response = await query.order('created_at', ascending: false).limit(limit);
      
      return (response as List).map((row) => Listing.fromJson(row)).toList();
    } catch (e) {
      print('Error fetching swipe listings: $e');
      return [];
    }
  }

  /// Register a right swipe (like)
  Future<void> registerSwipeRight(String userId, String listingId) async {
    try {
      await _supabase.from('likes').insert({
        'user_id': userId,
        'listing_id': listingId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error registering swipe right: $e');
    }
  }

  /// Register a left swipe (pass)
  Future<void> registerSwipeLeft(String userId, String listingId) async {
    try {
      await _supabase.from('passes').insert({
        'user_id': userId,
        'listing_id': listingId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error registering swipe left: $e');
    }
  }
}
