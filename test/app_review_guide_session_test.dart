import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple App Review guide is recurring across authenticated sessions', () {
    final source = File(
      'lib/src/features/dashboard/presentation/widgets/guided_tour_overlay.dart',
    ).readAsStringSync();

    expect(source, contains("'applereview@swipess.com'"));

    final reopensOnLogin = RegExp(
      r'widget\.enabled\s*&&\s*\(\s*!oldWidget\.enabled\s*\|\|\s*oldWidget\.userId\s*!=\s*widget\.userId',
      multiLine: true,
    );
    expect(
      reopensOnLogin.hasMatch(source),
      isTrue,
      reason: 'The review guide must start again when the reviewer logs in.',
    );

    final completionCheckOnlyForNormalUsers = RegExp(
      r'if\s*\(!_isAppReviewAccount\)\s*\{\s*final done\s*=\s*await GuidedTourOverlay\.hasCompleted',
      multiLine: true,
    );
    expect(
      completionCheckOnlyForNormalUsers.hasMatch(source),
      isTrue,
      reason: 'The Apple reviewer must never be blocked by a saved completed flag.',
    );

    final completionWriteOnlyForNormalUsers = RegExp(
      r'if\s*\(!_isAppReviewAccount\)\s*\{\s*await GuidedTourOverlay\.markCompleted',
      multiLine: true,
    );
    expect(
      completionWriteOnlyForNormalUsers.hasMatch(source),
      isTrue,
      reason: 'Closing the Apple review guide must not mark it permanently completed.',
    );

    expect(source, contains('OPEN TOKEN PURCHASES'));
    expect(source, contains('OPEN EVENT PURCHASE'));
  });
}
