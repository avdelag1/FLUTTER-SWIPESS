import 'dart:async';

import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/dashboard_dock.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/magic_ai_profile_sheet.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/utils/open_events_feed.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/direct_request_sheet.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';

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
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

/// Listing swipe deck. Right = free interest, left = pass. Messaging is free
/// after a match; before a match the user can wait or send a Direct Request.
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
    ref.read(chromeRevealProvider.notifier).reveal();
  }

  @override
  void didUpdateWidget(covariant ClientSwipeContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _categoryId = widget.categoryId;
      _deck = null;
      _undoable = null;
      ref.read(chromeRevealProvider.notifier).reveal();
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
    final me = ref.read(currentUserProvider)?.id;
    if (me != null && me == ownerId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('This is your listing')));
      return;
    }

    final repo = ref.read(swipeRepositoryProvider);
    final matched = await repo.checkForMatch(listing.id);
    if (!mounted) return;

    if (!matched) {
      await showDirectRequestSheet(
        context,
        receiverId: ownerId,
        listingId: listing.id,
        listingTitle: listing.title ?? 'this listing',
      );
      return;
    }

    AppHaptics.medium();
    try {
      final convoId = await repo.startConversation(
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chat opens free after a match. Send a Direct Request if you need an answer sooner.',
          ),
        ),
      );
    }
  }

  void _goDashboard() {
    AppHaptics.light();
    ref.read(navTabProvider.notifier).set(NavTab.dashboard);
    ref.read(chromeRevealProvider.notifier).reveal();
    ref.read(chromeVisibilityProvider.notifier).show();

    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop();
      return;
    }
    GoRouter.of(context).go(AppPaths.clientDashboard);
  }

  void _goMessages() {
    final router = GoRouter.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    ref.read(navTabProvider.notifier).set(NavTab.messages);
    ref.read(chromeRevealProvider.notifier).reveal();
    ref.read(chromeVisibilityProvider.notifier).show();
    if (rootNav.canPop()) rootNav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go(AppPaths.messages);
    });
  }

  void _invalidateDecisionCaches() {
    ref.invalidate(swipeListingsProvider(_categoryId));
    ref.invalidate(mapListingsProvider);
    ref.invalidate(likedListingsProvider);
    ref.invalidate(likedListingIdsProvider);
    ref.invalidate(mapProfilesProvider);
    ref.invalidate(likedPeopleProvider);
    ref.invalidate(likedPeopleIdsProvider);
    ref.invalidate(likedEventIdsProvider);
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

    unawaited(
      ref
          .read(swipeRepositoryProvider)
          .undoSwipe(last.id)
          .then((_) {
            _invalidateDecisionCaches();
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() => _deck?.removeWhere((l) => l.id == last.id));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not undo that decision.')),
            );
          }),
    );
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
        ref.read(overlayModalsProvider.notifier).openPassportMap();
      },
      onOpenAi: () => showMagicAiProfileSheet(context),
      onCategoryChange: (cat) {
        if (cat == 'events') {
          ref.read(chromeRevealProvider.notifier).reveal();
          ref.read(chromeVisibilityProvider.notifier).show();
          openEventsFeed(context, ref: ref, popSwipeDeck: true);
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
    final authUser = ref.read(currentUserProvider)?.id;
    if (authUser != null) {
      if (direction == SwipeDirection.right) {
        await ref
            .read(swipeRepositoryProvider)
            .registerSwipeRight(authUser, listing.id);

        ref.read(appNotificationsProvider.notifier).show(
          title: 'Saved',
          message: listing.title ?? 'Added to your likes',
          type: AppToastType.like,
        );
      } else {
        await ref
            .read(swipeRepositoryProvider)
            .registerSwipeLeft(authUser, listing.id, listing.price);
      }
      _invalidateDecisionCaches();
      ref.read(dailyQuestsProvider.notifier).increment('swipe');
    }
    if (direction == SwipeDirection.right && mounted) {
      var matched = false;
      if (authUser != null) {
        matched = await ref
            .read(swipeRepositoryProvider)
            .checkForMatch(listing.id);
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
          ownerImageUrl: listing.images.isNotEmpty
              ? listing.images.first
              : null,
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

    final cardExpanded = chrome.photoExpanded;
    final cardDuration = Duration(milliseconds: cardExpanded ? 680 : 420);
    final cardCurve = cardExpanded
        ? const Cubic(0.18, 1.16, 0.28, 1.0)
        : Curves.easeOutCubic;
    final chromeDuration = Duration(milliseconds: chrome.chromeVisible ? 360 : 320);

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

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: SafeArea(
                    bottom: false,
                    child: AnimatedPadding(
                      duration: cardDuration,
                      curve: cardCurve,
                      padding: EdgeInsets.fromLTRB(
                        8,
                        cardExpanded ? 8 : 76,
                        8,
                        cardExpanded ? 12 : 72,
                      ),
                      child: deck.isEmpty
                          ? _exhausted()
                          : Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (_) => ref
                                  .read(chromeRevealProvider.notifier)
                                  .keepAlive(),
                              onPointerSignal: (_) => ref
                                  .read(chromeRevealProvider.notifier)
                                  .keepAlive(),
                              child: SwipeableCardStack(
                                listings: deck,
                                railVisible: chrome.railVisible,
                                canUndo: _undoable != null,
                                onUndo: _undo,
                                onBack: _goDashboard,
                                onSummonChrome: () {
                                  ref
                                      .read(chromeRevealProvider.notifier)
                                      .toggle();
                                },
                                onOpenAi: () {
                                  ref
                                      .read(chromeRevealProvider.notifier)
                                      .reveal();
                                  showIntelCoreSheet(context);
                                },
                                onOpenMap: () {
                                  ref
                                      .read(chromeRevealProvider.notifier)
                                      .reveal();
                                  ref
                                      .read(overlayModalsProvider.notifier)
                                      .openPassportMap();
                                },
                                onInsights: (listing) {
                                  ref
                                      .read(chromeRevealProvider.notifier)
                                      .reveal();
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
                                  showListingShareSheet(
                                    context,
                                    listing: listing,
                                  );
                                },
                                onMessage: _message,
                                onReport: (listing) {
                                  showListingReportSheet(
                                    context,
                                    listing: listing,
                                  );
                                },
                                onSwiped: (listing, direction) {
                                  setState(() {
                                    _undoable = listing;
                                    _deck = List<Listing>.from(deck)
                                      ..removeWhere((l) => l.id == listing.id);
                                  });
                                  unawaited(_afterSwipe(listing, direction));
                                },
                              ),
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
                      duration: chromeDuration,
                      curve: Curves.easeOutCubic,
                      child: AnimatedSlide(
                        offset: chrome.chromeVisible
                            ? Offset.zero
                            : const Offset(0, -0.08),
                        duration: chromeDuration,
                        curve: Curves.easeOutCubic,
                        child: AnimatedScale(
                          scale: chrome.chromeVisible ? 1 : 0.985,
                          duration: chromeDuration,
                          curve: Curves.easeOutCubic,
                          child: AppTopBar(
                            firstName: profile?.name.split(' ').first,
                            avatarUrl: profile?.avatarUrl,
                            onProfileTap: () {
                              final rootNav =
                                  Navigator.of(context, rootNavigator: true);
                              if (rootNav.canPop()) {
                                rootNav.pop();
                              }
                              context.go(AppPaths.clientProfile);
                            },
                          ),
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
                      duration: chromeDuration,
                      curve: Curves.easeOutCubic,
                      child: AnimatedSlide(
                        offset: chrome.chromeVisible
                            ? Offset.zero
                            : const Offset(0, 0.16),
                        duration: chromeDuration,
                        curve: Curves.easeOutCubic,
                        child: AnimatedScale(
                          scale: chrome.chromeVisible ? 1 : 0.97,
                          duration: chromeDuration,
                          curve: Curves.easeOutCubic,
                          child: DashboardDock(
                            items: defaultDashboardNavItems,
                            selectedTab: NavTab.dashboard,
                            onTabSelected: (id) {
                              if (id == NavTab.dashboard) {
                                _goDashboard();
                              } else if (id == NavTab.messages) {
                                _goMessages();
                              } else if (id == NavTab.add) {
                                showCreateListingChooser(context);
                              } else if (id == NavTab.ai) {
                                ref
                                    .read(overlayModalsProvider.notifier)
                                    .openConcierge();
                              } else {
                                final router = GoRouter.of(context);
                                final rootNav =
                                    Navigator.of(context, rootNavigator: true);
                                if (rootNav.canPop()) {
                                  rootNav.pop();
                                }
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  router.go(AppPaths.pathForTab(id));
                                });
                                ref.read(navTabProvider.notifier).set(id);
                              }
                            },
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
