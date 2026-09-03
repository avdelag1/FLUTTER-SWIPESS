from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch marker: {label}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Buyers / Renters / Seekers now use the exact same swipe engine as listings.
# ---------------------------------------------------------------------------
people = Path('lib/src/features/seekers/presentation/screens/people_intent_discovery_screen.dart')
people.write_text(r'''import 'dart:async';

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

      final rows = await client
          .from('client_profiles')
          .select(
            'user_id, name, age, bio, city, country, profile_images, vap_avatar, intentions, occupation, vap_occupation, updated_at',
          )
          .order('updated_at', ascending: false)
          .limit(80) as List;

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
        const SnackBar(content: Text('Could not save that decision. Try again.')),
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
        initialMessage: 'Hey! I found your ${_label.substring(0, _label.length - 1)} profile on Swipess.',
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
            const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 52),
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
      backgroundColor: const Color(0xFF0A0A0D),
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
''')

# ---------------------------------------------------------------------------
# Profile discovery visibility is an explicit profile setting, OFF by default.
# ---------------------------------------------------------------------------
profile_repo = Path('lib/src/features/profile/data/repositories/profile_repository.dart')
text = profile_repo.read_text()
marker = '''  Future<({bool available, double? monthlyBudget})>\n  fetchRoommatePreferences() async {\n'''
addition = r'''  Future<({bool buyer, bool renter, bool seeker})>
  fetchPeopleDiscoveryVisibility() async {
    final user = _client.auth.currentUser;
    if (user == null) return (buyer: false, renter: false, seeker: false);
    try {
      final row = await _client
          .from('client_profiles')
          .select('intentions')
          .eq('user_id', user.id)
          .maybeSingle();
      final raw = row?['intentions'];
      final values = raw is List
          ? raw
                .map((e) => e.toString().trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toSet()
          : <String>{};
      return (
        buyer: values.contains('buyer'),
        renter: values.contains('renter'),
        seeker: values.contains('seeker'),
      );
    } catch (_) {
      return (buyer: false, renter: false, seeker: false);
    }
  }

  Future<void> updatePeopleDiscoveryVisibility({
    required bool buyer,
    required bool renter,
    required bool seeker,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final row = await _client
        .from('client_profiles')
        .select('intentions')
        .eq('user_id', user.id)
        .maybeSingle();
    final raw = row?['intentions'];
    final next = raw is List
        ? raw
              .map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .where(
                (value) =>
                    value != 'buyer' &&
                    value != 'renter' &&
                    value != 'seeker' &&
                    value != 'hire_service' &&
                    !value.startsWith('buy_') &&
                    !value.startsWith('rent_') &&
                    !value.startsWith('hire_'),
              )
              .toSet()
        : <String>{};

    if (buyer) next.add('buyer');
    if (renter) next.add('renter');
    if (seeker) next.add('seeker');

    await _client
        .from('client_profiles')
        .update({'intentions': next.toList(growable: false)})
        .eq('user_id', user.id);
  }

'''
text = replace_once(text, marker, addition + marker, 'profile visibility methods')
profile_repo.write_text(text)

