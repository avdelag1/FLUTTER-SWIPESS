import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/pull_down_to_dismiss.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipeable_card_stack.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final peopleIntentProfilesProvider =
    FutureProvider.family<List<PeopleIntentProfile>, String>((ref, mode) async {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;

      final rows =
          await client
                  .from('client_profiles')
                  .select(
                    'user_id, name, age, bio, city, country, profile_images, vap_avatar, intentions, occupation, vap_occupation, updated_at',
                  )
                  .order('updated_at', ascending: false)
                  .limit(80)
              as List;

      var profiles = rows
          .whereType<Map<String, dynamic>>()
          .where((row) => row['user_id']?.toString() != currentUserId)
          .map(PeopleIntentProfile.fromJson)
          .where((profile) => profile.matchesMode(mode))
          .toList(growable: false);

      if (currentUserId != null && profiles.isNotEmpty) {
        try {
          final visibleData = await client.rpc(
            'rpc_filter_discoverable_profile_ids',
            params: {'p_ids': profiles.map((p) => p.userId).toList()},
          );
          if (visibleData is List) {
            final visible = visibleData.map((e) => e.toString()).toSet();
            profiles = profiles
                .where((profile) => visible.contains(profile.userId))
                .toList(growable: false);
          } else {
            profiles = const <PeopleIntentProfile>[];
          }
        } catch (_) {
          profiles = const <PeopleIntentProfile>[];
        }
      }

      return profiles;
    });

class PeopleIntentProfile {
  const PeopleIntentProfile({
    required this.userId,
    required this.name,
    required this.intentions,
    this.age,
    this.bio,
    this.city,
    this.country,
    this.occupation,
    this.images = const <String>[],
  });

  factory PeopleIntentProfile.fromJson(Map<String, dynamic> row) {
    final rawImages = row['profile_images'];
    final images = rawImages is List
        ? rawImages
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final avatar = row['vap_avatar']?.toString().trim() ?? '';
    if (images.isEmpty && avatar.isNotEmpty) images.add(avatar);

    final rawIntentions = row['intentions'];
    final intentions = rawIntentions is List
        ? rawIntentions
              .map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final rawName = row['name']?.toString().trim() ?? '';
    return PeopleIntentProfile(
      userId: row['user_id']?.toString() ?? '',
      name: rawName.isEmpty ? 'Swipess member' : rawName,
      age: (row['age'] as num?)?.toInt(),
      bio: row['bio']?.toString(),
      city: row['city']?.toString(),
      country: row['country']?.toString(),
      occupation:
          row['vap_occupation']?.toString() ?? row['occupation']?.toString(),
      images: images,
      intentions: intentions,
    );
  }

  final String userId;
  final String name;
  final int? age;
  final String? bio;
  final String? city;
  final String? country;
  final String? occupation;
  final List<String> images;
  final List<String> intentions;

  bool matchesMode(String mode) {
    switch (mode) {
      case 'buyers':
        return intentions.contains('buyer');
      case 'renters':
        return intentions.contains('renter');
      case 'seekers':
        return intentions.contains('seeker');
      default:
        return false;
    }
  }

  String get locationLabel {
    final parts = <String>[
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((country ?? '').trim().isNotEmpty) country!.trim(),
    ];
    return parts.isEmpty ? 'Swipess' : parts.join(', ');
  }

  Listing asSwipeListing(String mode) {
    final role = switch (mode) {
      'buyers' => 'Looking to buy',
      'renters' => 'Looking to rent',
      _ => 'Looking to hire a worker',
    };
    final title = age == null ? name : '$name, $age';
    final details = <String>[
      role,
      if ((occupation ?? '').trim().isNotEmpty) occupation!.trim(),
      locationLabel,
      if ((bio ?? '').trim().isNotEmpty) bio!.trim(),
    ];
    return Listing(
      id: userId,
      ownerId: userId,
      title: title,
      description: details.join(' · '),
      category: 'person',
      listingType: mode,
      city: city,
      country: country,
      location: locationLabel,
      images: images,
      amenities: const <String>[],
      isActive: true,
      status: 'active',
    );
  }
}

class PeopleIntentDiscoveryScreen extends ConsumerStatefulWidget {
  const PeopleIntentDiscoveryScreen({super.key, required this.mode});

  final String mode;

  @override
  ConsumerState<PeopleIntentDiscoveryScreen> createState() =>
      _PeopleIntentDiscoveryScreenState();
}

