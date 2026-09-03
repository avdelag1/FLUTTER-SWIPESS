import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/roommates/domain/roommate_profile.dart';
import 'package:flutter_swipes/src/features/roommates/presentation/providers/roommates_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/pull_down_to_dismiss.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipeable_card_stack.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Roommate discovery deliberately reuses the same card engine as Properties,
/// Workers, Vehicles and the Buyer/Renter/Seeker people decks. Horizontal
/// swipes are like/pass; vertical swipes move next/previous with the same
/// page-locked interaction and physics as every other Swipess discovery deck.
class RoommateMatchingScreen extends ConsumerStatefulWidget {
  const RoommateMatchingScreen({super.key});

  @override
  ConsumerState<RoommateMatchingScreen> createState() =>
      _RoommateMatchingScreenState();
}

class _RoommateMatchingScreenState
    extends ConsumerState<RoommateMatchingScreen> {
  List<RoommateProfile>? _deck;
  RoommateProfile? _undoable;
  bool _retrying = false;

  void _ensureDeck(List<RoommateProfile> source) {
    _deck ??= List<RoommateProfile>.from(source);
  }

  void _goBack() {
    AppHaptics.light();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppPaths.clientDashboard);
    }
  }

  void _invalidateDecisionCaches() {
    ref.invalidate(roommatesProvider);
    ref.invalidate(mapProfilesProvider);
    ref.invalidate(likedPeopleProvider);
    ref.invalidate(likedPeopleIdsProvider);
  }

  Listing _asSwipeListing(RoommateProfile profile) {
    final details = <String>[
      'Looking for a roommate',
      if ((profile.occupation ?? '').trim().isNotEmpty)
        profile.occupation!.trim(),
      if ((profile.city ?? '').trim().isNotEmpty)
        'Looking in ${profile.city!.trim()}',
      if (profile.budget != null && profile.budget! > 0)
        'Budget ${profile.budget!.toStringAsFixed(0)}/month',
      if ((profile.bio ?? '').trim().isNotEmpty) profile.bio!.trim(),
    ];
    final avatar = profile.avatarUrl?.trim();
    return Listing(
      id: profile.userId,
      ownerId: profile.userId,
      title: profile.title,
      description: details.join(' · '),
      category: 'person',
      listingType: 'roommate',
      city: profile.city,
      location: (profile.city ?? '').trim().isEmpty
          ? 'Swipess'
          : profile.city!.trim(),
      images: avatar == null || avatar.isEmpty ? const [] : [avatar],
      amenities: const <String>[],
      isActive: true,
      status: 'active',
    );
  }

  RoommateProfile? _profileFor(String id, Map<String, RoommateProfile> byId) =>
      byId[id];

  Future<void> _afterSwipe(
    RoommateProfile profile,
    SwipeDirection direction,
  ) async {
    try {
      if (direction == SwipeDirection.right) {
        await SwipeRepository().likeProfile(profile.userId);
      } else {
        await SwipeRepository().dislikeProfile(profile.userId);
      }
      _invalidateDecisionCaches();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final current = _deck ?? <RoommateProfile>[];
        if (!current.any((item) => item.userId == profile.userId)) {
          _deck = <RoommateProfile>[profile, ...current];
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
        _deck = <RoommateProfile>[last, ...?_deck];
      });
      _invalidateDecisionCaches();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not undo that decision.')),
      );
    }
  }

  Future<void> _message(RoommateProfile profile) async {
    AppHaptics.medium();
    try {
      final convoId = await SwipeRepository().startConversation(
        ownerId: profile.userId,
        initialMessage: 'Hey! I saw your roommate profile on Swipess.',
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
          avatarUrl: profile.avatarUrl,
          listingTag: 'ROOMMATE',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need a message token or membership to start this chat.',
          ),
        ),
      );
    }
  }

  void _openProfile(RoommateProfile profile) {
    AppHaptics.medium();
    context.push(AppPaths.profile(profile.userId));
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
            const Text(
              'NO ROOMMATES POSTED YET',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only members who explicitly turn Roommate Mode on can appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('FILTERS'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _deck = null;
                    ref.invalidate(roommatesProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('REFRESH'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deckScaffold(List<RoommateProfile> profiles) {
    _ensureDeck(profiles);
    final deck = _deck ?? profiles;
    if (deck.isEmpty) return _emptyState();

    final byId = <String, RoommateProfile>{
      for (final profile in deck) profile.userId: profile,
    };
    final listings = deck.map(_asSwipeListing).toList(growable: false);

    return Stack(
      fit: StackFit.expand,
      children: [
        SwipeableCardStack(
          listings: listings,
          railVisible: true,
          canUndo: _undoable != null,
          onUndo: _undo,
          onBack: _goBack,
          onOpenMap: () => context.push(AppPaths.map),
          onInsights: (listing) {
            final profile = _profileFor(listing.id, byId);
            if (profile != null) _openProfile(profile);
          },
          onMessage: (listing) {
            final profile = _profileFor(listing.id, byId);
            if (profile != null) unawaited(_message(profile));
          },
          onShare: (listing) {
            final profile = _profileFor(listing.id, byId);
            if (profile != null) _openProfile(profile);
          },
          onSwiped: (listing, direction) {
            final profile = _profileFor(listing.id, byId);
            if (profile == null) return;
            setState(() {
              _undoable = profile;
              _deck = List<RoommateProfile>.from(deck)
                ..removeWhere((item) => item.userId == profile.userId);
            });
            unawaited(_afterSwipe(profile, direction));
          },
        ),
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Center(child: _FilterPill(onTap: _openFilters)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(roommatesProvider);
    final cached = async.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: PullDownToDismiss(
        onDismiss: _goBack,
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
                                _deck = null;
                                ref.invalidate(roommatesProvider);
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

  Future<void> _openFilters() async {
    final current = ref.read(roommateFiltersProvider);
    var draft = current;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MatteSurface.canvas(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROOMMATE FILTERS',
                        style: AppTheme.displayItalic.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Budget \$${draft.minBudget.toStringAsFixed(0)} – \$${draft.maxBudget.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                          fontSize: 12,
                        ),
                      ),
                      RangeSlider(
                        values: RangeValues(draft.minBudget, draft.maxBudget),
                        min: 200,
                        max: 8000,
                        divisions: 39,
                        activeColor: AppTheme.brandPrimary,
                        labels: RangeLabels(
                          draft.minBudget.toStringAsFixed(0),
                          draft.maxBudget.toStringAsFixed(0),
                        ),
                        onChanged: (v) => setModal(() {
                          draft = draft.copyWith(
                            minBudget: v.start,
                            maxBudget: v.end,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Age ${draft.minAge} – ${draft.maxAge}',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                          fontSize: 12,
                        ),
                      ),
                      RangeSlider(
                        values: RangeValues(
                          draft.minAge.toDouble(),
                          draft.maxAge.toDouble(),
                        ),
                        min: 18,
                        max: 70,
                        divisions: 52,
                        activeColor: AppTheme.brandPrimary,
                        onChanged: (v) => setModal(() {
                          draft = draft.copyWith(
                            minAge: v.start.round(),
                            maxAge: v.end.round(),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CITY',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Any'),
                            selected: draft.city == null,
                            onSelected: (_) => setModal(
                              () => draft = draft.copyWith(clearCity: true),
                            ),
                            selectedColor: AppTheme.brandPrimary,
                          ),
                          for (final city
                              in ListingTaxonomies.popularCities.take(8))
                            ChoiceChip(
                              label: Text(city),
                              selected: draft.city == city,
                              onSelected: (_) => setModal(
                                () => draft = draft.copyWith(city: city),
                              ),
                              selectedColor: AppTheme.brandPrimary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            ref
                                .read(roommateFiltersProvider.notifier)
                                .set(draft);
                            setState(() => _deck = null);
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Apply filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(150),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withAlpha(42)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'ROOMMATE FILTERS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
