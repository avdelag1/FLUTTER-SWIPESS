import 'package:flutter_swipes/src/core/routing/app_navigation_history.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previousDistinctFrom skips stacked copies of the same tool', () {
    AppNavigationHistory.record(AppPaths.clientDashboard);
    AppNavigationHistory.record(AppPaths.clientProfile);
    AppNavigationHistory.record(AppPaths.ownerListingsNew);
    AppNavigationHistory.record(AppPaths.ownerListingsNew);

    expect(
      AppNavigationHistory.previousDistinctFrom(AppPaths.ownerListingsNew),
      AppPaths.clientProfile,
    );
  });
}
