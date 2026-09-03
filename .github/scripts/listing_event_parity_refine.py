from pathlib import Path


def replace(path, old, new, count=1):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'Missing expected block in {path}: {old[:180]!r}')
    text = text.replace(old, new, count)
    p.write_text(text)


quick = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
bento = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'

# Keep a category-specific handle to each live listing quick-filter player.
# Events already owns its exact teaser controller; this gives listings the same
# guarantee even when another partially-visible dashboard card owns audio.
replace(quick, """class _VideoPlaybackCoordinator {
  static _QuickFilterMediaState? _active;
  static double _activeVisibility = 0;
""", """class _VideoPlaybackCoordinator {
  static _QuickFilterMediaState? _active;
  static double _activeVisibility = 0;
  static final Map<String, _QuickFilterMediaState> _handoffStates =
      <String, _QuickFilterMediaState>{};

  static void registerHandoffState(_QuickFilterMediaState state) {
    final category = state.widget.handoffCategoryId;
    if (category == null || category.isEmpty) return;
    _handoffStates[category] = state;
  }

  static void unregisterHandoffState(
    _QuickFilterMediaState state, {
    String? category,
  }) {
    final key = category ?? state.widget.handoffCategoryId;
    if (key == null || !identical(_handoffStates[key], state)) return;
    _handoffStates.remove(key);
  }
""")

replace(quick, """  static SwipeDeckMediaHandoffData? captureActiveForDeck(
    bool wantSound, {
    String? categoryId,
  }) {
    final state = _active;
    if (state == null) return null;
    if (categoryId != null && state.widget.handoffCategoryId != categoryId) {
      return null;
    }
    return state._captureForDeckHandoff(wantSound);
  }
}""", """  static SwipeDeckMediaHandoffData? captureActiveForDeck(
    bool wantSound, {
    String? categoryId,
  }) {
    if (categoryId != null) {
      final targeted = _handoffStates[categoryId];
      if (targeted == null) return null;
      return targeted._captureForDeckHandoff(
        wantSound,
        requireOwnership: false,
      );
    }

    final state = _active;
    if (state == null) return null;
    return state._captureForDeckHandoff(wantSound);
  }
}""")

replace(quick, """  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reshuffle(widget.sources);
""", """  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _VideoPlaybackCoordinator.registerHandoffState(this);
    _reshuffle(widget.sources);
""")

replace(quick, """  @override
  void didUpdateWidget(covariant QuickFilterMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.sources, widget.sources) ||
        oldWidget.enableVideo != widget.enableVideo) {
""", """  @override
  void didUpdateWidget(covariant QuickFilterMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handoffCategoryId != widget.handoffCategoryId) {
      _VideoPlaybackCoordinator.unregisterHandoffState(
        this,
        category: oldWidget.handoffCategoryId,
      );
      _VideoPlaybackCoordinator.registerHandoffState(this);
    }
    if (!listEquals(oldWidget.sources, widget.sources) ||
        oldWidget.enableVideo != widget.enableVideo) {
""")

replace(quick, """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _VideoPlaybackCoordinator.release(this);
""", """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _VideoPlaybackCoordinator.unregisterHandoffState(this);
    _VideoPlaybackCoordinator.release(this);
""")

replace(quick, """  SwipeDeckMediaHandoffData? _captureForDeckHandoff(bool wantSound) {
    if (!_VideoPlaybackCoordinator.owns(this)) return null;

    final player = _video;
""", """  SwipeDeckMediaHandoffData? _captureForDeckHandoff(
    bool wantSound, {
    bool requireOwnership = true,
  }) {
    if (requireOwnership && !_VideoPlaybackCoordinator.owns(this)) return null;

    final player = _video;
""")

replace(quick, """    _detachPlayerListener(player);
    _VideoPlaybackCoordinator.release(this);
    if (_holdsBudgetSlot) {
""", """    _detachPlayerListener(player);
    if (_VideoPlaybackCoordinator.owns(this)) {
      // Transfer the exact playing movie without pausing it.
      _VideoPlaybackCoordinator.release(this);
    } else {
      // A different dashboard card may own audio. Silence it before the
      // destination route starts, but keep this targeted decoded frame intact.
      _VideoPlaybackCoordinator.pauseActive();
    }
    if (_holdsBudgetSlot) {
""")

# Do not show stock/photo media while a real listing feed is still resolving.
# Events stays on a dark surface until its video is ready; listings should too.
replace(bento, """    final previewListings = isListingVideoQuickFilter
        ? (ref.watch(swipeListingsProvider(item.id)).value ?? const <Listing>[])
        : const <Listing>[];
""", """    final previewAsync = isListingVideoQuickFilter
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
""")

replace(bento, """    final liveListingMedia = videoListings.isNotEmpty
        ? videoListings
              .map((listing) => listing.videoUrl!.trim())
              .toList(growable: false)
        : BentoMediaPools.forId(item.id);
""", """    final liveListingMedia = videoListings.isNotEmpty
        ? videoListings
              .map((listing) => listing.videoUrl!.trim())
              .toList(growable: false)
        : isListingVideoQuickFilter && !previewResolved
        ? const <String>[]
        : BentoMediaPools.forId(item.id);
""")
