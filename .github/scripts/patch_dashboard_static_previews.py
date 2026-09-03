from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Patch target not found: {label}")
    if text.count(old) != 1:
        raise SystemExit(f"Patch target is not unique ({text.count(old)} matches): {label}")
    return text.replace(old, new, 1)


path = Path("lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart")
text = path.read_text()

text = replace_once(
    text,
    "import 'package:flutter/material.dart';\n",
    "import 'dart:async';\nimport 'dart:math' as math;\n\nimport 'package:flutter/material.dart';\n",
    "dart timer/random imports",
)

old_media = """    const listingVideoQuickFilters = <String>{
      'property',
      'services',
      'yacht',
      'motorcycle',
      'bicycle',
    };
    final isListingVideoQuickFilter = listingVideoQuickFilters.contains(
      item.id,
    );
    final previewAsync = isListingVideoQuickFilter
        ? ref.watch(swipeListingsProvider(item.id))
        : null;
    final previewListings = previewAsync?.value ?? const <Listing>[];
    final previewResolved = previewAsync == null
        ? true
        : previewAsync.when(
            data: (_) => true,
            error: (_, __) => true,
            loading: () => false,
          );
    final seenVideoUrls = <String>{};
    final videoListings = previewListings
        .where((listing) {
          final url = listing.videoUrl?.trim();
          return url != null && url.isNotEmpty && seenVideoUrls.add(url);
        })
        .toList(growable: false);
    final liveListingMedia = videoListings.isNotEmpty
        ? videoListings
              .map((listing) => listing.videoUrl!.trim())
              .toList(growable: false)
        : isListingVideoQuickFilter && !previewResolved
        ? const <String>[]
        : BentoMediaPools.forId(item.id);
    final sourceListingIds = <String, String>{
      for (final listing in videoListings) listing.videoUrl!.trim(): listing.id,
    };
"""

new_media = """    // Events are the only dashboard quick filter that auto-plays video.
    // Every other listing category uses a portrait-cropped still preview and
    // rotates through real listings instead of running several videos at once.
    const listingPreviewQuickFilters = <String>{
      'property',
      'services',
      'yacht',
      'motorcycle',
      'bicycle',
    };
    final isListingPreviewQuickFilter = listingPreviewQuickFilters.contains(
      item.id,
    );
    final previewAsync = isListingPreviewQuickFilter
        ? ref.watch(swipeListingsProvider(item.id))
        : null;
    final previewListings = previewAsync?.value ?? const <Listing>[];
    final previewResolved = previewAsync == null
        ? true
        : previewAsync.when(
            data: (_) => true,
            error: (_, __) => true,
            loading: () => false,
          );
    final seenPreviewUrls = <String>{};
    final listingPreviewMedia = previewListings
        .map((listing) => listing.primaryImage?.trim())
        .whereType<String>()
        .where((url) => url.isNotEmpty && seenPreviewUrls.add(url))
        .toList(growable: false);
    final liveListingMedia = listingPreviewMedia.isNotEmpty
        ? listingPreviewMedia
        : isListingPreviewQuickFilter && !previewResolved
        ? const <String>[]
        : BentoMediaPools.forId(item.id);
"""
text = replace_once(text, old_media, new_media, "listing preview media pool")

old_card_call = """        _BentoCard(
          title: item.title,
          subtitle: item.subtitle,
          height: item.height,
          media: liveListingMedia,
          sourceListingIds: sourceListingIds,
          handoffCategoryId: videoListings.isNotEmpty ? item.id : null,
          stagger: Duration(seconds: int.parse(item.delaySeconds)),
          isLight: isLight,
          enableVideo: true,
          onTap: () {
"""
new_card_call = """        _BentoCard(
          title: item.title,
          subtitle: item.subtitle,
          height: item.height,
          media: liveListingMedia,
          stagger: Duration(seconds: int.parse(item.delaySeconds)),
          isLight: isLight,
          enableVideo: false,
          onTap: () {
"""
text = replace_once(text, old_card_call, new_card_call, "non-event card video disable")

old_state = """class _BentoCardState extends State<_BentoCard> {
  bool _pressed = false;

  static const _clarityMatrix = <double>[
"""
new_state = """class _BentoCardState extends State<_BentoCard> {
  bool _pressed = false;
  int _mediaIndex = 0;
  Timer? _previewTimer;
  final math.Random _previewRandom = math.Random();

  @override
  void initState() {
    super.initState();
    if (widget.media.length > 1) {
      _mediaIndex = _previewRandom.nextInt(widget.media.length);
    }
    _scheduleNextPreview();
  }

  @override
  void didUpdateWidget(covariant _BentoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.media.isEmpty) {
      _mediaIndex = 0;
    } else if (_mediaIndex >= widget.media.length) {
      _mediaIndex %= widget.media.length;
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void _scheduleNextPreview() {
    _previewTimer?.cancel();
    // A fresh 5-7 second delay per card keeps the grid feeling alive without
    // making every tile flip at the same instant.
    final delay = Duration(milliseconds: 5000 + _previewRandom.nextInt(2001));
    _previewTimer = Timer(delay, () {
      if (!mounted) return;
      final mediaCount = widget.media.length;
      if (mediaCount > 1 && TickerMode.of(context)) {
        setState(() => _mediaIndex = (_mediaIndex + 1) % mediaCount);
      }
      _scheduleNextPreview();
    });
  }

  static const _clarityMatrix = <double>[
"""
text = replace_once(text, old_state, new_state, "random 5-7 second preview timer")

old_build_head = """  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
"""
new_build_head = """  @override
  Widget build(BuildContext context) {
    final previewSources = widget.media.isEmpty
        ? const <String>[]
        : <String>[widget.media[_mediaIndex % widget.media.length]];

    return AnimatedScale(
"""
text = replace_once(text, old_build_head, new_build_head, "single rotating preview source")

old_quick_media = """                child: QuickFilterMedia(
                  sources: widget.media,
                  enableVideo: widget.enableVideo,
                  sourceListingIds: widget.sourceListingIds,
                  handoffCategoryId: widget.handoffCategoryId,
                ),
"""
new_quick_media = """                child: QuickFilterMedia(
                  sources: previewSources,
                  enableVideo: false,
                  showMute: false,
                ),
"""
text = replace_once(text, old_quick_media, new_quick_media, "static quick-filter media")

path.write_text(text)
print("Patched dashboard: events stay live; all other quick filters use portrait stills rotating every 5-7 seconds.")
