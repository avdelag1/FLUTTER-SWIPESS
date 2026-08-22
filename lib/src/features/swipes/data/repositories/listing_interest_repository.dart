import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListingInterest {
  const ListingInterest({
    required this.listingId,
    required this.likerId,
    required this.listingTitle,
    required this.category,
    required this.memberName,
    required this.isNeed,
    this.memberAvatar,
  });

  final String listingId;
  final String likerId;
  final String listingTitle;
  final String category;
  final String memberName;
  final String? memberAvatar;
  final bool isNeed;
}

class ListingInterestRepository {
  ListingInterestRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ListingInterest?> fetch({
    required String listingId,
    required String likerId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final listing = await _client
        .from('listings')
        .select('id, owner_id, title, category, listing_type, mode')
        .eq('id', listingId)
        .eq('owner_id', uid)
        .maybeSingle();
    if (listing == null) return null;

    final interest = await _client
        .from('likes')
        .select('user_id')
        .eq('user_id', likerId)
        .eq('target_id', listingId)
        .eq('target_type', 'listing')
        .eq('direction', 'right')
        .maybeSingle();
    if (interest == null) return null;

    String memberName = 'Member';
    String? memberAvatar;
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, username, avatar_url, profile_photo_url, avatar')
          .eq('id', likerId)
          .maybeSingle();
      if (profile != null) {
        memberName = _firstText([
              profile['full_name'],
              profile['username'],
            ]) ??
            memberName;
        memberAvatar = _firstText([
          profile['avatar_url'],
          profile['profile_photo_url'],
          profile['avatar'],
        ]);
      }
    } catch (_) {}

    if (memberName == 'Member' || memberAvatar == null) {
      try {
        final clientProfile = await _client
            .from('client_profiles')
            .select('name, profile_images')
            .eq('user_id', likerId)
            .maybeSingle();
        if (clientProfile != null) {
          memberName = _firstText([clientProfile['name']]) ?? memberName;
          final images = clientProfile['profile_images'];
          if (memberAvatar == null && images is List && images.isNotEmpty) {
            memberAvatar = images.first?.toString();
          }
        }
      } catch (_) {}
    }

    return ListingInterest(
      listingId: listingId,
      likerId: likerId,
      listingTitle: _firstText([listing['title']]) ?? 'Your listing',
      category: '${listing['category'] ?? 'listing'}',
      memberName: memberName,
      memberAvatar: memberAvatar,
      isNeed: listing['listing_type'] == 'request' && listing['mode'] == 'seek',
    );
  }

  Future<String?> accept({
    required String listingId,
    required String likerId,
  }) async {
    final raw = await _client.rpc(
      'rpc_accept_listing_interest',
      params: {
        'p_liker_id': likerId,
        'p_listing_id': listingId,
      },
    );
    if (raw is Map) return raw['conversation_id']?.toString();
    return null;
  }

  static String? _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }
}

final listingInterestRepositoryProvider = Provider<ListingInterestRepository>((ref) {
  return ListingInterestRepository();
});
