from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f'{label}: already applied')
        return text
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    return text.replace(old, new, 1)

# 1) Profile: refresh owner listings every time the profile is entered and keep
# a visible preview while network media is reloading/falling back.
profile_path = Path('lib/src/features/profile/presentation/screens/profile_screen.dart')
profile = profile_path.read_text()
profile = replace_once(
    profile,
    """    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(chromeVisibilityProvider.notifier).show();
    });""",
    """    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chromeVisibilityProvider.notifier).show();
      // A listing may have been created/edited on a replace-route tool. Force a
      // fresh owner read on every profile entry so stale cached rows cannot
      // leave the gallery looking empty or dark after returning.
      ref.invalidate(myListingsProvider('all'));
      ref.invalidate(ownerListingsStatsProvider);
    });""",
    'profile fresh-on-entry',
)

preview_pattern = re.compile(
    r"/// Profile miniatures are still images by design\..*?\nclass _ListingTilePreview extends StatelessWidget \{.*?\n\}\n\nclass _EmptyGallery",
    re.S,
)
preview_replacement = r'''/// Profile miniatures are still images by design. Keep a real visual on-screen
/// while the network cover is loading, and fall through every available photo
/// plus the video poster before giving up. Returning from Create/Edit must never
/// leave the owner's gallery as a wall of black tiles.
class _ListingTilePreview extends StatelessWidget {
  const _ListingTilePreview({required this.listing});

  final Listing listing;

  List<String> get _candidates {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in listing.images) {
      final url = raw.trim();
      if (url.isNotEmpty && seen.add(url)) out.add(url);
    }
    final poster = listing.videoPosterUrl?.trim();
    if (poster != null && poster.isNotEmpty && seen.add(poster)) {
      out.add(poster);
    }
    return out;
  }

  IconData get _fallbackIcon => switch ((listing.category ?? '').toLowerCase()) {
    'worker' || 'services' => Icons.handyman_rounded,
    'motorcycle' => Icons.two_wheeler_rounded,
    'bicycle' => Icons.pedal_bike_rounded,
    'yacht' => Icons.sailing_rounded,
    _ => Icons.home_rounded,
  };

  Widget _fallback() {
    final title = (listing.title ?? '').trim();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF485266), Color(0xFF28303D)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(_fallbackIcon, color: Colors.white70, size: 34),
          ),
          if (title.isNotEmpty)
            Positioned(
              left: 8,
              right: 8,
              bottom: 25,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _candidateAt(BuildContext context, List<String> urls, int index) {
    if (index >= urls.length) return _fallback();
    final url = urls[index];
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _candidateAt(context, urls, index + 1),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 480,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(),
      errorBuilder: (_, _, _) => _candidateAt(context, urls, index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _candidates;
    if (urls.isEmpty) return _fallback();
    return _candidateAt(context, urls, 0);
  }
}

class _EmptyGallery'''
if 'wall of black tiles' not in profile:
    profile, count = preview_pattern.subn(preview_replacement, profile, count=1)
    if count != 1:
        raise SystemExit('profile preview class marker not found')
else:
    print('profile preview fallback: already applied')
profile_path.write_text(profile)

# 2) Dashboard source selection: always prefer the processed/playback URL over
# the raw original upload. Video listings remain video-only on the dashboard;
# their photos are available after opening the listing/deck.
bento_path = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
bento = bento_path.read_text()
bento = replace_once(
    bento,
    """      final directVideo = (listing.videoOriginalUrl ?? '').trim();
      final video = directVideo.isNotEmpty
          ? directVideo
          : (listing.preferredVideoUrl ?? '').trim();""",
    """      final preferredVideo = (listing.preferredVideoUrl ?? '').trim();
      final originalVideo = (listing.videoOriginalUrl ?? '').trim();
      final video = preferredVideo.isNotEmpty ? preferredVideo : originalVideo;""",
    'dashboard processed-video first',
)
bento_path.write_text(bento)

# 3) Properties quick-filter: if a listing is a video listing, never paint its
# photo/poster underneath while the movie initializes. Show a neutral video
# loading surface, then the decoded video surface.
property_path = Path('lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart')
property_text = property_path.read_text()
property_text = replace_once(
    property_text,
    """  Widget _still(String url) {
    if (url.isEmpty) return _propertyBackdrop();""",
    """  Widget _videoLoadingBackdrop() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A202A), Color(0xFF0C0F14)],
      ),
    ),
    child: Center(
      child: Icon(Icons.play_circle_outline_rounded, color: Colors.white54, size: 42),
    ),
  );

  Widget _still(String url) {
    if (url.isEmpty) return _propertyBackdrop();""",
    'property video loading surface',
)
property_text = property_text.replace(
    "    final poster = video ? _posterForIndex(safeIndex, url) : null;\n",
    "",
    1,
)
old_property_media = """        if (video)
          Stack(
            fit: StackFit.expand,
            children: [
              if (poster != null)
                _still(poster)
              else
                _propertyBackdrop(),
              // Keep the exact initialized video surface mounted while paused
              // and playing, matching Events. Re-inserting the web platform view
              // on the Play tap can freeze Chrome/PWA on the first decoded frame.
              if (ready)
                _CoverVideo(
                  key: ValueKey('property-video:$url'),
                  controller: player,
                ),
            ],
          )
        else
          _still(url),"""
