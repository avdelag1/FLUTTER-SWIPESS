import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/live_map_screen.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart'
    as swipe_repo;
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/chrome_reveal_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_insights_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_report_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_share_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipeable_card_stack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap listing swipe deck — no like/dislike buttons; chrome auto-hides ~5s.
class ClientSwipeContainer extends ConsumerStatefulWidget {
  const ClientSwipeContainer({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  final String categoryId;
  final String categoryTitle;

  @override
  ConsumerState<ClientSwipeContainer> createState() =>
      _ClientSwipeContainerState();
}

class _ClientSwipeContainerState extends ConsumerState<ClientSwipeContainer> {
  List<Listing>? _deck;
  final List<Listing> _passed = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chromeRevealProvider.notifier).reveal();
    });
  }

  void _ensureDeck(List<Listing> source) {
    _deck ??= List<Listing>.from(source);
  }

  Future<void> _message(Listing listing) async {
    final ownerId = listing.ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner unavailable for messaging')),
      );
      return;
    }
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me != null && me == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your listing')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final convoId = await swipe_repo.SwipeRepository().startConversation(
          ownerId: ownerId,
          listingId: listing.id,
        );
    if (!mounted || convoId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: ChatConversation(
            id: convoId,
            otherUserId: ownerId,
            name: listing.title ?? 'Owner',
            lastMessage: '',
            timestamp: 'now',
            listingTag: listing.title,
          ),
        ),
      ),
    );
  }

  void _undo() {
    if (_passed.isEmpty || _deck == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      final last = _passed.removeLast();
      _deck = [last, ..._deck!];
    });
    ref.read(chromeRevealProvider.notifier).reveal();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(swipeListingsProvider(widget.categoryId));
    final chrome = ref.watch(chromeRevealProvider);
    final profile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: listingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading swipes: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (listings) {
          _ensureDeck(listings);
          final deck = _deck ?? listings;

          return Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(
                      10,
                      chrome.chromeVisible ? 56 : 8,
                      10,
                      chrome.chromeVisible ? 78 : 16,
                    ),
                    child: deck.isEmpty
                        ? const Center(
                            child: Text(
                              "You've seen all listings in this category!",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : SwipeableCardStack(
                            listings: deck,
                            railVisible: chrome.railVisible,
                            canUndo: _passed.isNotEmpty,
                            onUndo: _undo,
                            onBack: () => Navigator.of(context).pop(),
                            onSummonChrome: () {
                              ref.read(chromeRevealProvider.notifier).toggle();
                            },
                            onOpenAi: () {
                              ref.read(chromeRevealProvider.notifier).reveal();
                              showIntelCoreSheet(context);
                            },
                            onOpenMap: () {
                              ref.read(chromeRevealProvider.notifier).reveal();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LiveMapScreen(),
                                ),
                              );
                            },
                            onInsights: (listing) {
                              ref.read(chromeRevealProvider.notifier).reveal();
                              showListingInsightsSheet(
                                context,
                                listing: listing,
                                onMessage: () => _message(listing),
                                onShare: () => showListingShareSheet(
                                  context,
                                  listing: listing,
                                ),
                                onReport: () => showListingReportSheet(
                                  context,
                                  listing: listing,
                                ),
                              );
                            },
                            onShare: (listing) {
                              showListingShareSheet(context, listing: listing);
                            },
                            onMessage: _message,
                            onReport: (listing) {
                              showListingReportSheet(context, listing: listing);
                            },
                            onSwiped: (listing, direction) {
                              setState(() {
                                _passed.add(listing);
                                _deck = List<Listing>.from(deck)
                                  ..removeWhere((l) => l.id == listing.id);
                              });
                              final authUser = Supabase
                                  .instance.client.auth.currentUser?.id;
                              if (authUser != null) {
                                if (direction == SwipeDirection.right) {
                                  ref
                                      .read(swipeRepositoryProvider)
                                      .registerSwipeRight(
                                          authUser, listing.id);
                                } else {
                                  ref
                                      .read(swipeRepositoryProvider)
                                      .registerSwipeLeft(
                                          authUser, listing.id);
                                }
                              }
                              ref
                                  .read(chromeRevealProvider.notifier)
                                  .reveal();
                            },
                          ),
                  ),
                ),
              ),

              // Cap header — fades after ~5s
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: chrome.chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !chrome.chromeVisible,
                    child: AppTopBar(
                      firstName: profile?.name.split(' ').first,
                      avatarUrl: profile?.avatarUrl,
                      onProfileTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: AnimatedOpacity(
                    opacity: chrome.chromeVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !chrome.chromeVisible,
                      child: _SwipeDeckDock(
                        onDashboard: () => Navigator.of(context).pop(),
                        onAi: () => showIntelCoreSheet(context),
                        onAdd: () => showCreateListingChooser(context),
                        onTokens: () => showGlassModal(
                          context: context,
                          builder: (_) => const TokensModal(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwipeDeckDock extends StatelessWidget {
  const _SwipeDeckDock({
    required this.onDashboard,
    required this.onAi,
    required this.onAdd,
    required this.onTokens,
  });

  final VoidCallback onDashboard;
  final VoidCallback onAi;
  final VoidCallback onAdd;
  final VoidCallback onTokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.dashWell.withAlpha(245),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(200), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DockIcon(icon: Icons.bolt_rounded, onTap: onDashboard),
              _DockIcon(
                icon: Icons.local_fire_department_rounded,
                onTap: onTokens,
              ),
              _DockIcon(icon: Icons.smart_toy_outlined, onTap: onAi),
              _DockIcon(
                icon: Icons.add_circle_rounded,
                onTap: onAdd,
                accent: true,
              ),
              _DockIcon(
                icon: Icons.chat_bubble_outline_rounded,
                onTap: onAi,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent ? const Color(0x33FF4D6A) : Colors.transparent,
          border: accent
              ? Border.all(color: const Color(0xFFFF4D6A), width: 1.4)
              : null,
        ),
        child: Icon(
          icon,
          size: accent ? 22 : 18,
          color: accent ? const Color(0xFFFF4D6A) : Colors.white,
        ),
      ),
    );
  }
}
