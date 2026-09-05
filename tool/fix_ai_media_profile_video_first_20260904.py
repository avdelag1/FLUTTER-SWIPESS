from pathlib import Path
from textwrap import dedent


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)


# 1) AI listing builder: the photo browser must be large enough for real
# property uploads. Keep the grid internally scrollable, but grow it as photos
# are added so 6/12/20+ photos do not feel trapped in a tiny box.
ai_path = Path("lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart")
ai = ai_path.read_text()
ai = replace_once(
    ai,
    """  Widget _mediaSection(int photoLimit) {
    final studioSelection = ref.watch(studioListingSelectionProvider);
""",
    """  Widget _mediaSection(int photoLimit) {
    final studioSelection = ref.watch(studioListingSelectionProvider);
    final photoPanelHeight = _photos.length <= 4
        ? 320.0
        : _photos.length <= 10
        ? 430.0
        : 540.0;
""",
    "AI media section height state",
)
ai = replace_once(
    ai,
    """            Expanded(
              flex: 3,
              child: SizedBox(height: 260, child: _buildPhotoPanel()),
            ),
""",
    """            Expanded(
              flex: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: photoPanelHeight,
                child: _buildPhotoPanel(),
              ),
            ),
""",
    "AI photo panel sizing",
)
ai_path.write_text(ai)


# 2) Profile listing miniatures: never leave a listing as a dark/black tile just
# because the first network image failed or was temporarily unavailable. Try all
# listing photos in order, then the video poster. This is deliberately a still
# preview so leaving/returning from the create flow cannot strand video frame 0.
profile_path = Path("lib/src/features/profile/presentation/screens/profile_screen.dart")
profile = profile_path.read_text()
start = profile.find("/// Profile miniatures are still images by design.")
end = profile.find("class _EmptyGallery extends StatelessWidget", start)
if start < 0 or end < 0:
    raise SystemExit("missing profile preview block")
replacement = dedent("""\
/// Profile miniatures stay visible even after navigating through create/edit.
/// Try every real listing photo before falling back to the processed video
/// poster; a temporary failure of one URL must never turn the tile black.
class _ListingTilePreview extends StatefulWidget {
  const _ListingTilePreview({required this.listing});

  final Listing listing;

  @override
  State<_ListingTilePreview> createState() => _ListingTilePreviewState();
}

class _ListingTilePreviewState extends State<_ListingTilePreview> {
  int _candidateIndex = 0;

  List<String> get _candidates {
    final seen = <String>{};
    final urls = <String>[];
    for (final raw in widget.listing.images) {
      final url = raw.trim();
      if (url.isNotEmpty && seen.add(url)) urls.add(url);
    }
    final poster = widget.listing.videoPosterUrl?.trim() ?? '';
    if (poster.isNotEmpty && seen.add(poster)) urls.add(poster);
    return urls;
  }

  @override
  void didUpdateWidget(covariant _ListingTilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listing.id != widget.listing.id ||
        oldWidget.listing.images.join('|') != widget.listing.images.join('|') ||
        oldWidget.listing.videoPosterUrl != widget.listing.videoPosterUrl) {
      _candidateIndex = 0;
    }
  }

  void _tryNext(List<String> candidates) {
    if (!mounted || _candidateIndex + 1 >= candidates.length) return;
    setState(() => _candidateIndex += 1);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    if (candidates.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF20242D),
        child: Center(child: Icon(Icons.photo_outlined)),
      );
    }
    final index = _candidateIndex.clamp(0, candidates.length - 1);
    final image = candidates[index];
    return Image.network(
      image,
      key: ValueKey('profile-preview:${widget.listing.id}:$image'),
      fit: BoxFit.cover,
      cacheWidth: 480,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
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
      },
      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryNext(candidates));
        return const ColoredBox(
          color: Color(0xFF20242D),
          child: Center(child: Icon(Icons.photo_outlined)),
        );
      },
    );
  }
}

""")
profile = profile[:start] + replacement + profile[end:]
profile_path.write_text(profile)


# 3) Dashboard quick filters: video listings must be treated as video listings
# before any still-only listing, regardless of which video field is populated.
# While the player is binding, use only the processed video poster, never a
# listing photo. That removes the visible "photo first, then video" flash.
bento_path = Path("lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart")
bento = bento_path.read_text()
old_order = """    final orderedPreviewListings = <Listing>[
      ...previewListings.where(
        (listing) => (listing.videoUrl ?? '').trim().isNotEmpty,
      ),
      ...previewListings.where(
        (listing) => (listing.videoUrl ?? '').trim().isEmpty,
      ),
    ];
"""
new_order = """    bool hasDashboardVideo(Listing listing) =>
        (listing.videoOriginalUrl ?? '').trim().isNotEmpty ||
        (listing.preferredVideoUrl ?? '').trim().isNotEmpty ||
        (listing.videoUrl ?? '').trim().isNotEmpty;

    final orderedPreviewListings = <Listing>[
      ...previewListings.where(hasDashboardVideo),
      ...previewListings.where((listing) => !hasDashboardVideo(listing)),
    ];
"""
bento = replace_once(bento, old_order, new_order, "dashboard video-first ordering")
old_poster = """      listingPreviewPosterUrls.add(
        video.isNotEmpty && image.isNotEmpty ? image : null,
      );
"""
new_poster = """      final videoPoster = (listing.videoPosterUrl ?? '').trim();
      listingPreviewPosterUrls.add(
        video.isNotEmpty && videoPoster.isNotEmpty ? videoPoster : null,
      );
"""
bento = replace_once(bento, old_poster, new_poster, "dashboard index poster")
old_map = """        if (image.isNotEmpty) {
          videoPosterUrls.putIfAbsent(video, () => image);
        }
"""
new_map = """        if (videoPoster.isNotEmpty) {
          videoPosterUrls.putIfAbsent(video, () => videoPoster);
        }
"""
bento = replace_once(bento, old_map, new_map, "dashboard poster map")
bento_path.write_text(bento)
