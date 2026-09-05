from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f'{label}: already applied')
        return text
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    return text.replace(old, new, 1)

# PROFILE ---------------------------------------------------------------------
p = Path('lib/src/features/profile/presentation/screens/profile_screen.dart')
s = p.read_text()
s = replace_once(
    s,
    """    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(chromeVisibilityProvider.notifier).show();
    });""",
    """    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chromeVisibilityProvider.notifier).show();
      // Create/Edit use replace-style routes, so the provider can otherwise
      // keep an older in-memory snapshot when the owner returns to Profile.
      ref.invalidate(myListingsProvider('all'));
      ref.invalidate(ownerListingsStatsProvider);
    });""",
    'profile refresh on entry',
)

fallback_method = """  Widget _visibleFallback() {
    final category = (widget.listing.category ?? '').toLowerCase();
    final icon = switch (category) {
      'worker' || 'services' => Icons.handyman_rounded,
      'motorcycle' => Icons.two_wheeler_rounded,
      'bicycle' => Icons.pedal_bike_rounded,
      'yacht' => Icons.sailing_rounded,
      _ => Icons.home_rounded,
    };
    final title = (widget.listing.title ?? '').trim();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF566174), Color(0xFF303949)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: Icon(icon, color: Colors.white70, size: 34)),
          if (title.isNotEmpty)
            Positioned(
              left: 7,
              right: 7,
              bottom: 24,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

"""
if '_visibleFallback()' not in s:
    marker = """  void _tryNext(List<String> candidates) {
    if (!mounted || _candidateIndex + 1 >= candidates.length) return;
    setState(() => _candidateIndex += 1);
  }

"""
    if marker not in s:
        raise SystemExit('profile fallback insertion marker not found')
    s = s.replace(marker, marker + fallback_method, 1)

s = s.replace(
    """    if (candidates.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF20242D),
        child: Center(child: Icon(Icons.photo_outlined)),
      );
    }""",
    """    if (candidates.isEmpty) return _visibleFallback();""",
    1,
)
s = s.replace(
    """      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFF20242D),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },""",
    """      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        // Keep a recognizable listing tile visible while the real cover is
        // loading instead of flashing a black/dark rectangle.
        return _visibleFallback();
      },""",
    1,
)
s = s.replace(
    """      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryNext(candidates));
        return const ColoredBox(
          color: Color(0xFF20242D),
          child: Center(child: Icon(Icons.photo_outlined)),
        );
      },""",
    """      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryNext(candidates));
        return _visibleFallback();
      },""",
    1,
)
p.write_text(s)

# DASHBOARD MEDIA ORDER --------------------------------------------------------
p = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
s = p.read_text()
s = replace_once(
    s,
    """      final directVideo = (listing.videoOriginalUrl ?? '').trim();
      final video = directVideo.isNotEmpty
          ? directVideo
          : (listing.preferredVideoUrl ?? '').trim();""",
    """      final preferredVideo = (listing.preferredVideoUrl ?? '').trim();
      final originalVideo = (listing.videoOriginalUrl ?? '').trim();
      // Processed/playback media wins. The raw upload is recovery-only.
      final video = preferredVideo.isNotEmpty ? preferredVideo : originalVideo;""",
    'dashboard processed video first',
)
p.write_text(s)

# PROPERTY QUICK FILTER --------------------------------------------------------
p = Path('lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart')
s = p.read_text()
if '_videoLoadingBackdrop()' not in s:
    s = replace_once(
        s,
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
s = s.replace("    final poster = video ? _posterForIndex(safeIndex, url) : null;\n", "", 1)
old = """        if (video)
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
new = """        if (video)
          // A video listing never flashes its photo/poster first.
          ready
              ? _CoverVideo(
                  key: ValueKey('property-video:$url'),
                  controller: player,
                )
              : _videoLoadingBackdrop()
        else
          _still(url),"""
s = replace_once(s, old, new, 'property video surface first')
p.write_text(s)

# GENERIC QUICK FILTERS --------------------------------------------------------
p = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
s = p.read_text()
s = s.replace(
    """      if (!_isKnownVideoUrl(nextUrl)) {
        precacheImage(NetworkImage(nextUrl), context);
      } else {
        final poster = _posterForVideo(nextUrl);
        if (poster != null) precacheImage(NetworkImage(poster), context);
      }""",
    """      if (!_isKnownVideoUrl(nextUrl)) {
        precacheImage(NetworkImage(nextUrl), context);
      }""",
    1,
)
if '_videoLoadingBackdrop()' not in s:
    s = replace_once(
        s,
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
        'generic video loading surface',
    )
old = """    if (_isKnownVideoUrl(url)) {
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
new = """    if (_isKnownVideoUrl(url)) {
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
      // Never substitute a listing photo/poster while a video is warming.
      return _videoLoadingBackdrop();
    }
    return _buildStill(url);"""
s = replace_once(s, old, new, 'generic video surface first')
s = s.replace(
    "      // On each round only this card changes listing. Video sources stay on\n      // their static poster until the user explicitly presses Play.\n",
    "      // On each round only this card changes listing. Video sources keep the\n      // decoded movie surface first and never flash a listing photo/poster.\n",
    1,
)
p.write_text(s)

# SWIPE CARD ------------------------------------------------------------------
p = Path('lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart')
s = p.read_text()
s = replace_once(
    s,
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
      // Video is media #1. Photos follow only after the movie.
      out.insert(0, video);
    }
    return out;
  }""",
    'swipe deck video first',
)
s = replace_once(
    s,
    "    final explicit = widget.listing.videoUrl?.trim();",
    "    final explicit = widget.listing.preferredVideoUrl?.trim();",
    'swipe deck preferred video identity',
)
p.write_text(s)

print('Final profile visibility + video-first patch applied.')
