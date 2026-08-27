import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/likes/domain/profile_like.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

class InterestedClient {
  const InterestedClient({
    required this.userId,
    required this.name,
    this.bio,
    this.avatarUrl,
    this.images = const [],
    this.age,
    this.occupation,
    this.likedListingTitle,
    this.likedAt,
  });

  final String userId;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final List<String> images;
  final int? age;
  final String? occupation;
  final String? likedListingTitle;
  final DateTime? likedAt;

  String? get primaryImage {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) return avatarUrl;
    if (images.isNotEmpty) return images.first;
    return null;
  }
}

class LikesRepository {
  LikesRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Map hearts use the same `likes` rows as the swipe deck, so saving from
  /// Map immediately becomes part of the existing Likes library and the item
  /// disappears from discovery on the next provider refresh.
  Future<void> likeTarget({
    required String targetType,
    required String targetId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || targetId.trim().isEmpty) return;

    final existing = await _client
        .from('likes')
        .select('target_id')
        .eq('user_id', userId)
        .eq('target_id', targetId)
        .eq('target_type', targetType)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('likes')
          .update({
            'direction': 'right',
            'dismiss_count': 0,
            'dismissed_at': null,
          })
          .eq('user_id', userId)
          .eq('target_id', targetId)
          .eq('target_type', targetType);
      return;
    }

