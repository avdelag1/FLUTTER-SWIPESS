from pathlib import Path


def replace(path, old, new, count=1):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'Missing expected block in {path}: {old[:160]!r}')
    text = text.replace(old, new, count)
    p.write_text(text)


handoff = 'lib/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart'
quick = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
bento = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
opener = 'lib/src/features/swipes/presentation/utils/open_swipe_deck.dart'
container = 'lib/src/features/swipes/presentation/screens/client_swipe_container.dart'
stack = 'lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart'

replace(handoff, """    this.controller,
    this.wantSound = false,
  });""", """    this.controller,
    this.wantSound = false,
    this.listingId,
    this.categoryId,
  });""")
replace(handoff, """  final VideoPlayerController? controller;
  final bool wantSound;
}""", """  final VideoPlayerController? controller;
  final bool wantSound;

  /// Listing identity carried with the dashboard video so the destination deck
  /// can put the exact previewed listing first before its first frame paints.
  final String? listingId;
  final String? categoryId;
}""")
replace(handoff, """  static SwipeDeckMediaHandoffData? _pending;

  static void set(SwipeDeckMediaHandoffData data) => _pending = data;""", """  static SwipeDeckMediaHandoffData? _pending;

  static String? get pendingListingId => _pending?.listingId;
  static String? get pendingCategoryId => _pending?.categoryId;

  static void set(SwipeDeckMediaHandoffData data) => _pending = data;""")

replace(quick, """  static SwipeDeckMediaHandoffData? captureActiveForDeck(bool wantSound) {
    final state = _active;
    if (state == null) return null;
    return state._captureForDeckHandoff(wantSound);
  }""", """  static SwipeDeckMediaHandoffData? captureActiveForDeck(
    bool wantSound, {
    String? categoryId,
  }) {
    final state = _active;
    if (state == null) return null;
    if (categoryId != null && state.widget.handoffCategoryId != categoryId) {
      return null;
    }
    return state._captureForDeckHandoff(wantSound);
  }""")
replace(quick, """SwipeDeckMediaHandoffData? captureQuickFilterVideoForDeck({
  required bool wantSound,
}) => _VideoPlaybackCoordinator.captureActiveForDeck(wantSound);""", """SwipeDeckMediaHandoffData? captureQuickFilterVideoForDeck({
  required bool wantSound,
  String? categoryId,
}) => _VideoPlaybackCoordinator.captureActiveForDeck(
  wantSound,
  categoryId: categoryId,
);""")
replace(quick, """    this.showMute = true,
    this.enableVideo = true,
  });""", """    this.showMute = true,
    this.enableVideo = true,
    this.sourceListingIds = const <String, String>{},
    this.handoffCategoryId,
  });""")
replace(quick, """  final bool showMute;
  final bool enableVideo;

  @override""", """  final bool showMute;
  final bool enableVideo;

  /// When a dashboard category is showing real listing videos, map each video
  /// URL back to its listing so a tap can continue the exact same movie in the
  /// swipe deck, just like the Events teaser handoff.
  final Map<String, String> sourceListingIds;
  final String? handoffCategoryId;

  @override""")
replace(quick, """  SwipeDeckMediaHandoffData? _captureForDeckHandoff(bool wantSound) {
    if (!_VideoPlaybackCoordinator.owns(this)) return null;

    final player = _video;
    final url = _boundVideoUrl?.trim();""", """  String? _listingIdForUrl(String url) {
    final normalized = url.trim();
    for (final entry in widget.sourceListingIds.entries) {
      if (entry.key.trim() == normalized) return entry.value;
    }
    return null;
  }

  SwipeDeckMediaHandoffData? _captureForDeckHandoff(bool wantSound) {
    if (!_VideoPlaybackCoordinator.owns(this)) return null;

    final player = _video;
    final url = _boundVideoUrl?.trim();""")
replace(quick, """    return SwipeDeckMediaHandoffData(
      videoUrl: url,
      position: player.value.position,
      controller: player,
      wantSound: wantSound,
    );""", """    return SwipeDeckMediaHandoffData(
      videoUrl: url,
      position: player.value.position,
      controller: player,
      wantSound: wantSound,
      listingId: _listingIdForUrl(url),
      categoryId: widget.handoffCategoryId,
    );""")