# ---------------------------------------------------------------------------
# Edit Profile: explicit Buyer / Renter / Seeker switches next to Roommate Mode.
# ---------------------------------------------------------------------------
edit = Path('lib/src/features/profile/presentation/screens/edit_profile_screen.dart')
text = edit.read_text()
text = replace_once(
    text,
    '''  bool _roommateAvailable = false;\n  bool _loadingRoommatePrefs = true;\n''',
    '''  bool _roommateAvailable = false;\n  bool _loadingRoommatePrefs = true;\n  bool _buyerVisible = false;\n  bool _renterVisible = false;\n  bool _seekerVisible = false;\n  bool _loadingPeoplePrefs = true;\n''',
    'edit profile visibility state',
)
text = replace_once(
    text,
    '''      _loadRoommatePreferences();\n''',
    '''      _loadRoommatePreferences();\n      _loadPeopleDiscoveryVisibility();\n''',
    'edit profile load visibility',
)
text = replace_once(
    text,
    '''  @override\n  void dispose() {\n''',
    r'''  Future<void> _loadPeopleDiscoveryVisibility() async {
    final prefs = await ref
        .read(profileRepositoryProvider)
        .fetchPeopleDiscoveryVisibility();
    if (!mounted) return;
    setState(() {
      _buyerVisible = prefs.buyer;
      _renterVisible = prefs.renter;
      _seekerVisible = prefs.seeker;
      _loadingPeoplePrefs = false;
    });
  }

  @override
  void dispose() {
''',
    'edit profile visibility loader method',
)
text = replace_once(
    text,
    '''      await repo.updateRoommatePreferences(\n        available: _roommateAvailable,\n        monthlyBudget: parsedBudget,\n      );\n''',
    '''      await repo.updateRoommatePreferences(\n        available: _roommateAvailable,\n        monthlyBudget: parsedBudget,\n      );\n      await repo.updatePeopleDiscoveryVisibility(\n        buyer: _buyerVisible,\n        renter: _renterVisible,\n        seeker: _seekerVisible,\n      );\n''',
    'edit profile save visibility',
)
roommate_card = '''              SizedBox(height: 24),\n              Container(\n                width: double.infinity,\n                padding: EdgeInsets.all(18),\n                decoration: BoxDecoration(\n                  color: Colors.white.withAlpha(8),\n                  borderRadius: BorderRadius.circular(24),\n                  border: Border.all(color: Colors.white.withAlpha(32)),\n                ),\n                child: _loadingRoommatePrefs\n'''
visibility_card = r'''              SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withAlpha(32)),
                ),
                child: _loadingPeoplePrefs
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DISCOVERY VISIBILITY',
                            style: GoogleFonts.plusJakartaSans(
                              color: MatteSurface.ink(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'All are OFF by default. Turn on only the places where you want other people to discover you.',
                            style: GoogleFonts.plusJakartaSans(
                              color: MatteSurface.muted(context),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DiscoveryToggle(
                            icon: Icons.sell_outlined,
                            title: 'Buyer',
                            subtitle: 'Show me to people looking for buyers.',
                            value: _buyerVisible,
                            onChanged: (value) {
                              AppHaptics.selection();
                              setState(() => _buyerVisible = value);
                            },
                          ),
                          _DiscoveryToggle(
                            icon: Icons.key_outlined,
                            title: 'Renter',
                            subtitle: 'Show me to people looking for renters.',
                            value: _renterVisible,
                            onChanged: (value) {
                              AppHaptics.selection();
                              setState(() => _renterVisible = value);
                            },
                          ),
                          _DiscoveryToggle(
                            icon: Icons.handyman_outlined,
                            title: 'Seeker',
                            subtitle: 'I am looking to hire a worker.',
                            value: _seekerVisible,
                            onChanged: (value) {
                              AppHaptics.selection();
                              setState(() => _seekerVisible = value);
                            },
                          ),
                        ],
                      ),
              ),
              SizedBox(height: 16),
'''
text = replace_once(text, roommate_card, visibility_card + roommate_card, 'edit profile visibility card')
text = replace_once(
    text,
    '''class _Label extends StatelessWidget {\n''',
    r'''class _DiscoveryToggle extends StatelessWidget {
  const _DiscoveryToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: MatteSurface.ink(context), size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.ink(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 10.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
''',
    'edit profile visibility toggle widget',
)
edit.write_text(text)

# ---------------------------------------------------------------------------
# Browsing/applying listing filters must NEVER silently publish a person.
# ---------------------------------------------------------------------------
prefs = Path('lib/src/features/swipes/data/repositories/client_filter_preferences_repository.dart')
text = prefs.read_text()
start = text.index('  /// Adds the signed-in user\'s current search intent')
end = text.index('\n  }\n}', start) + len('\n  }')
replacement = r'''  /// Legacy compatibility hook. Applying listing filters must never make the
  /// signed-in user public in Buyers, Renters or Seekers. Public people
  /// discovery is controlled only by the explicit switches in Edit Profile.
  Future<void> activateDiscoveryIntent({
    required String category,
    required String interestType,
  }) async {
    return;
  }'''
text = text[:start] + replacement + text[end:]
prefs.write_text(text)

filters = Path('lib/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart')
text = filters.read_text()
old = r'''    // Keep Apply instant. Persistence and public intent visibility sync in the
    // background while the local deck updates immediately.
    unawaited(preferences.upsertFromFilter(next));
    unawaited(
      preferences.activateDiscoveryIntent(
        category: cat,
        interestType: cat == 'buyers'
            ? 'sale'
            : cat == 'renters'
            ? 'rent'
            : _interestType,
      ),
    );
'''
new = r'''    // Keep Apply instant. Persist search filters in the background, but never
    // change the user's public Buyer/Renter/Seeker visibility from browsing.
    unawaited(preferences.upsertFromFilter(next));
'''
text = replace_once(text, old, new, 'remove automatic people activation')
text = text.replace(
    "const SnackBar(content: Text('Filters applied. Matching people can now find your profile.'))",
    "const SnackBar(content: Text('Filters applied. Your deck is updating.'))",
)
text = text.replace(
    "'Make your profile visible in Seekers',",
    "'Browse workers to hire',",
)
filters.write_text(text)

