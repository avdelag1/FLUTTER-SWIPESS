import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';

/// Holds a deep link that arrived while the app was still gated or signed out
/// so the user lands on it once they get in, instead of on the dashboard.
///
/// Shared listing, profile and event links are handed out publicly, so most of
/// them reach someone who has to pass the access gate and sign in first.
/// Dropping the target on the floor at that point is what makes a link feel
/// like it "did nothing".
///
/// Deliberately mutable state behind a plain [Provider] rather than a
/// [Notifier]: the router writes to this from inside `redirect`, and a
/// reactive write there would re-fire the router's refresh listener and loop.
class PendingDeepLink {
  String? _location;

  String? get peek => _location;

  void remember(String location) {
    if (!isResumable(location)) return;
    _location = location;
  }

  /// Reads and clears in one step so a link is only ever resumed once.
  String? take() {
    final value = _location;
    _location = null;
    return value;
  }

  void clear() => _location = null;

  /// The gate and auth screens are what we bounce *to*, so resuming onto one
  /// would loop. The dashboard is already the default landing spot.
  static bool isResumable(String location) {
    const skip = <String>{
      '/',
      AppPaths.gate,
      AppPaths.welcome,
      AppPaths.onboarding,
      AppPaths.auth,
      AppPaths.resetPassword,
      AppPaths.clientDashboard,
      AppPaths.legacyDashboard,
    };
    final path = Uri.parse(location).path;
    return path.isNotEmpty && !skip.contains(path);
  }
}

final pendingDeepLinkProvider =
    Provider<PendingDeepLink>((ref) => PendingDeepLink());
