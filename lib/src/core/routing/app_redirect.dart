import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/pending_deep_link.dart';

/// The gate/auth/alias decision behind `GoRouter.redirect`, as a pure function
/// so it can be exercised without a live Supabase session.
///
/// Returns the path to bounce to, or `null` to let [location] render.
abstract final class AppRedirect {
  /// Reachable without passing the access gate, so shared links and the
  /// password-recovery mail work for someone who does not have an account yet.
  static const publicExact = <String>{
    AppPaths.resetPassword,
    AppPaths.paymentSuccess,
    AppPaths.paymentCancel,
    AppPaths.about,
    AppPaths.contact,
    AppPaths.faqClient,
    AppPaths.faqOwner,
    AppPaths.legal,
  };

  static const publicPrefixes = <String>[
    '/preview/listing/',
    '/preview/profile/',
    '/u/',
    '/vap-validate/',
    '/s/',
  ];

  static const _authScreens = <String>{
    AppPaths.welcome,
    AppPaths.onboarding,
    AppPaths.auth,
  };

  static bool isPublic(String location) =>
      publicExact.contains(location) ||
      publicPrefixes.any(location.startsWith);

  /// [location] is the matched path; [uri] is the full incoming location
  /// including any query, which is what gets queued as a pending deep link.
  static String? resolve({
    required String location,
    required String uri,
    required bool grantLoading,
    required bool granted,
    required bool signedIn,
    required PendingDeepLink pending,
  }) {
    // While grant status is still loading, don't bounce the user.
    if (grantLoading) return null;

    if (isPublic(location)) return null;

    if (!granted && location != AppPaths.gate) {
      pending.remember(uri);
      return AppPaths.gate;
    }

    if (granted && !signedIn) {
      if (location == AppPaths.gate) return AppPaths.welcome;
      if (_authScreens.contains(location)) return null;
      pending.remember(uri);
      return AppPaths.welcome;
    }

    if (signedIn &&
        (location == AppPaths.gate || _authScreens.contains(location))) {
      // A share link followed before signing in wins over the default landing
      // spot; `take` clears it so it only resumes once.
      return pending.take() ?? AppPaths.clientDashboard;
    }

    return _capacitorAlias(location);
  }

  /// Paths the Capacitor app served that have a different home in Flutter.
  static String? _capacitorAlias(String location) {
    switch (location) {
      case '/':
        return AppPaths.gate;
      case AppPaths.legacyDashboard:
      case AppPaths.ownerDashboard:
        return AppPaths.clientDashboard;
      case AppPaths.ownerProfile:
        return AppPaths.clientProfile;
      case AppPaths.exploreServices:
        return AppPaths.clientServices;
      case '/promote-event/request':
      case '/promote-event/packages':
      case '/promote':
        return AppPaths.clientAdvertise;
      case '/privacy-policy':
        return '${AppPaths.legal}?doc=privacy';
      case '/terms-of-service':
        return '${AppPaths.legal}?doc=terms';
      case '/agl':
        return '${AppPaths.legal}?doc=agl';
      case '/share-target':
        return AppPaths.clientDashboard;
      default:
        return null;
    }
  }
}
