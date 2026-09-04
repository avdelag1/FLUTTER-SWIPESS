import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/studio/data/studio_render_repository.dart';
import 'package:flutter_swipes/src/features/studio/presentation/screens/studio_composer_screen.dart';
import 'package:flutter_swipes/src/features/studio/presentation/widgets/cinematic_preview.dart';

void main() {
  test('Studio UI and render surfaces stay linkable', () {
    expect(StudioComposerScreen.new, isNotNull);
    expect(CinematicPreview.new, isNotNull);
    expect(StudioRenderRepository.new, isNotNull);
  });
}