class _PeopleIntentDiscoveryScreenState
    extends ConsumerState<PeopleIntentDiscoveryScreen> {
  List<PeopleIntentProfile>? _deck;
  PeopleIntentProfile? _undoable;
  bool _retrying = false;

  String get _label => switch (widget.mode) {
    'buyers' => 'buyers',
    'renters' => 'renters',
    _ => 'seekers',
  };

  void _ensureDeck(List<PeopleIntentProfile> source) {
    _deck ??= List<PeopleIntentProfile>.from(source);
  }

  PeopleIntentProfile? _findProfile(String id) {
    for (final profile in _deck ?? const <PeopleIntentProfile>[]) {
      if (profile.userId == id) return profile;
    }
    return null;
  }

  void _goDashboard() {
    AppHaptics.light();
    context.go(AppPaths.clientDashboard);
  }

  void _openProfile(PeopleIntentProfile profile) {
    AppHaptics.medium();
    context.push(AppPaths.profile(profile.userId));
  }

  void _invalidatePeopleCaches() {
    ref.invalidate(peopleIntentProfilesProvider(widget.mode));
    ref.invalidate(mapProfilesProvider);
    ref.invalidate(likedPeopleProvider);
    ref.invalidate(likedPeopleIdsProvider);
  }

  Future<void> _afterSwipe(
    PeopleIntentProfile profile,
    SwipeDirection direction,
  ) async {
    final repo = SwipeRepository();
    try {
      if (direction == SwipeDirection.right) {
        await repo.likeProfile(profile.userId);
      } else {
        await repo.dislikeProfile(profile.userId);
      }
      _invalidatePeopleCaches();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final deck = _deck ?? <PeopleIntentProfile>[];
        if (!deck.any((item) => item.userId == profile.userId)) {
          _deck = <PeopleIntentProfile>[profile, ...deck];
        }
        if (_undoable?.userId == profile.userId) _undoable = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save that decision. Try again.'),
        ),
      );
    }
  }

  Future<void> _undo() async {
    final last = _undoable;
    if (last == null) return;
    AppHaptics.selection();
    try {
      await SwipeRepository().undoProfileSwipe(last.userId);
      if (!mounted) return;
      setState(() {
        _undoable = null;
        _deck = <PeopleIntentProfile>[last, ...?_deck];
      });
      _invalidatePeopleCaches();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not undo that decision.')),
      );
    }
  }

  Future<void> _message(PeopleIntentProfile profile) async {
    AppHaptics.medium();
    try {
      final convoId = await SwipeRepository().startConversation(
        ownerId: profile.userId,
        initialMessage:
            'Hey! I found your ${_label.substring(0, _label.length - 1)} profile on Swipess.',
      );
      if (!mounted || convoId == null) return;
      await showChatPopup(
        context,
        isNewConversation: true,
        conversation: ChatConversation(
          id: convoId,
          otherUserId: profile.userId,
          name: profile.name,
          lastMessage: '',
          timestamp: 'now',
          avatarUrl: profile.images.isEmpty ? null : profile.images.first,
          listingTag: _label.toUpperCase(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start that conversation right now.'),
        ),
      );
    }
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_alt_rounded,
              color: Colors.white70,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              'NO $_label POSTED YET'.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'People appear here only after they explicitly turn that discovery mode on in Edit Profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => context.go(AppPaths.clientProfile),
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('MY PROFILE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deckScaffold(List<PeopleIntentProfile> profiles) {
    _ensureDeck(profiles);
    final deck = _deck ?? profiles;
    if (deck.isEmpty) return _emptyState();

    final byId = <String, PeopleIntentProfile>{
      for (final profile in deck) profile.userId: profile,
    };
    final listings = deck
        .map((profile) => profile.asSwipeListing(widget.mode))
        .toList(growable: false);

    return Listener(
      behavior: HitTestBehavior.translucent,
      child: SwipeableCardStack(
        listings: listings,
        railVisible: true,
        canUndo: _undoable != null,
        onUndo: _undo,
        onBack: _goDashboard,
        onOpenMap: () => context.push(AppPaths.map),
        onInsights: (listing) {
          final profile = byId[listing.id];
          if (profile != null) _openProfile(profile);
        },
        onMessage: (listing) {
          final profile = byId[listing.id];
          if (profile != null) unawaited(_message(profile));
        },
        onShare: (listing) {
          final profile = byId[listing.id];
          if (profile != null) _openProfile(profile);
        },
        onSwiped: (listing, direction) {
          final profile = byId[listing.id];
          if (profile == null) return;
          setState(() {
            _undoable = profile;
            _deck = List<PeopleIntentProfile>.from(deck)
              ..removeWhere((item) => item.userId == profile.userId);
          });
          unawaited(_afterSwipe(profile, direction));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(peopleIntentProfilesProvider(widget.mode));
    final cached = async.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: PullDownToDismiss(
        onDismiss: _goDashboard,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 76, 8, 72),
            child: cached != null
                ? _deckScaffold(cached)
                : async.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, _) => Center(
                      child: TextButton.icon(
                        onPressed: _retrying
                            ? null
                            : () async {
                                setState(() => _retrying = true);
                                ref.invalidate(
                                  peopleIntentProfilesProvider(widget.mode),
                                );
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 350),
                                );
                                if (mounted) setState(() => _retrying = false);
                              },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('RETRY'),
                      ),
                    ),
                    data: _deckScaffold,
                  ),
          ),
        ),
      ),
    );
  }
}
