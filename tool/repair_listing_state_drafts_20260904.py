from pathlib import Path
from textwrap import dedent


def must_replace(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)


# Finish later is an in-app pause, never a remote upload/publish operation.
draft = Path("lib/src/features/add/data/listing_draft_repository.dart")
draft.write_text(dedent("""\
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavedListingDraft {
  const SavedListingDraft({
    required this.id,
    required this.draftKey,
    required this.kind,
    required this.category,
    required this.step,
    required this.payload,
    required this.updatedAt,
    this.sourceListingId,
    this.photos = const [],
    this.video,
    this.documents = const [],
    this.backgroundMusic,
  });

  final String id;
  final String draftKey;
  final String kind;
  final String category;
  final int step;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
  final String? sourceListingId;
  final List<XFile> photos;
  final XFile? video;
  final List<XFile> documents;
  final XFile? backgroundMusic;
}

/// Session-local paused listing state.
///
/// "Finish later" must never create/update a listing, a draft row, or media in
/// Supabase. Keeping the original XFile objects also means a selected video is
/// still present when the user returns to the builder during this app session.
class ListingDraftRepository {
  ListingDraftRepository();

  static final Map<String, SavedListingDraft> _pausedDrafts =
      <String, SavedListingDraft>{};

  Future<SavedListingDraft?> load(String draftKey) async {
    final saved = _pausedDrafts[draftKey];
    if (saved == null) return null;
    return SavedListingDraft(
      id: saved.id,
      draftKey: saved.draftKey,
      kind: saved.kind,
      category: saved.category,
      step: saved.step,
      payload: Map<String, dynamic>.from(saved.payload),
      updatedAt: saved.updatedAt,
      sourceListingId: saved.sourceListingId,
      photos: List<XFile>.from(saved.photos),
      video: saved.video,
      documents: List<XFile>.from(saved.documents),
      backgroundMusic: saved.backgroundMusic,
    );
  }

  Future<void> save({
    required String draftKey,
    required String kind,
    required String category,
    required int step,
    required Map<String, dynamic> payload,
    String? sourceListingId,
    List<XFile> photos = const [],
    XFile? video,
    List<XFile> documents = const [],
    XFile? backgroundMusic,
  }) async {
    _pausedDrafts[draftKey] = SavedListingDraft(
      id: 'paused:$draftKey',
      draftKey: draftKey,
      kind: kind,
      category: category,
      step: step,
      payload: Map<String, dynamic>.from(payload),
      updatedAt: DateTime.now(),
      sourceListingId: sourceListingId,
      photos: List<XFile>.from(photos),
      video: video,
      documents: List<XFile>.from(documents),
      backgroundMusic: backgroundMusic,
    );
  }

  Future<void> delete(String draftKey) async {
    _pausedDrafts.remove(draftKey);
  }
}

final listingDraftRepositoryProvider = Provider<ListingDraftRepository>((ref) {
  return ListingDraftRepository();
});
"""))

# Make the UI explicit that this is a pause, not a server save.
ai = Path("lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart")
s = ai.read_text()
s = s.replace("_status = 'Saving your draft…';", "_status = 'Pausing your draft…';")
s = s.replace("_status = 'Draft saved ✓';", "_status = 'Draft paused ✓';")
s = s.replace(
    "_showMessage('Saved. You can finish this listing later.');",
    "_showMessage('Paused locally. Nothing was published or uploaded.');",
)
ai.write_text(s)

# Owner mutations must immediately invalidate public discovery surfaces.
provider = Path("lib/src/features/profile/presentation/providers/my_listings_provider.dart")
s = provider.read_text()
import_anchor = "import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';\n"
if "swipe_providers.dart" not in s:
    s = must_replace(
        s,
        import_anchor,
        import_anchor
        + "import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';\n",
        "my listings swipe provider import",
    )
s = must_replace(
    s,
    """  void _refresh() {
    _ref.invalidate(myListingsProvider);
    _ref.invalidate(ownerListingsStatsProvider);
  }
""",
    """  void _refresh() {
    _ref.invalidate(myListingsProvider);
    _ref.invalidate(ownerListingsStatsProvider);
    _ref.invalidate(quickFilterPreviewListingsProvider);
    _ref.invalidate(swipeListingsProvider);
  }
""",
    "owner listing public-surface refresh",
)
provider.write_text(s)

# Profile grid: never use video frame 0 (often black on Safari/PWA).
profile = Path("lib/src/features/profile/presentation/screens/profile_screen.dart")
s = profile.read_text()
s = s.replace("import 'package:video_player/video_player.dart';\n", "")
start = s.find("/// Instagram-style listing cover:")
end = s.find("class _EmptyGallery extends StatelessWidget", start)
if start < 0 or end < 0:
    raise SystemExit("missing profile listing preview section")
replacement = dedent("""\
/// Profile miniatures are still images by design. Use the real listing cover
/// first and the processed video poster only when no cover photo exists.
class _ListingTilePreview extends StatelessWidget {
  const _ListingTilePreview({required this.listing});

  final Listing listing;

  String? get _previewUrl {
    for (final raw in listing.images) {
      final url = raw.trim();
      if (url.isNotEmpty) return url;
    }
    final poster = listing.videoPosterUrl?.trim();
    return poster == null || poster.isEmpty ? null : poster;
  }

  @override
  Widget build(BuildContext context) {
    final image = _previewUrl;
    if (image == null) {
      return const ColoredBox(
        color: Color(0xFF20242D),
        child: Center(child: Icon(Icons.photo_outlined)),
      );
    }
    return Image.network(
      image,
      fit: BoxFit.cover,
      cacheWidth: 480,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFF20242D),
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      ),
    );
  }
}

""")
s = s[:start] + replacement + s[end:]
profile.write_text(s)

# Quick filters are projections of live listings, not decorative memory.
bento = Path("lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart")
s = bento.read_text()
s = must_replace(
    s,
    """        : listingPreviewMedia.isNotEmpty
        ? listingPreviewMedia
        : isListingPreviewQuickFilter && !previewResolved
        ? const <String>[]
        : BentoMediaPools.forId(item.id);
""",
    """        : isListingPreviewQuickFilter
        ? (previewResolved ? listingPreviewMedia : const <String>[])
        : BentoMediaPools.forId(item.id);
""",
    "authoritative listing quick-filter media",
)
s = must_replace(
    s,
    """                PropertyTeaserCard(
                  media: liveListingMedia,
""",
    """                PropertyTeaserCard(
                  key: ValueKey(
                    'property:${listingPreviewListingIds.join('|')}:${liveListingMedia.join('|')}',
                  ),
                  media: liveListingMedia,
""",
    "property teaser identity key",
)
s = must_replace(
    s,
    """                QuickFilterMedia(
                  sources: widget.media,
""",
    """                QuickFilterMedia(
                  key: ValueKey(
                    '${widget.handoffCategoryId}:${widget.sourceListingIdsByIndex.join('|')}:${widget.media.join('|')}',
                  ),
                  sources: widget.media,
""",
    "generic quick-filter identity key",
)
bento.write_text(s)
