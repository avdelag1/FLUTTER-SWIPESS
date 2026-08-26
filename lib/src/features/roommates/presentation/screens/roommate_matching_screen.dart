import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/roommates/domain/roommate_profile.dart';
import 'package:flutter_swipes/src/features/roommates/presentation/providers/roommates_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap RoommateMatching — deck + filters + profile swipe + message.
class RoommateMatchingScreen extends ConsumerStatefulWidget {
  const RoommateMatchingScreen({super.key});

  @override
  ConsumerState<RoommateMatchingScreen> createState() =>
      _RoommateMatchingScreenState();
}

class _RoommateMatchingScreenState
    extends ConsumerState<RoommateMatchingScreen> {
  int _index = 0;
  bool _showDetails = false;
  bool _busy = false;
  final List<RoommateProfile> _history = [];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(roommatesProvider);

    return Scaffold(
      body: async.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: MatteSurface.ink(context),
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(roommatesProvider),
            child: const Text('Could not load roommates — retry'),
          ),
        ),
        data: (profiles) {
          if (profiles.isEmpty || _index >= profiles.length) {
            return SafeArea(
              child: Column(
                children: [
                  _Header(
                    canUndo: _history.isNotEmpty,
                    onBack: () => Navigator.of(context).pop(),
                    onFilters: _openFilters,
                    onUndo: _undo,
                  ),
                  Spacer(),
                  Text(
                    'NO MORE PROFILES',
                    style: AppTheme.displayItalic.copyWith(fontSize: 22),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Adjust filters or check back later.',
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.muted(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() => _index = 0);
                      ref.invalidate(roommatesProvider);
                    },
                    child: const Text('Reload deck'),
                  ),
                  const Spacer(),
                ],
              ),
            );
          }

          final current = profiles[_index];
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        current.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_showDetails)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 150,
                  child: _DetailsPanel(profile: current),
                ),
              SafeArea(
                child: _Header(
                  canUndo: _history.isNotEmpty,
                  onBack: () => Navigator.of(context).pop(),
                  onFilters: _openFilters,
                  onUndo: _undo,
                  onToggleDetails: () =>
                      setState(() => _showDetails = !_showDetails),
                  detailsOpen: _showDetails,
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _swipe(current, like: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('PASS'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: _busy ? null : () => _message(current),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy
                            ? null
                            : () => _swipe(current, like: true),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('LIKE'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _invalidateDecisionCaches() {
    ref.invalidate(roommatesProvider);
    ref.invalidate(mapProfilesProvider);
    ref.invalidate(likedPeopleProvider);
  }

  Future<void> _swipe(RoommateProfile profile, {required bool like}) async {
    setState(() => _busy = true);
    AppHaptics.selection();
    final repo = SwipeRepository();
    try {
      if (like) {
        await repo.likeProfile(profile.userId);
      } else {
        await repo.dislikeProfile(profile.userId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save that decision. Try again.'),
        ),
      );
      return;
    }

    _invalidateDecisionCaches();
    if (!mounted) return;
    setState(() {
      _history.add(profile);
      _index++;
      _showDetails = false;
      _busy = false;
    });
    if (like) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved ${profile.name}')));
    }
  }

  Future<void> _undo() async {
    if (_history.isEmpty || _index <= 0) return;
    final last = _history.last;
    AppHaptics.light();
    try {
      await SwipeRepository().undoProfileSwipe(last.userId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not undo that decision.')),
      );
      return;
    }
    _history.removeLast();
    _invalidateDecisionCaches();
    if (!mounted) return;
    setState(() {
      _index = (_index - 1).clamp(0, 9999);
      _showDetails = false;
    });
  }

  Future<void> _message(RoommateProfile profile) async {
    setState(() => _busy = true);
    try {
      final convoId = await SwipeRepository().startConversation(
        ownerId: profile.userId,
        initialMessage: 'Hey! Saw your roommate profile on Swipess.',
      );
      if (!mounted) return;
      if (convoId != null) {
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
            listingTag: 'Roommate',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need a message token or membership to start this chat.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFilters() async {
    final current = ref.read(roommateFiltersProvider);
    var draft = current;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROOMMATE FILTERS',
                    style: AppTheme.displayItalic.copyWith(fontSize: 18),
                  ),
                  SizedBox(height: 18),
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
                  SizedBox(height: 8),
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
                  SizedBox(height: 12),
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
                      for (final city in ListingTaxonomies.popularCities.take(
                        8,
                      ))
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
                        ref.read(roommateFiltersProvider.notifier).set(draft);
                        setState(() => _index = 0);
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
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onFilters,
    required this.onUndo,
    required this.canUndo,
    this.onToggleDetails,
    this.detailsOpen = false,
  });

  final VoidCallback onBack;
  final VoidCallback onFilters;
  final VoidCallback onUndo;
  final bool canUndo;
  final VoidCallback? onToggleDetails;
  final bool detailsOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: MatteSurface.ink(context),
            ),
          ),
          Text(
            'ROOMMATES',
            style: AppTheme.displayItalic.copyWith(fontSize: 20),
          ),
          Spacer(),
          if (onToggleDetails != null)
            IconButton(
              tooltip: 'Details',
              onPressed: onToggleDetails,
              icon: Icon(
                detailsOpen
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: MatteSurface.muted(context),
              ),
            ),
          IconButton(
            tooltip: 'Undo',
            onPressed: canUndo ? onUndo : null,
            icon: Icon(
              Icons.undo_rounded,
              color: canUndo ? Colors.white : Colors.white24,
            ),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: onFilters,
            icon: Icon(Icons.tune_rounded, color: MatteSurface.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.profile});
  final RoommateProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.name,
            style: TextStyle(
              color: MatteSurface.ink(context),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            profile.bio?.trim().isNotEmpty == true
                ? profile.bio!
                : 'No bio yet — say hi and ask about living style.',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.city != null)
                _pill(context, Icons.place_outlined, profile.city!),
              if (profile.occupation != null)
                _pill(context, Icons.work_outline_rounded, profile.occupation!),
              if (profile.budget != null)
                _pill(
                  context,
                  Icons.attach_money_rounded,
                  '\$${profile.budget!.toStringAsFixed(0)}/mo',
                ),
              if (profile.age != null)
                _pill(context, Icons.cake_outlined, '${profile.age} yrs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MatteSurface.muted(context)),
          SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.ink(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
