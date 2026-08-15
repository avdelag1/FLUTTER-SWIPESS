import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/likes/domain/profile_like.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final whoLikedYouProvider =
    AsyncNotifierProvider<WhoLikedYouNotifier, List<ProfileLike>>(
      WhoLikedYouNotifier.new,
    );

class WhoLikedYouNotifier extends AsyncNotifier<List<ProfileLike>> {
  @override
  Future<List<ProfileLike>> build() async {
    ref.watch(authStateProvider);
    return _fetch();
  }

  Future<List<ProfileLike>> _fetch() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];

    final likes =
        await client
                .from('likes')
                .select('user_id, created_at')
                .eq('target_id', userId)
                .eq('target_type', 'profile')
                .eq('direction', 'right')
                .order('created_at', ascending: false)
                .limit(100)
            as List;

    if (likes.isEmpty) return const [];

    final ownerIds = likes
        .map((row) => (row as Map)['user_id'] as String?)
        .whereType<String>()
        .toList();

    Map<String, Map<String, dynamic>> profiles = {};
    try {
      final rows = await client
          .from('profiles')
          .select(
            'user_id, full_name, bio, images, avatar_url, age, occupation',
          )
          .inFilter('user_id', ownerIds);
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        profiles[map['user_id'] as String] = map;
      }
    } catch (_) {
      final rows = await client
          .from('client_profiles')
          .select('user_id, name, bio, profile_images, age, occupation')
          .inFilter('user_id', ownerIds);
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        profiles[map['user_id'] as String] = {
          'user_id': map['user_id'],
          'full_name': map['name'],
          'bio': map['bio'],
          'images': map['profile_images'],
          'avatar_url': null,
          'age': map['age'],
          'occupation': map['occupation'],
        };
      }
    }

    return [
      for (final raw in likes)
        if (profiles[(raw as Map)['user_id'] as String] != null)
          _mapLike(raw as Map<String, dynamic>, profiles),
    ];
  }

  ProfileLike _mapLike(
    Map<String, dynamic> like,
    Map<String, Map<String, dynamic>> profiles,
  ) {
    final pid = like['user_id'] as String;
    final p = profiles[pid]!;
    final images = p['images'];
    return ProfileLike(
      userId: pid,
      name: (p['full_name'] as String?)?.trim().isNotEmpty == true
          ? p['full_name'] as String
          : 'Member',
      bio: p['bio'] as String?,
      avatarUrl: p['avatar_url'] as String?,
      images: images is List
          ? images.map((e) => e.toString()).toList()
          : const [],
      age: (p['age'] as num?)?.toInt(),
      occupation: p['occupation'] as String?,
      likedAt: DateTime.tryParse(like['created_at']?.toString() ?? ''),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> dismiss(String likerUserId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client
        .from('likes')
        .delete()
        .eq('user_id', likerUserId)
        .eq('target_id', userId)
        .eq('target_type', 'profile');
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((p) => p.userId != likerUserId).toList());
  }
}
