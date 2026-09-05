import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Studio explicitly defaults every unset photo to portrait', () {
    final source = File(
      'lib/src/features/studio/presentation/screens/studio_composer_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('i: initial?.photoFits[i] ?? StudioPhotoFit.portrait'),
    );
    expect(source, contains('void _setAllPhotosPortrait()'));
    expect(source, contains("'PORTRAIT ALL'"));
  });
}
