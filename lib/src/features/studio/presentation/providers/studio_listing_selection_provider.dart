import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';

class StudioListingSelection {
  const StudioListingSelection({
    required this.project,
    required this.photoKeys,
    this.uploadedImageUrls = const <String>[],
    this.renderedVideoUrl,
    this.renderedPosterUrl,
    this.renderedDurationSeconds,
  });

  final StudioProject project;
  final List<String> photoKeys;
  final List<String> uploadedImageUrls;
  final String? renderedVideoUrl;
  final String? renderedPosterUrl;
  final double? renderedDurationSeconds;

  bool get hasRenderedVideo =>
      renderedVideoUrl != null && renderedVideoUrl!.trim().isNotEmpty;

  static String photoKey(XFile file) => '${file.path}::${file.name}';

  bool matchesPhotos(List<XFile> photos) {
    final keys = photos
        .take(6)
        .map(photoKey)
        .toList(growable: false);
    if (keys.length != photoKeys.length) return false;
    for (var i = 0; i < keys.length; i++) {
      if (keys[i] != photoKeys[i]) return false;
    }
    return true;
  }

  StudioListingSelection withRendered({
    required List<String> uploadedImageUrls,
    required String videoUrl,
    String? posterUrl,
    required double durationSeconds,
  }) {
    return StudioListingSelection(
      project: project,
      photoKeys: photoKeys,
      uploadedImageUrls: List<String>.unmodifiable(uploadedImageUrls),
      renderedVideoUrl: videoUrl,
      renderedPosterUrl: posterUrl,
      renderedDurationSeconds: durationSeconds,
    );
  }
}

class StudioListingSelectionNotifier extends Notifier<StudioListingSelection?> {
  @override
  StudioListingSelection? build() => null;

  void set({required StudioProject project, required List<XFile> photos}) {
    state = StudioListingSelection(
      project: project,
      photoKeys: photos
          .take(6)
          .map(StudioListingSelection.photoKey)
          .toList(growable: false),
    );
  }

  bool setRendered({
    required List<XFile> photos,
    required List<String> uploadedImageUrls,
    required String videoUrl,
    String? posterUrl,
    required double durationSeconds,
  }) {
    final current = state;
    if (current == null || !current.matchesPhotos(photos)) return false;
    state = current.withRendered(
      uploadedImageUrls: uploadedImageUrls,
      videoUrl: videoUrl,
      posterUrl: posterUrl,
      durationSeconds: durationSeconds,
    );
    return true;
  }

  void clearRendered() {
    final current = state;
    if (current == null || !current.hasRenderedVideo) return;
    state = StudioListingSelection(
      project: current.project,
      photoKeys: current.photoKeys,
    );
  }

  void clear() => state = null;
}

final studioListingSelectionProvider =
    NotifierProvider<StudioListingSelectionNotifier, StudioListingSelection?>(
      StudioListingSelectionNotifier.new,
    );
