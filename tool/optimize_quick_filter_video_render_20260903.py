from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing expected block: {label}')
    return text.replace(old, new, 1)


# 1) Move the world map control next to the burger on the top-right.
path = Path('lib/src/core/widgets/app_top_bar.dart')
text = path.read_text()
left_map = """              SizedBox(width: chromeGap),
              _HudButton(
                key: const ValueKey('header-map'),
                semanticLabel: 'Open world map',
                onTap: () {
                  AppHaptics.medium();
                  ref.read(overlayModalsProvider.notifier).openPassportMap();
                },
                child: const _AnimatedWorldIcon(),
              ),
"""
text = replace_once(text, left_map, '', 'remove map from profile group')
menu_anchor = """        PopupMenuButton<String>(
          key: const ValueKey('header-menu'),
"""
right_map = """        _HudButton(
          key: const ValueKey('header-map'),
          semanticLabel: 'Open world map',
          onTap: () {
            AppHaptics.medium();
            ref.read(overlayModalsProvider.notifier).openPassportMap();
          },
          child: const _AnimatedWorldIcon(),
        ),
        SizedBox(width: chromeGap),
        PopupMenuButton<String>(
          key: const ValueKey('header-menu'),
"""
text = replace_once(text, menu_anchor, right_map, 'place map beside menu')
path.write_text(text)


# 2) Do not shader-filter live quick-filter media. ColorFiltered around a web
# HtmlElementView forces extra compositing and can visibly drop frames.
path = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
text = path.read_text()
clarity = re.compile(
    r"\n  static const _clarityMatrix = <double>\[.*?\n  \];\n",
    re.S,
)
text, count = clarity.subn('\n', text, count=1)
if count != 1:
    raise SystemExit('missing clarity matrix')
old_media = """              ColorFiltered(
                colorFilter: const ColorFilter.matrix(_clarityMatrix),
                child: QuickFilterMedia(
                  sources: widget.media,
                  rotateSlot: widget.rotateSlot,
                  slotCount: widget.slotCount,
                  enableVideo: widget.enableVideo,
                  showMute: widget.enableVideo,
                  sourceListingIds: widget.sourceListingIds,
                  sourceImageListingIds: widget.sourceImageListingIds,
                  videoPosterUrls: widget.videoPosterUrls,
                  handoffCategoryId: widget.handoffCategoryId,
                  onOpen: widget.onTap,
                ),
              ),
"""
new_media = """              QuickFilterMedia(
                sources: widget.media,
                rotateSlot: widget.rotateSlot,
                slotCount: widget.slotCount,
                enableVideo: widget.enableVideo,
                showMute: widget.enableVideo,
                sourceListingIds: widget.sourceListingIds,
                sourceImageListingIds: widget.sourceImageListingIds,
                videoPosterUrls: widget.videoPosterUrls,
                handoffCategoryId: widget.handoffCategoryId,
                onOpen: widget.onTap,
              ),
"""
text = replace_once(text, old_media, new_media, 'remove ColorFiltered from media')
path.write_text(text)


