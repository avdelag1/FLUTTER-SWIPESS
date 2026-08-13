import 'package:flutter_swipes/src/core/routing/app_paths.dart';

/// Port of Cap `src/utils/sectionNavigation.ts`.
///
/// Back should walk **up** the app hierarchy rather than replay history, so a
/// user deep inside a section gets `sub-page → section home → dashboard → exit`
/// instead of tapping back through every screen they passed through.
///
/// Everything falls back to the dashboard, so an unmapped route can never trap
/// the user.
abstract final class SectionNavigation {
  static const dashboardRoot = AppPaths.clientDashboard;

  /// Top-level screens the user lands on after leaving the dashboard. Order does
  /// not matter — lookup picks the longest matching prefix, so
  /// `/explore/events/:id` resolves to `/explore/events` and
  /// `/client/legal-services` to itself rather than to `/client/legal`.
  static const _sectionRoots = <String>[
    AppPaths.clientDashboard,
    AppPaths.ownerDashboard,
    AppPaths.clientLikedProperties,
    AppPaths.clientWhoLikedYou,
    AppPaths.clientSavedSearches,
    AppPaths.clientServices,
    AppPaths.clientLegalServices,
    AppPaths.clientLegal,
    AppPaths.clientContracts,
    AppPaths.clientSettings,
    AppPaths.clientSecurity,
    AppPaths.clientProfile,
    AppPaths.clientFilters,
    AppPaths.clientPerks,
    AppPaths.clientAdvertise,
    AppPaths.clientMaintenance,
    AppPaths.clientCamera,
    AppPaths.clientVapId,
    AppPaths.ownerProperties,
    AppPaths.ownerListings,
    AppPaths.ownerSettings,
    AppPaths.ownerContracts,
    AppPaths.ownerFilters,
    AppPaths.ownerCamera,
    AppPaths.ownerInterestedClients,
    AppPaths.ownerLikedClients,
    AppPaths.messages,
    AppPaths.notifications,
    AppPaths.subscriptionPackages,
    AppPaths.documents,
    AppPaths.escrow,
    AppPaths.map,
    AppPaths.legal,
    AppPaths.exploreEvents,
    AppPaths.exploreRoommates,
    AppPaths.explorePrices,
    AppPaths.exploreTours,
    AppPaths.exploreIntel,
    AppPaths.exploreSeekers,
  ];

  /// Pre-auth surfaces. Back on these hands the press to the platform, which is
  /// what Cap did by never registering a handler before the dashboard.
  static const _preAuthRoots = <String>{
    AppPaths.gate,
    AppPaths.welcome,
    AppPaths.onboarding,
    AppPaths.auth,
    AppPaths.resetPassword,
  };

  static const _dashboardRoots = <String>{
    AppPaths.clientDashboard,
    AppPaths.ownerDashboard,
    AppPaths.legacyDashboard,
    '/',
  };

  static String _normalize(String path) {
    if (path.isEmpty) return '/';
    final withoutQuery = path.split('?').first;
    return withoutQuery.length > 1 && withoutQuery.endsWith('/')
        ? withoutQuery.substring(0, withoutQuery.length - 1)
        : withoutQuery;
  }

  static bool isPreAuth(String path) => _preAuthRoots.contains(_normalize(path));

  /// The section a path belongs to, or `null` when it is not under a known one.
  /// Picks the most specific (longest) matching root.
  static String? sectionRoot(String path) {
    final normalized = _normalize(path);
    String? best;
    for (final root in _sectionRoots) {
      if (normalized == root || normalized.startsWith('$root/')) {
        if (best == null || root.length > best.length) best = root;
      }
    }
    return best;
  }

  /// Where "up" leads from [path]:
  ///
  /// * dashboard root or a pre-auth screen → `null` (the caller lets the
  ///   platform handle the press, which closes the app)
  /// * a section's own home page → the dashboard
  /// * a page inside a section → that section's home page
  /// * anything unmapped → the dashboard
  static String? parentRoute(String path) {
    final normalized = _normalize(path);
    if (_dashboardRoots.contains(normalized)) return null;
    if (_preAuthRoots.contains(normalized)) return null;

    final section = sectionRoot(normalized);
    if (section == null) return dashboardRoot;
    if (normalized == section) {
      return _dashboardRoots.contains(section) ? null : dashboardRoot;
    }
    return section;
  }
}
