import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/admin/presentation/screens/admin_category_photos_screen.dart';
import 'package:flutter_swipes/src/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/admin/presentation/screens/admin_eventos_screen.dart';
import 'package:flutter_swipes/src/features/admin/presentation/screens/admin_performance_screen.dart';
import 'package:flutter_swipes/src/features/admin/presentation/screens/admin_photos_screen.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/app_redirect.dart';
import 'package:flutter_swipes/src/core/routing/pending_deep_link.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/app_splash_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/legendary_onboarding_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/not_found_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/business/presentation/screens/partner_business_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/profile_camera_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/business_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/escrow/presentation/screens/escrow_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_detail_route_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_favorites_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/local_intel_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/price_tracker_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contracts_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/faq_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/lawyer_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/lawyer_services_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/legal_admin_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/legal_hub_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/likes_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/owner_interested_clients_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/who_liked_you_screen.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/live_map_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/messages_screen.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/payment_result_screen.dart';
import 'package:flutter_swipes/src/features/preview/presentation/screens/public_listing_preview_screen.dart';
import 'package:flutter_swipes/src/features/preview/presentation/screens/public_profile_preview_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/about_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/advertise_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/contact_support_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/maintenance_requests_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/owner_filters_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/owner_properties_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/perks_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/saved_searches_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/security_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/settings_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/vap_id_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/vap_validate_screen.dart';
import 'package:flutter_swipes/src/features/roommates/presentation/screens/roommate_matching_screen.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/screens/seekers_screen.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/screens/worker_discovery_screen.dart';
import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/profile_insights/presentation/screens/profile_insights_screen.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/subscription_packages_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/safe_listing_detail_route.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';
import 'package:flutter_swipes/src/features/video_tours/presentation/screens/video_tours_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppPaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final grantedAsync = ref.read(accessGrantedProvider);
      final signedIn = ref.read(currentUserProvider) != null;
      final baseRedirect = AppRedirect.resolve(
        location: state.matchedLocation,
        uri: state.uri.toString(),
        grantLoading: grantedAsync.isLoading,
        granted: grantedAsync.value ?? false,
        signedIn: signedIn,
        pending: ref.read(pendingDeepLinkProvider),
      );
      if (baseRedirect != null) return baseRedirect;

      final location = state.matchedLocation;
      if (signedIn) {
        final sessionAsync = ref.read(appSessionProvider);
        final session = sessionAsync.value;

        // Privileged workspaces fail closed. While the authenticated session
        // contract is still loading, let the role screen render its loading
        // state instead of bouncing a legitimate staff member away.
        if (!sessionAsync.isLoading) {
          if (_isGeneralAdminLocation(location) &&
              session?.canUseAdminPortal != true) {
            return AppPaths.clientDashboard;
          }
          if (location == AppPaths.legalAdminDashboard &&
              session?.canUseLegalAdmin != true) {
            return AppPaths.clientDashboard;
          }
          if (location == AppPaths.businessDashboard &&
              session?.businessActive != true) {
            return AppPaths.clientDashboard;
          }
          if (location == AppPaths.lawyerDashboard &&
              session?.lawyerActive != true) {
            return AppPaths.clientDashboard;
          }
        }

        final market = ref.read(appMarketProvider).value;
        if (market != null) {
          final feature = _marketFeatureForLocation(location);
          if (feature != null &&
              (!market.effectiveOpen || !market.featureEnabled(feature))) {
            return AppPaths.clientDashboard;
          }
        }
      }

      if (signedIn && location != AppPaths.subscriptionPackages) {
        final subscription = ref.read(subscriptionProvider).value;
        if (subscription != null) {
          final tier = subscription.effectiveTier;
          if (_isPaidEventsLocation(location) && !tier.canViewEvents) {
            return AppPaths.subscriptionPackages;
          }
          if (_isPaidLegalLocation(location) && !tier.canUseLegal) {
            return AppPaths.subscriptionPackages;
          }
          if ((location == AppPaths.clientVapId ||
                  location == AppPaths.clientVapIdEdit) &&
              !tier.canUseVirtualCard) {
            return AppPaths.subscriptionPackages;
          }
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppPaths.splash,
        builder: (ctx, _) => const AppSplashScreen(),
      ),
      GoRoute(
        path: AppPaths.gate,
        builder: (ctx, _) => const AccessCodeGateScreen(),
      ),
      GoRoute(
        path: AppPaths.welcome,
        builder: (ctx, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppPaths.onboarding,
        builder: (ctx, _) =>
            LegendaryOnboardingScreen(onFinish: () => ctx.go(AppPaths.welcome)),
      ),
      GoRoute(
        path: AppPaths.auth,
        builder: (ctx, state) {
          final q = state.uri.queryParameters['mode'];
          final intent = ref.read(authIntentProvider);
          final mode = q == 'signup' || q == 'login'
              ? q!
              : (intent == AuthIntent.signup ? 'signup' : 'login');
          return AuthScreen(mode: mode);
        },
      ),
      GoRoute(
        path: AppPaths.resetPassword,
        builder: (ctx, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/preview/listing/:id',
        builder: (ctx, state) =>
            PublicListingPreviewScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/preview/profile/:id',
        builder: (ctx, state) =>
            PublicProfilePreviewScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/u/:id',
        redirect: (ctx, state) =>
            AppPaths.previewProfile(state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/s/listing/:id',
        redirect: (ctx, state) =>
            AppPaths.previewListing(state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/s/profile/:id',
        redirect: (ctx, state) =>
            AppPaths.previewProfile(state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/s/event/:id',
        redirect: (ctx, state) =>
            AppPaths.exploreEvent(state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppPaths.paymentSuccess,
        builder: (ctx, _) => const PaymentResultScreen(success: true),
      ),
      GoRoute(
        path: AppPaths.paymentCancel,
        builder: (ctx, _) => const PaymentResultScreen(success: false),
      ),
      GoRoute(path: AppPaths.about, builder: (ctx, _) => const AboutScreen()),
      GoRoute(
        path: AppPaths.contact,
        builder: (ctx, _) => const ContactSupportScreen(),
      ),
      GoRoute(
        path: AppPaths.faqClient,
        builder: (ctx, _) => const FAQScreen(audience: 'client'),
      ),
      GoRoute(
        path: AppPaths.faqOwner,
        builder: (ctx, _) => const FAQScreen(audience: 'owner'),
      ),
      GoRoute(
        path: AppPaths.legal,
        builder: (ctx, _) => const LegalHubScreen(),
      ),
      GoRoute(
        path: '/vap-validate/:id',
        builder: (ctx, state) =>
            VapValidateScreen(userId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppPaths.clientVapIdEdit,
        builder: (ctx, _) => const VapIdScreen(initialEdit: true),
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (ctx, state) => SafeListingDetailRoute(
          listingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (ctx, state) =>
            ProfileDetailScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/event',
        redirect: (ctx, state) {
          final extra = state.extra;
          if (extra is String) return AppPaths.exploreEvent(extra);
          try {
            final id = (extra as dynamic).id as String?;
            if (id != null) return AppPaths.exploreEvent(id);
          } catch (_) {}
          return AppPaths.exploreEvents;
        },
      ),

      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: AppPaths.legacyDashboard,
            redirect: (ctx, state) => AppPaths.clientDashboard,
          ),
          GoRoute(
            path: AppPaths.clientDashboard,
            builder: (ctx, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppPaths.clientLikedProperties,
            builder: (ctx, _) => const LikesScreen(),
          ),
          GoRoute(
            path: AppPaths.messages,
            builder: (ctx, _) => const MessagesScreen(),
          ),
          GoRoute(
            path: AppPaths.exploreEvents,
            builder: (ctx, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppPaths.exploreSeekers,
            builder: (ctx, _) => const SeekersScreen(),
          ),
          GoRoute(
            path: AppPaths.clientLegal,
            builder: (ctx, _) => const LegalHubScreen(),
          ),
          GoRoute(
            path: AppPaths.clientLegalServices,
            builder: (ctx, _) => const LawyerServicesScreen(),
          ),
          GoRoute(
            path: AppPaths.clientVapId,
            builder: (ctx, _) => const VapIdScreen(),
          ),
          GoRoute(
            path: AppPaths.clientProfile,
            builder: (ctx, _) => const ProfileScreen(),
          ),
        ],
      ),

      GoRoute(
        path: AppPaths.ownerDashboard,
        builder: (ctx, _) => const BusinessDashboardScreen(),
      ),
      GoRoute(
        path: AppPaths.businessDashboard,
        builder: (ctx, _) => const PartnerBusinessDashboardScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerProfile,
        builder: (ctx, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppPaths.clientSettings,
        builder: (ctx, _) => const SettingsScreen(audience: 'client'),
      ),
      GoRoute(
        path: AppPaths.ownerSettings,
        builder: (ctx, _) => const SettingsScreen(audience: 'owner'),
      ),
      GoRoute(
        path: AppPaths.clientWhoLikedYou,
        builder: (ctx, _) => const WhoLikedYouScreen(),
      ),
      GoRoute(
        path: AppPaths.clientSavedSearches,
        builder: (ctx, _) => const SavedSearchesScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerSavedSearches,
        builder: (ctx, _) => const SavedSearchesScreen(),
      ),
      GoRoute(
        path: AppPaths.clientSecurity,
        builder: (ctx, _) => const SecurityScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerSecurity,
        builder: (ctx, _) => const SecurityScreen(),
      ),
      GoRoute(
        path: AppPaths.clientServices,
        builder: (ctx, _) => const WorkerDiscoveryScreen(),
      ),
      GoRoute(
        path: AppPaths.clientContracts,
        builder: (ctx, _) => const ContractsScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerContracts,
        redirect: (ctx, state) => AppPaths.clientContracts,
      ),
      GoRoute(
        path: AppPaths.legalServices,
        builder: (ctx, _) => const LawyerServicesScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerLegalServices,
        builder: (ctx, _) => const LawyerServicesScreen(),
      ),
      GoRoute(
        path: AppPaths.clientCamera,
        builder: (ctx, _) => const ProfileCameraScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerCamera,
        builder: (ctx, _) => const ProfileCameraScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerCameraListing,
        builder: (ctx, _) => const ListingCameraScreen(),
      ),
      GoRoute(
        path: AppPaths.clientFilters,
        builder: (ctx, _) => const FilterBottomSheet(asPage: true),
      ),
      GoRoute(
        path: AppPaths.ownerFilters,
        builder: (ctx, _) => const OwnerFiltersScreen(),
      ),
      GoRoute(
        path: AppPaths.clientMaintenance,
        builder: (ctx, _) => const MaintenanceRequestsScreen(),
      ),
      GoRoute(
        path: AppPaths.clientAdvertise,
        builder: (ctx, _) => const AdvertiseScreen(),
      ),
      GoRoute(
        path: AppPaths.clientPerks,
        builder: (ctx, _) => const PerksScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerProperties,
        builder: (ctx, _) => const OwnerPropertiesScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerListings,
        builder: (ctx, _) => const OwnerPropertiesScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerListingsNew,
        builder: (ctx, _) => const AddListingScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerLikedClients,
        builder: (ctx, _) => const LikesScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerInterestedClients,
        builder: (ctx, _) => const OwnerInterestedClientsScreen(),
      ),
      GoRoute(
        path: '/owner/view-client/:clientId',
        builder: (ctx, state) =>
            ProfileDetailScreen(userId: state.pathParameters['clientId']!),
      ),
      GoRoute(
        path: AppPaths.notifications,
        builder: (ctx, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppPaths.subscriptionPackages,
        builder: (ctx, _) => const SubscriptionPackagesScreen(),
      ),
      GoRoute(
        path: AppPaths.profileInsights,
        builder: (ctx, _) => const ProfileInsightsScreen(),
      ),
      GoRoute(
        path: AppPaths.exploreEventsLikes,
        builder: (ctx, _) => const EventFavoritesScreen(),
      ),
      GoRoute(
        path: '/explore/events/:id',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          child: EventDetailRouteScreen(eventId: state.pathParameters['id']!),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppPaths.explorePrices,
        builder: (ctx, _) => const PriceTrackerScreen(),
      ),
      GoRoute(
        path: AppPaths.exploreTours,
        builder: (ctx, _) => const VideoToursScreen(),
      ),
      GoRoute(
        path: AppPaths.exploreIntel,
        builder: (ctx, _) => const LocalIntelScreen(),
      ),
      GoRoute(
        path: AppPaths.exploreRoommates,
        builder: (ctx, _) => const RoommateMatchingScreen(),
      ),
      GoRoute(
        path: AppPaths.documents,
        builder: (ctx, _) => const DocumentVaultScreen(),
      ),
      GoRoute(
        path: AppPaths.escrow,
        builder: (ctx, _) => const EscrowDashboardScreen(),
      ),
      GoRoute(path: AppPaths.map, builder: (ctx, _) => const LiveMapScreen()),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (ctx, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: AppPaths.adminDashboard,
        builder: (ctx, _) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppPaths.legalAdminDashboard,
        builder: (ctx, _) => const LegalAdminDashboardScreen(),
      ),
      GoRoute(
        path: AppPaths.lawyerDashboard,
        builder: (ctx, _) => const LawyerDashboardScreen(),
      ),
      GoRoute(
        path: AppPaths.adminEventos,
        builder: (ctx, _) => const AdminEventosScreen(),
      ),
      GoRoute(
        path: AppPaths.adminPhotos,
        builder: (ctx, _) => const AdminPhotosScreen(),
      ),
      GoRoute(
        path: AppPaths.adminCategoryPhotos,
        builder: (ctx, _) => const AdminCategoryPhotosScreen(),
      ),
      GoRoute(
        path: AppPaths.adminPerformance,
        builder: (ctx, _) => const AdminPerformanceScreen(),
      ),
      GoRoute(
        path: '*',
        builder: (ctx, state) => NotFoundScreen(path: state.uri.toString()),
      ),
    ],
  );

  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
    if (next.value?.event == AuthChangeEvent.passwordRecovery) {
      router.go(AppPaths.resetPassword);
    }
  });
  ref.listen(subscriptionProvider, (_, _) => router.refresh());
  ref.listen(appSessionProvider, (_, _) => router.refresh());
  ref.listen(appMarketProvider, (_, _) => router.refresh());

  return router;
});

bool _isPaidEventsLocation(String location) =>
    location == AppPaths.exploreEvents ||
    location == AppPaths.exploreEventsLikes ||
    location.startsWith('${AppPaths.exploreEvents}/');

bool _isPaidLegalLocation(String location) =>
    location == AppPaths.clientLegal ||
    location == AppPaths.clientLegalServices ||
    location == AppPaths.legalServices ||
    location == AppPaths.ownerLegalServices;

bool _isGeneralAdminLocation(String location) =>
    location == AppPaths.adminDashboard ||
    location == AppPaths.adminEventos ||
    location == AppPaths.adminPhotos ||
    location == AppPaths.adminCategoryPhotos ||
    location == AppPaths.adminPerformance;

String? _marketFeatureForLocation(String location) {
  if (_isPaidEventsLocation(location)) return 'events';
  if (_isPaidLegalLocation(location) || location == AppPaths.clientContracts) {
    return 'legal';
  }
  if (location == AppPaths.clientVapId ||
      location == AppPaths.clientVapIdEdit ||
      location.startsWith('/vap-validate/')) {
    return 'local_id';
  }
  if (location == AppPaths.clientServices) return 'workers';
  if (location == AppPaths.exploreSeekers) return 'seekers';
  if (location == AppPaths.subscriptionPackages) return 'premium';
  return null;
}

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _authSub = ref.listen(authStateProvider, (_, _) => notifyListeners());
    _userSub = ref.listen(currentUserProvider, (_, _) => notifyListeners());
    _grantSub = ref.listen(accessGrantedProvider, (_, _) => notifyListeners());
    _sessionSub = ref.listen(appSessionProvider, (_, _) => notifyListeners());
    _marketSub = ref.listen(appMarketProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<AsyncValue<dynamic>> _authSub;
  late final ProviderSubscription<dynamic> _userSub;
  late final ProviderSubscription<AsyncValue<bool>> _grantSub;
  late final ProviderSubscription<AsyncValue<dynamic>> _sessionSub;
  late final ProviderSubscription<AsyncValue<dynamic>> _marketSub;

  @override
  void dispose() {
    _authSub.close();
    _userSub.close();
    _grantSub.close();
    _sessionSub.close();
    _marketSub.close();
    super.dispose();
  }
}
