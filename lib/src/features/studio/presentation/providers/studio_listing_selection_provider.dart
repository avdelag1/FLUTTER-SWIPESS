import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';

class StudioListingSelection {
  const StudioListingSelection({
    required this.project,
    required this.photoKeys,
  });

  final StudioProject project;
  final List<String> photoKeys;

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

  void clear() => state = null;
}

final studioListingSelectionProvider =
    NotifierProvider<StudioListingSelectionNotifier, StudioListingSelection?>(
      StudioListingSelectionNotifier.new,
    );
