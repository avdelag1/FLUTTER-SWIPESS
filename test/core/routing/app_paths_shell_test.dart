import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';

void main() {
  test('signed-in profile and tool routes use shared app chrome', () {
    const routes = <String>[
      AppPaths.clientDashboard,
      AppPaths.clientProfile,
      AppPaths.profileInsights,
      AppPaths.clientSettings,
      AppPaths.clientSecurity,
      AppPaths.clientSavedSearches,
      AppPaths.clientWhoLikedYou,
      AppPaths.clientServices,
      AppPaths.clientContracts,
      AppPaths.clientLegal,
      AppPaths.clientLegalServices,
      AppPaths.clientMaintenance,
      AppPaths.clientAdvertise,
      AppPaths.clientPerks,
      AppPaths.clientVapId,
      AppPaths.clientVapIdEdit,
      AppPaths.validateId,
      AppPaths.notifications,
      AppPaths.subscriptionPackages,
      AppPaths.exploreEvents,
      AppPaths.exploreEventsLikes,
      AppPaths.exploreSeekers,
      AppPaths.explorePrices,
      AppPaths.exploreIntel,
      AppPaths.exploreTours,
      AppPaths.exploreRoommates,
      AppPaths.documents,
      AppPaths.escrow,
      AppPaths.map,
    ];

    for (final route in routes) {
      expect(
        AppPaths.isShellLocation(route),
        isTrue,
        reason: '$route must keep the shared header and dock',
      );
    }
  });

  test('signed-in nested detail routes keep shared app chrome', () {
    expect(AppPaths.isShellLocation('/listing/abc'), isTrue);
    expect(AppPaths.isShellLocation('/profile/abc'), isTrue);
    expect(AppPaths.isShellLocation('/messages/abc'), isTrue);
    expect(AppPaths.isShellLocation('/explore/events/abc'), isTrue);
    expect(AppPaths.isShellLocation('/owner/view-client/abc'), isTrue);
  });

  test('public auth and preview routes stay outside signed-in shell', () {
    expect(AppPaths.isShellLocation(AppPaths.welcome), isFalse);
    expect(AppPaths.isShellLocation(AppPaths.auth), isFalse);
    expect(AppPaths.isShellLocation('/preview/listing/abc'), isFalse);
    expect(AppPaths.isShellLocation('/preview/profile/abc'), isFalse);
  });
}