# ---------------------------------------------------------------------------
# Dashboard previews/counts only include explicit canonical opt-ins.
# ---------------------------------------------------------------------------
dash = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
text = dash.read_text()
old = r'''  switch (id) {
    case 'buyers':
      return intentions.any((i) => i == 'buyer' || i.startsWith('buy_'));
    case 'renters':
      return intentions.any((i) => i == 'renter' || i.startsWith('rent_'));
    case 'seekers':
      return intentions.any(
        (i) => i == 'seeker' || i == 'hire_service' || i.startsWith('hire_'),
      );
    default:
      return false;
  }
'''
new = r'''  switch (id) {
    case 'buyers':
      return intentions.contains('buyer');
    case 'renters':
      return intentions.contains('renter');
    case 'seekers':
      return intentions.contains('seeker');
    default:
      return false;
  }
'''
text = replace_once(text, old, new, 'dashboard explicit people opt-in')
dash.write_text(text)

# ---------------------------------------------------------------------------
# Shared listing card understands person cards without showing price/match junk.
# ---------------------------------------------------------------------------
card = Path('lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart')
text = card.read_text()
text = replace_once(
    text,
    "import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';\n",
    "import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';\nimport 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';\n",
    'person avatar import',
)
text = text.replace(
    "              if (!_zoomed)\n                Positioned(\n                  top: 66,",
    "              if (!_zoomed && widget.listing.category != 'person')\n                Positioned(\n                  top: 66,",
    1,
)
text = text.replace(
    "                                    widget.listing.formattedPrice,",
    "                                    widget.listing.category == 'person'\n                                        ? (widget.listing.title ?? 'Swipess member')\n                                        : widget.listing.formattedPrice,",
    1,
)
text = text.replace(
    "                              widget.listing.title ?? 'Listing',",
    "                              widget.listing.category == 'person'\n                                  ? (widget.listing.description ??\n                                      widget.listing.formattedLocation)\n                                  : (widget.listing.title ?? 'Listing'),",
    1,
)
text = replace_once(
    text,
    "  Widget _fallback() => const ColoredBox(color: Color(0xFF111827));\n",
    r'''  Widget _fallback() {
    if (widget.listing.category == 'person') {
      return FunAvatar(
        seed: widget.listing.ownerId ?? widget.listing.id,
        size: 420,
        borderRadius: BorderRadius.zero,
      );
    }
    return const ColoredBox(color: Color(0xFF111827));
  }
''',
    'person avatar fallback',
)
old_actions = r'''      children: [
        _RailButton(
          onTap: onAi,
          child: Text(
            'AI',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
            ),
          ),
        ),
        _RailButton(
          onTap: onShare,
          child: Icon(
            Icons.share_rounded,
            size: 17,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
        _RailButton(
          onTap: onMessage,
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 17,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
        _RailButton(
          onTap: onInsights,
          child: Icon(
            Icons.bar_chart_rounded,
            size: 17,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
        _RailButton(
          onTap: onReport,
          child: Icon(
            Icons.flag_outlined,
            size: 17,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
      ],
'''
new_actions = r'''      children: [
        if (onAi != null)
          _RailButton(
            onTap: onAi,
            child: Text(
              'AI',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
              ),
            ),
          ),
        if (onShare != null)
          _RailButton(
            onTap: onShare,
            child: const Icon(
              Icons.share_rounded,
              size: 17,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
            ),
          ),
        if (onMessage != null)
          _RailButton(
            onTap: onMessage,
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 17,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
            ),
          ),
        if (onInsights != null)
          _RailButton(
            onTap: onInsights,
            child: const Icon(
              Icons.person_outline_rounded,
              size: 17,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
            ),
          ),
        if (onReport != null)
          _RailButton(
            onTap: onReport,
            child: const Icon(
              Icons.flag_outlined,
              size: 17,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
            ),
          ),
      ],
'''
text = replace_once(text, old_actions, new_actions, 'conditional card action rail')
card.write_text(text)

# One-shot cleanup: the resulting source commit should not keep patch machinery.
Path('tool/unify_people_swipe_flow_20260903.py').unlink(missing_ok=True)
Path('.github/workflows/unify-people-swipe-flow-20260903.yml').unlink(missing_ok=True)
