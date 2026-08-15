import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/magic_ai_profile_sheet.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/live_map_screen.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart'
    as swipe_repo;
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/chrome_reveal_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/chrome_summon_zones.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_insights_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_report_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_share_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/match_celebrate_modal.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/pull_down_to_dismiss.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_error_state.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_exhausted_state.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipeable_card_stack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap listing swipe deck — chrome auto-hides after seven seconds and the
/// full-bleed photo grows smoothly into the released space.
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
  /// One-shot return: only the most recent swipe can be restored once.
  Listing? _undoable;
  late String _categoryId;
  bool _demoMatchShown = false;
  bool _retrying = false;
  bool _detecting = false;
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chromeRevealProvider.notifier).reveal();
    });
  }

  @override
  void didUpdateWidget(covariant ClientSwipeContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _categoryId = widget.categoryId;
      _deck = null;
      _undoable = null;
    }
  }

  String get _categoryLabel {
    switch (_categoryId) {
      case 'property':
        return 'properties';
      case 'motorcycle':
        return 'motorcycles';
      case 'bicycle':
        return 'bicycles';
      case 'yacht':
        return 'yachts';
      case 'services':
      case 'worker':
        return 'workers';
      default:
        return _categoryId;
    }
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
    AppHaptics.medium();
    final convoId = await swipe_repo.SwipeRepository().startConversation(
          ownerId: ownerId,
          listingId: listing.id,
        );
    if (!mounted || convoId == null) return;
    await showChatPopup(
      context,
      isNewConversation: true,
      conversation: ChatConversation(
        id: convoId,
        otherUserId: ownerId,
        name: listing.title ?? 'Owner',
        lastMessage: '',
        timestamp: 'now',
        listingTag: listing.title,
      ),
    );
  }

  void _goDashboard() {
    ref.read(navTabProvider.notifier).set(NavTab.dashboard);
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
    context.go(AppPaths.clientDashboard);
  }

  void _goMessages() {
    ref.read(navTabProvider.notifier).set(NavTab.messages);
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
    context.go(AppPaths.messages);
  }

  void _undo() {
    final last = _undoable;
    if (last == null || _deck == null) return;
    AppHaptics.selection();
    setState(() {
      _undoable = null;
      _deck = [last, ..._deck!];
    });
    ref.read(chromeRevealProvider.notifier).reveal();
  }

  Widget _exhausted() {
    return SwipeExhaustedState(
      categoryName: _categoryLabel,
      activeCategory: _categoryId,
      detecting: _detecting,
      detected: _detected,
      onBack: _goDashboard,
      onRadiusChange: (km) {
        ref.read(discoveryLocationProvider.notifier).setRadiusKm(km);
        _deck = null;
        ref.invalidate(swipeListingsProvider(_categoryId));
      },
      onDetectLocation: () async {
        setState(() => _detecting = true);
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(() {
          _detecting = false;
          _detected = true;
        });
      },
      onOpenFilters: () => FilterBottomSheet.show(context),
      onOpenMap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LiveMapScreen()),
        );
      },
      onOpenAi: () => showMagicAiProfileSheet(context),
      onCategoryChange: (cat) {
        if (cat == 'events') {
          Navigator.of(context).pop();
          ref.read(navTabProvider.notifier).set(NavTab.events);
          return;
        }
        setState(() {
          _categoryId = cat;
          _deck = null;
          _undoable = null;
        });
        ref.read(chromeRevealProvider.notifier).reveal();
      },
    );
  }

  Future<void> _afterSwipe(Listing listing, SwipeDirection direction) async {
    final authUser = Supabase.instance.client.auth.currentUser?.id;
    if (authUser != null) {
      if (direction == SwipeDirection.right) {
        await ref
            .read(swipeRepositoryProvider)
            .registerSwipeRight(authUser, listing.id);
      } else {
        await ref
            .read(swipeRepositoryProvider)
            .registerSwipeLeft(authUser, listing.id);
      }
      ref.read(dailyQuestsProvider.notifier).increment('swipe');
    }
    if (direction == SwipeDirection.right && mounted) {
      var matched = false;
      if (authUser != null) {
        matched = await swipe_repo.SwipeRepository().checkForMatch(listing.id);
      } else if (!_demoMatchShown) {
        matched = true;
        _demoMatchShown = true;
      }
      if (matched && mounted) {
        final profile = ref.read(currentProfileProvider).value;
        await showMatchCelebrateModal(
          context,
          clientName: listing.title ?? 'this listing',
          clientImageUrl: profile?.avatarUrl,
          ownerImageUrl:
              listing.images.isNotEmpty ? listing.images.first : null,
          onMessage: () => _message(listing),
        );
      }
    }
    if (mounted) {
      ref.read(chromeRevealProvider.notifier).reveal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(swipeListingsProvider(_categoryId));
    final chrome = ref.watch(chromeRevealProvider);
    final profile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      extendBody: true,
      body: PullDownToDismiss(
        onDismiss: _goDashboard,
        child: listingsAsync.when(
        loading: () => const SizedBox.expand(child: SwipeLoadingSkeleton()),
        error: (err, _) => SwipeErrorState(
          isRetrying: _retrying,
          onRetry: () async {
            setState(() => _retrying = true);
            ref.invalidate(swipeListingsProvider(_categoryId));
            await Future<void>.delayed(const Duration(milliseconds: 400));
            if (mounted) setState(() => _retrying = false);
          },
        ),
        data: (listings) {
          _ensureDeck(listings);
          final deck = _deck ?? listings;

          // Must expand. ChromeSummonZones is a zero-size child when the
          // header is up — a loose Stack then collapses to 0×0 and the
          // cards never paint (black page until chrome used to hide).
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: AnimatedPadding(
                    duration: Duration(
                      milliseconds: chrome.chromeVisible ? 360 : 340,
                    ),
                    curve: const Cubic(0.25, 0.1, 0.25, 1),
                    padding: EdgeInsets.fromLTRB(
                      8,
                      chrome.chromeVisible ? 76 : 8,
                      8,
                      chrome.chromeVisible ? 72 : 12,
                    ),
                    child: deck.isEmpty
                        ? _exhausted()
                        : SwipeableCardStack(
                            listings: deck,
                            railVisible: chrome.railVisible,
                            canUndo: _undoable != null,
                            onUndo: _undo,
                            onBack: _goDashboard,
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
                                _undoable = listing;
                                _deck = List<Listing>.from(deck)
                                  ..removeWhere((l) => l.id == listing.id);
                              });
                              _afterSwipe(listing, direction);
                            },
                          ),
                  ),
                ),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !chrome.chromeVisible,
                  child: AnimatedOpacity(
                    opacity: chrome.chromeVisible ? 1 : 0,
                    duration: Duration(
                      milliseconds: chrome.chromeVisible ? 360 : 340,
                    ),
                    curve: const Cubic(0.25, 0.1, 0.25, 1),
                    child: AnimatedSlide(
                      offset: chrome.chromeVisible
                          ? Offset.zero
                          : const Offset(0, -0.12),
                      duration: Duration(
                        milliseconds: chrome.chromeVisible ? 360 : 340,
                      ),
                      curve: const Cubic(0.25, 0.1, 0.25, 1),
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
              ),

              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !chrome.chromeVisible,
                  child: AnimatedOpacity(
                    opacity: chrome.chromeVisible ? 1 : 0,
                    duration: Duration(
                      milliseconds: chrome.chromeVisible ? 360 : 340,
                    ),
                    curve: const Cubic(0.25, 0.1, 0.25, 1),
                    child: AnimatedSlide(
                      offset: chrome.chromeVisible
                          ? Offset.zero
                          : const Offset(0, 0.5),
                      duration: Duration(
                        milliseconds: chrome.chromeVisible ? 360 : 340,
                      ),
                      curve: const Cubic(0.25, 0.1, 0.25, 1),
                      child: SafeArea(
                  child: SwipeDeckDock(
                    onDashboard: _goDashboard,
                    onMessages: _goMessages,
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
              ),
              Positioned.fill(
                child: ChromeSummonZones(
                  visible: chrome.chromeVisible,
                  onSummon: () =>
                      ref.read(chromeRevealProvider.notifier).reveal(),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

class SwipeDeckDock extends StatelessWidget {
  const SwipeDeckDock({
    super.key,
    required this.onDashboard,
    required this.onMessages,
    required this.onAi,
    required this.onAdd,
    required this.onTokens,
  });

  final VoidCallback onDashboard;
  final VoidCallback onMessages;
  final VoidCallback onAi;
  final VoidCallback onAdd;
  final VoidCallback onTokens;

  @override
  Widget build(BuildContext context) {
    const iconIdle = Colors.white;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(36), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DockIcon(
                semanticLabel: 'Dashboard',
                icon: Icons.dashboard_rounded,
                onTap: onDashboard,
                idleColor: iconIdle,
              ),
              _DockIcon(
                semanticLabel: 'Tokens',
                icon: Icons.diamond_rounded,
                onTap: onTokens,
                idleColor: iconIdle,
              ),
              _DockIcon(
                semanticLabel: 'AI concierge',
                icon: Icons.smart_toy_rounded,
                onTap: onAi,
                idleColor: iconIdle,
              ),
              _DockIcon(
                semanticLabel: 'Create listing',
                icon: Icons.add_rounded,
                onTap: onAdd,
                accent: true,
                idleColor: iconIdle,
              ),
              _DockIcon(
                semanticLabel: 'Messages',
                icon: Icons.chat_bubble_rounded,
                onTap: onMessages,
                idleColor: iconIdle,
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
    required this.idleColor,
    required this.semanticLabel,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color idleColor;
  final String semanticLabel;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent ? const Color(0xFFFF4D00) : const Color(0x1FFFFFFF),
          border: accent
              ? null
              : Border.all(color: const Color(0x2EFFFFFF), width: 1),
        ),
        child: Icon(
          icon,
          size: accent ? 24 : 21,
          color: accent ? const Color(0xFFFF4D6A) : idleColor,
        ),
      ),
    );
  }
}