    await _client.from('likes').insert({
      'user_id': userId,
      'target_id': targetId,
      'target_type': targetType,
      'direction': 'right',
      'dismiss_count': 0,
    });
  }

  Future<void> likeListing(String listingId) =>
      likeTarget(targetType: 'listing', targetId: listingId);

  Future<void> likePerson(String userId) =>
      likeTarget(targetType: 'profile', targetId: userId);

  Future<void> likeEvent(String eventId) =>
      likeTarget(targetType: 'event', targetId: eventId);

  Future<Set<String>> fetchLikedEventIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <String>{};
    final rows = await _client
        .from('likes')
        .select('target_id')
        .eq('user_id', userId)
        .eq('target_type', 'event')
        .eq('direction', 'right');
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['target_id'] as String?)
        .whereType<String>()
        .toSet();
  }

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

  /// Capacitor LikedClients — profiles the current user swiped right on.
  Future<List<ProfileLike>> fetchLikedPeople() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final likes = await _client
        .from('likes')
        .select('target_id, created_at')
        .eq('user_id', userId)
        .eq('target_type', 'profile')
        .eq('direction', 'right')
        .order('created_at', ascending: false);

    final ids = (likes as List)
        .map((row) => (row as Map<String, dynamic>)['target_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];

    final profiles = await _loadProfiles(ids);
    final likeAt = {
      for (final row in likes as List)
        (row as Map<String, dynamic>)['target_id'] as String: DateTime.tryParse(
          row['created_at']?.toString() ?? '',
        ),
    };

    return [
      for (final id in ids)
        if (profiles[id] != null) profiles[id]!.copyWithLikedAt(likeAt[id]),
    ];
  }

  Future<void> removeLikedPerson(String targetUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('likes')
        .update({
          'direction': 'left',
          'dismiss_count': 1,
          'dismissed_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('target_id', targetUserId)
        .eq('target_type', 'profile');
  }

  Future<void> removeLikedListing(String listingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('likes')
        .update({
          'direction': 'left',
          'dismiss_count': 1,
          'dismissed_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('target_id', listingId)
        .eq('target_type', 'listing');
  }

  Future<void> removeLikedEvent(String eventId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('likes')
        .update({
          'direction': 'left',
          'dismiss_count': 1,
          'dismissed_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('target_id', eventId)
        .eq('target_type', 'event');
  }

  /// Capacitor OwnerInterestedClients — people who liked my listings.
  Future<List<InterestedClient>> fetchInterestedClients() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final listings =
        await _client
                .from('listings')
                .select('id, title')
                .eq('owner_id', userId)
            as List;
    if (listings.isEmpty) return const [];

    final listingIds = listings
        .map((row) => (row as Map)['id'] as String?)
        .whereType<String>()
        .toList();
    final titles = {
      for (final row in listings)
        (row as Map)['id'] as String: (row)['title'] as String?,
    };

    final likes = await _client
        .from('likes')
        .select('user_id, target_id, created_at')
        .inFilter('target_id', listingIds)
        .eq('target_type', 'listing')
        .eq('direction', 'right')
        .order('created_at', ascending: false);

    if ((likes as List).isEmpty) return const [];

    final clientIds = likes
        .map((row) => (row as Map)['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final profiles = await _loadProfiles(clientIds);

    // Keep first like per client (newest first from query order).
    final seen = <String>{};
    final out = <InterestedClient>[];
    for (final raw in likes) {
      final row = Map<String, dynamic>.from(raw as Map);
      final cid = row['user_id'] as String?;
      if (cid == null || seen.contains(cid)) continue;
      seen.add(cid);
      final p = profiles[cid];
      if (p == null) continue;
      out.add(
        InterestedClient(
          userId: cid,
          name: p.name,
          bio: p.bio,
          avatarUrl: p.avatarUrl,
          images: p.images,
          age: p.age,
          occupation: p.occupation,
          likedListingTitle: titles[row['target_id'] as String?],
          likedAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        ),
      );
    }
    return out;
  }

  Future<void> dismissInterestedClient(String clientId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final listings =
        await _client.from('listings').select('id').eq('owner_id', userId)
            as List;
    final listingIds = listings
        .map((row) => (row as Map)['id'] as String?)
        .whereType<String>()
        .toList();
    if (listingIds.isEmpty) return;
    await _client
        .from('likes')
        .delete()
        .eq('user_id', clientId)
        .inFilter('target_id', listingIds);
  }

  Future<Map<String, ProfileLike>> _loadProfiles(List<String> ids) async {
    if (ids.isEmpty) return {};
    final out = <String, ProfileLike>{};

    try {
      final rows = await _client
          .from('profiles')
          .select(
            'user_id, full_name, bio, images, avatar_url, age, occupation',
          )
          .inFilter('user_id', ids);
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final id = map['user_id'] as String;
        final images = map['images'];
        out[id] = ProfileLike(
          userId: id,
          name: (map['full_name'] as String?)?.trim().isNotEmpty == true
              ? map['full_name'] as String
              : 'Member',
          bio: map['bio'] as String?,
          avatarUrl: map['avatar_url'] as String?,
          images: images is List
              ? images.map((e) => e.toString()).toList()
              : const [],
          age: (map['age'] as num?)?.toInt(),
          occupation: map['occupation'] as String?,
        );
      }
    } catch (_) {}

    final missing = ids.where((id) => !out.containsKey(id)).toList();
    if (missing.isEmpty) return out;

    try {
      final rows = await _client
          .from('client_profiles')
          .select('user_id, name, bio, profile_images, age, occupation')
          .inFilter('user_id', missing);
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final id = map['user_id'] as String;
        final images = map['profile_images'];
        out[id] = ProfileLike(
          userId: id,
          name: (map['name'] as String?)?.trim().isNotEmpty == true
              ? map['name'] as String
              : 'Member',
          bio: map['bio'] as String?,
          images: images is List
              ? images.map((e) => e.toString()).toList()
              : const [],
          age: (map['age'] as num?)?.toInt(),
          occupation: map['occupation'] as String?,
        );
      }
    } catch (_) {}

    return out;
  }
}

extension on ProfileLike {
  ProfileLike copyWithLikedAt(DateTime? likedAt) {
    return ProfileLike(
      userId: userId,
      name: name,
      bio: bio,
      avatarUrl: avatarUrl,
      images: images,
      age: age,
      occupation: occupation,
      likedAt: likedAt,
    );
  }
}