# 3) Make the PWA media surface cheaper while preserving reliable video taps.
path = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = path.read_text()
text = replace_once(
    text,
    '  static int get maxActive => kIsWeb ? 2 : 3;\n',
    """  static int get maxActive {
    if (!kIsWeb) return 3;
    // Mobile PWAs are far more sensitive to decoder/texture pressure than
    // desktop browsers. Keep only one listing decoder warm there; desktop web
    // can keep two. A manual Play still evicts an idle preview immediately.
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return 1;
    }
    return 2;
  }
""",
    'adaptive web decoder budget',
)
text = replace_once(
    text,
    '  double get _previewWarmupThreshold => kIsWeb ? 0.06 : 0.05;\n',
    """  double get _previewWarmupThreshold {
    if (!kIsWeb) return 0.05;
    // Do not let barely-visible mobile PWA cards start buffering 1080p media.
    // Warm only a clearly visible card; desktop web has more headroom.
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return 0.30;
    }
    return 0.10;
  }
""",
    'adaptive preview warmup threshold',
)
text = replace_once(
    text,
    '  bool _previewWarmupScheduled = false;\n',
    '  bool _previewWarmupScheduled = false;\n  bool _webPointerShieldHold = false;\n',
    'web pointer shield hold state',
)
text = replace_once(
    text,
    '    _index = 0;\n  }\n\n  void _togglePlayPause()',
    '    _index = 0;\n    _webPointerShieldHold = false;\n  }\n\n  void _togglePlayPause()',
    'reset pointer shield on source refresh',
)
text = replace_once(
    text,
    '              duration: Duration(milliseconds: kIsWeb ? 55 : 70),\n',
    '              duration: kIsWeb ? Duration.zero : const Duration(milliseconds: 70),\n',
    'remove web media crossfade',
)
text = replace_once(
    text,
    '            intercepting: kIsWeb,\n',
    """            intercepting:
                kIsWeb && (_isKnownVideoUrl(current) || _webPointerShieldHold),
""",
    'only create web hit shield for video transition',
)
build_visibility = """    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleVisibilityCheck(),
    );

"""
text = replace_once(text, build_visibility, '', 'remove redundant build visibility callback')
advance_re = re.compile(
    r"  void _advance\(int delta\) \{.*?\n  \}\n\n  Future<void> _syncVideo",
    re.S,
)
new_advance = """  void _advance(int delta) {
    final sources = _sources;
    if (sources.length <= 1 || !mounted || !_routeActive) return;

    final previousIndex = _index % sources.length;
    var nextIndex = (previousIndex + delta) % sources.length;
    if (nextIndex < 0) nextIndex += sources.length;
    final previousUrl = sources[previousIndex];
    final nextUrl = sources[nextIndex];
    final holdWebShield =
        kIsWeb && (_isKnownVideoUrl(previousUrl) || _isKnownVideoUrl(nextUrl));

    setState(() {
      _index = nextIndex;
      _userPaused = true;
      _manualPlaybackStarted = false;
      _reportedVideoTurnComplete = false;
      if (holdWebShield) _webPointerShieldHold = true;
    });
    _disposeVideo();

    // Keep the web pointer interceptor alive just long enough for an outgoing
    // HtmlElementView to disappear, then remove that platform-view layer from
    // photo cards. This preserves reliable PWA taps without paying the cost of
    // an interceptor on every quick-filter card all the time.
    if (kIsWeb && !_isKnownVideoUrl(nextUrl) && _webPointerShieldHold) {
      Future<void>.delayed(const Duration(milliseconds: 140), () {
        if (!mounted || !_routeActive || _sources.isEmpty) return;
        final current = _sources[_index % _sources.length];
        if (_isKnownVideoUrl(current) || !_webPointerShieldHold) return;
        setState(() => _webPointerShieldHold = false);
      });
    }

    // Re-evaluate immediately after a manual edge tap. If the newly selected
    // item is a video, start its paused initialization on the next frame rather
    // than waiting for another scroll/visibility event to happen by chance.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_routeActive) return;
      _scheduleVisibilityCheck();
      if (_visibleFraction >= _previewWarmupThreshold) {
        _schedulePreviewWarmup();
      }
    });
  }

  Future<void> _syncVideo"""
text, count = advance_re.subn(new_advance, text, count=1)
if count != 1:
    raise SystemExit('missing _advance function')
path.write_text(text)


# 4) Future browser/PWA uploads should be a delivery rendition, not a 7.5 Mbps
# full-HD master. 720x1280 @ 4.8 Mbps remains crisp on phones and is much easier
# for mobile browsers to buffer/decode smoothly. Native exports remain full-HD.
path = Path('lib/src/features/camera/data/video_recut_v3_html.dart')
text = path.read_text()
old_canvas = """      // Match the native full-HD portrait delivery export. H.264/WebM at
      // 1080x1920 remains hardware-decodable while looking as sharp as Events.
      canvasWidth = 1080;
      canvasHeight = 1920;
"""
new_canvas = """      // Browser/PWA uploads use a mobile delivery rendition. 720x1280 is
      // still crisp on phone displays while cutting pixel decode work by more
      // than half versus 1080x1920, which matters on quick-filter feeds.
      canvasWidth = 720;
      canvasHeight = 1280;
"""
text = replace_once(text, old_canvas, new_canvas, 'web portrait delivery size')
text = replace_once(
    text,
    "            'videoBitsPerSecond': 7500000,\n",
    "            'videoBitsPerSecond': 4800000,\n",
    'web delivery bitrate',
)
path.write_text(text)

print('quick-filter render optimization patch applied')
