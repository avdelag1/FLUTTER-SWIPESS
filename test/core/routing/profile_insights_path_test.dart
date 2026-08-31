import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile insights path cannot be captured by public profile id route', () {
    expect(AppPaths.profileInsights, '/client/profile/insights');
    expect(AppPaths.profileInsights.startsWith('/profile/'), isFalse);
  });
}
