import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

class LikesRepository {
  LikesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Listing>> fetchLikedListings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final likes = await _client
        .from('likes')
        .select('target_id, created_at')
        .eq('user_id', userId)
        .eq('direction', 'right')
        .eq('target_type', 'listing')
        .order('created_at', ascending: false);

    final ids = (likes as List)
        .map((row) => (row as Map<String, dynamic>)['target_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];

    final rows = await _client.from('listings').select().inFilter('id', ids);
    final byId = {
      for (final row in rows as List)
        (row as Map<String, dynamic>)['id'] as String: Listing.fromJson(row),
    };
    return ids.map((id) => byId[id]).whereType<Listing>().toList();
  }
}
