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