replace(bento, """import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';""", """import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';""")
replace(bento, """    final unreadCount = counts[item.id] ?? 0;

    final badgeWidget = unreadCount > 0""", """    final unreadCount = counts[item.id] ?? 0;

    const listingVideoQuickFilters = <String>{
      'property',
      'recommended',
      'services',
      'yacht',
      'motorcycle',
      'bicycle',
    };
    final isListingVideoQuickFilter = listingVideoQuickFilters.contains(item.id);
    final previewListings = isListingVideoQuickFilter
        ? (ref.watch(swipeListingsProvider(item.id)).value ?? const <Listing>[])
        : const <Listing>[];
    final seenVideoUrls = <String>{};
    final videoListings = previewListings.where((listing) {
      final url = listing.videoUrl?.trim();
      return url != null && url.isNotEmpty && seenVideoUrls.add(url);
    }).toList(growable: false);
    final liveListingMedia = videoListings.isNotEmpty
        ? videoListings.map((listing) => listing.videoUrl!.trim()).toList(growable: false)
        : BentoMediaPools.forId(item.id);
    final sourceListingIds = <String, String>{
      for (final listing in videoListings) listing.videoUrl!.trim(): listing.id,
    };

    final badgeWidget = unreadCount > 0""")
replace(bento, """          media: BentoMediaPools.forId(item.id),
          stagger: Duration(seconds: int.parse(item.delaySeconds)),
          isLight: isLight,
          enableVideo: true,""", """          media: liveListingMedia,
          sourceListingIds: sourceListingIds,
          handoffCategoryId: videoListings.isNotEmpty ? item.id : null,
          stagger: Duration(seconds: int.parse(item.delaySeconds)),
          isLight: isLight,
          enableVideo: true,""")
replace(bento, """    required this.onTap,
    this.enableVideo = true,
  });""", """    required this.onTap,
    this.enableVideo = true,
    this.sourceListingIds = const <String, String>{},
    this.handoffCategoryId,
  });""")
replace(bento, """  final VoidCallback onTap;
  final bool enableVideo;

  @override""", """  final VoidCallback onTap;
  final bool enableVideo;
  final Map<String, String> sourceListingIds;
  final String? handoffCategoryId;

  @override""")
replace(bento, """                child: QuickFilterMedia(
                  sources: widget.media,
                  enableVideo: widget.enableVideo,
                ),""", """                child: QuickFilterMedia(
                  sources: widget.media,
                  enableVideo: widget.enableVideo,
                  sourceListingIds: widget.sourceListingIds,
                  handoffCategoryId: widget.handoffCategoryId,
                ),""")

replace(opener, """  final handoff = captureQuickFilterVideoForDeck(wantSound: soundOn);""", """  final handoff = captureQuickFilterVideoForDeck(
    wantSound: soundOn,
    categoryId: categoryId,
  );""")

replace(container, """import 'package:flutter_swipes/src/features/swipes/presentation/providers/chrome_reveal_provider.dart';""", """import 'package:flutter_swipes/src/features/swipes/presentation/providers/chrome_reveal_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart';""")
replace(container, """  void _ensureDeck(List<Listing> source) {
    _deck ??= List<Listing>.from(source);
  }""", """  void _ensureDeck(List<Listing> source) {
    if (_deck != null) return;
    final next = List<Listing>.from(source);
    final pendingId = SwipeDeckMediaHandoff.pendingListingId;
    final pendingCategory = SwipeDeckMediaHandoff.pendingCategoryId;
    if (pendingId != null &&
        (pendingCategory == null || pendingCategory == _categoryId)) {
      final target = next.indexWhere((listing) => listing.id == pendingId);
      if (target > 0) {
        final previewed = next.removeAt(target);
        next.insert(0, previewed);
      }
    }
    _deck = next;
  }""")

replace(stack, """import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/cap_swipe_card.dart';""", """import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_deck_media_handoff.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/cap_swipe_card.dart';""")
replace(stack, """    _horizontalController.addListener(_tickHorizontal);
    _verticalController.addListener(_tickVertical);
  }""", """    _horizontalController.addListener(_tickHorizontal);
    _verticalController.addListener(_tickVertical);
    _adoptDashboardVideoHandoff();
  }""")
replace(stack, """  bool _isVideoUrl(String value) {""", """  void _adoptDashboardVideoHandoff() {
    final handoff = SwipeDeckMediaHandoff.take();
    if (handoff == null) return;

    final listingId = handoff.listingId;
    final controller = handoff.controller;
    if (listingId == null || controller == null || !controller.value.isInitialized) {
      // Preserve legacy/non-listing handoffs for the top card's existing path.
      SwipeDeckMediaHandoff.set(handoff);
      return;
    }

    final target = widget.listings.indexWhere((listing) => listing.id == listingId);
    if (target < 0) {
      controller.dispose();
      return;
    }

    final expectedUrl = _listingPrimaryVideo(widget.listings[target])?.trim();
    if (expectedUrl == null || expectedUrl != handoff.videoUrl.trim()) {
      controller.dispose();
      return;
    }

    _cursor = target;
    _preloadedVideos[listingId] = controller;
  }

  bool _isVideoUrl(String value) {""")