new_property_media = """        if (video)
          // Never flash a listing photo before a listing video. Keep a neutral
          // video surface until the controller has decoded the real movie.
          ready
              ? _CoverVideo(
                  key: ValueKey('property-video:$url'),
                  controller: player,
                )
              : _videoLoadingBackdrop()
        else
          _still(url),"""
property_text = replace_once(
    property_text,
    old_property_media,
    new_property_media,
    'property no-photo-before-video',
)
property_path.write_text(property_text)

# 4) Generic listing quick filters (workers, yachts, motos, bicycles): same rule.
quick_path = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
quick = quick_path.read_text()
quick = replace_once(
    quick,
    """      if (!_isKnownVideoUrl(nextUrl)) {
        precacheImage(NetworkImage(nextUrl), context);
      } else {
        final poster = _posterForVideo(nextUrl);
        if (poster != null) precacheImage(NetworkImage(poster), context);
      }""",
    """      if (!_isKnownVideoUrl(nextUrl)) {
        precacheImage(NetworkImage(nextUrl), context);
      }""",
    'quick-filter do not preload video poster',
)
quick = replace_once(
    quick,
    """  Widget _emptyCategoryBackdrop() {""",
    """  Widget _videoLoadingBackdrop() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A202A), Color(0xFF0C0F14)],
      ),
    ),
    child: Center(
      child: Icon(Icons.play_circle_outline_rounded, color: Colors.white54, size: 42),
    ),
  );

  Widget _emptyCategoryBackdrop() {""",
    'quick-filter video loading surface',
)
old_quick_video = """    if (_isKnownVideoUrl(url)) {
      final poster = _posterForVideo(url) ?? _fallbackStillUrl();
      Widget? posterWidget;
      if (poster != null) posterWidget = _buildStill(poster);

      if (!_videoEnabled) {
        return posterWidget ?? _emptyCategoryBackdrop();
      }

      final player = _video;
      if (player != null &&
          player.value.isInitialized &&
          _boundVideoUrl == url) {
        final size = player.value.size;
        if (size.width > 0 && size.height > 0) {
          final videoWidget = ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(player),
                ),
              ),
            ),
          );
          if (posterWidget != null) {
            return Stack(
              fit: StackFit.expand,
              children: [posterWidget, videoWidget],
            );
          }
          return videoWidget;
        }
      }
      return posterWidget ?? _emptyCategoryBackdrop();
    }
    return _buildStill(url);"""
new_quick_video = """    if (_isKnownVideoUrl(url)) {
      if (!_videoEnabled) return _videoLoadingBackdrop();

      final player = _video;
      if (player != null &&
          player.value.isInitialized &&
          _boundVideoUrl == url) {
        final size = player.value.size;
        if (size.width > 0 && size.height > 0) {
          return ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(player),
                ),
              ),
            ),
          );
        }
      }
      // Video listings never borrow a photo/poster while warming up.
      return _videoLoadingBackdrop();
    }
    return _buildStill(url);"""
quick = replace_once(
    quick,
    old_quick_video,
    new_quick_video,
    'generic quick-filter no-photo-before-video',
)
quick = quick.replace(
    "      // On each round only this card changes listing. Video sources stay on\n      // their static poster until the user explicitly presses Play.\n",
    "      // On each round only this card changes listing. Video sources keep the\n      // decoded movie surface first; they never flash a listing photo/poster.\n",
    1,
)
quick_path.write_text(quick)

# 5) Swipe deck: video is media #1 and photos follow it. Use the actual preferred
# playback URL so the dashboard handoff and card gallery agree on the same movie.
card_path = Path('lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart')
card = card_path.read_text()
card = replace_once(
    card,
    """  List<String> get _media {
    final out = <String>[...widget.listing.images];
    final video = widget.listing.videoUrl;
    if (video != null && video.isNotEmpty && !out.contains(video)) {
      out.insert(0, video);
    }
    return out;
  }""",
    """  List<String> get _media {
    final out = <String>[...widget.listing.images];
    final video = widget.listing.preferredVideoUrl?.trim();
    if (video != null && video.isNotEmpty && !out.contains(video)) {
      // Video is always media #1; photos follow it.
      out.insert(0, video);
    }
    return out;
  }""",
    'swipe card video first',
)
card = replace_once(
    card,
    """    final explicit = widget.listing.videoUrl?.trim();""",
    """    final explicit = widget.listing.preferredVideoUrl?.trim();""",
    'swipe card preferred video identity',
)
card_path.write_text(card)

print('Profile preview + dashboard video-first patch applied.')
