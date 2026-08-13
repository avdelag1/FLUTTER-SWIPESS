import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/cap_placeholder_screen.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/legendary_onboarding_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/not_found_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/profile_camera_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/escrow/presentation/screens/escrow_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_detail_route_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_favorites_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/local_intel_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/price_tracker_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contracts_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/faq_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/lawyer_services_screen.dart';
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
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/subscription_packages_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';
import 'package:flutter_swipes/src/features/video_tours/presentation/screens/video_tours_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppPaths.gate,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final grantedAsync = ref.read(accessGrantedProvider);
      // While grant status is still loading, don't bounce the user.
      if (grantedAsync.isLoading) return null;
      final granted = grantedAsync.value ?? false;
      final user = ref.read(currentUserProvider);

      final publicExact = {
        AppPaths.resetPassword,
        AppPaths.paymentSuccess,
        AppPaths.paymentCancel,
        AppPaths.about,
        AppPaths.contact,
        AppPaths.faqClient,
        AppPaths.faqOwner,
        AppPaths.legal,
      };
      final isPublic = publicExact.contains(loc) ||
          loc.startsWith('/preview/listing/') ||
          loc.startsWith('/preview/profile/') ||
          loc.startsWith('/vap-validate/') ||
          loc.startsWith('/s/');

      if (isPublic) return null;

      if (!granted && loc != AppPaths.gate) return AppPaths.gate;

      if (granted && user == null) {
        if (loc == AppPaths.gate) return AppPaths.welcome;
        if (loc == AppPaths.onboarding) return null;
        if (loc == AppPaths.legacyDashboard ||
            loc == AppPaths.clientDashboard) {
          return AppPaths.welcome;
        }
      }

      if (user != null &&
          (loc == AppPaths.gate ||
              loc == AppPaths.welcome ||
              loc == AppPaths.onboarding ||
              loc == AppPaths.auth)) {
        return AppPaths.clientDashboard;
      }

      // Capacitor aliases / redirects
      if (loc == AppPaths.legacyDashboard) return AppPaths.clientDashboard;
      if (loc == AppPaths.ownerDashboard) return AppPaths.clientDashboard;
      if (loc == AppPaths.ownerProfile) return AppPaths.clientProfile;
      if (loc == AppPaths.exploreServices) return AppPaths.clientServices;
      if (loc == '/promote-event/request' ||
          loc == '/promote-event/packages' ||
          loc == '/promote') {
        return AppPaths.clientAdvertise;
      }
      if (loc == '/privacy-policy') return '${AppPaths.legal}?doc=privacy';
      if (loc == '/terms-of-service') return '${AppPaths.legal}?doc=terms';
      if (loc == '/agl') return '${AppPaths.legal}?doc=agl';
      if (loc == '/share-target') return AppPaths.clientDashboard;

      return null;
    },
    routes: [
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
        builder: (ctx, _) => LegendaryOnboardingScreen(
          onFinish: () => ctx.go(AppPaths.welcome),
        ),
      ),
      GoRoute(
        path: AppPaths.auth,
        builder: (ctx, _) {
          final intent = ref.read(authIntentProvider);
          return AuthScreen(
            mode: intent == AuthIntent.signup ? 'signup' : 'login',
          );
        },
      ),
      GoRoute(
        path: AppPaths.resetPassword,
        builder: (ctx, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/preview/listing/:id',
        builder: (ctx, state) => PublicListingPreviewScreen(
          listingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/preview/profile/:id',
        builder: (ctx, state) => PublicProfilePreviewScreen(
          userId: state.pathParameters['id']!,
        ),
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
      GoRoute(
        path: AppPaths.about,
        builder: (ctx, _) => const AboutScreen(),
      ),
      GoRoute(
        path: AppPaths.contact,
        builder: (ctx, _) => const ContactSupportScreen(),
      ),
      GoRoute(
        path: AppPaths.faqClient,
        builder: (ctx, _) => const FAQScreen(),
      ),
      GoRoute(
        path: AppPaths.faqOwner,
        builder: (ctx, _) => const FAQScreen(),
      ),
      GoRoute(
        path: AppPaths.legal,
        builder: (ctx, _) => const LegalHubScreen(),
      ),
      GoRoute(
        path: '/vap-validate/:id',
        builder: (ctx, state) => VapValidateScreen(
          userId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (ctx, state) => ListingDetailScreen(
          listingId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (ctx, state) => ProfileDetailScreen(
          userId: state.pathParameters['id']!,
        ),
      ),
      // Legacy event_card push target
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
            builder: (ctx, _) => const BentoDashboardScreen(),
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
            builder: (ctx, _) => const EventsScreen(),
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
            // Cap dock legal → LawyerServicesPage (chrome stays).
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

      // Full-screen authenticated Cap routes (no bottom dock)
      GoRoute(
        path: AppPaths.clientSettings,
        builder: (ctx, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppPaths.ownerSettings,
        builder: (ctx, _) => const SettingsScreen(),
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
        redirect: (ctx, state) => AppPaths.clientFilters,
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
        builder: (ctx, state) => ProfileDetailScreen(
          userId: state.pathParameters['clientId']!,
        ),
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
        path: AppPaths.exploreEventsLikes,
        builder: (ctx, _) => const EventFavoritesScreen(),
      ),
      GoRoute(
        path: '/explore/events/:id',
        builder: (ctx, state) => EventDetailRouteScreen(
          eventId: state.pathParameters['id']!,
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
      GoRoute(
        path: AppPaths.map,
        builder: (ctx, _) => const LiveMapScreen(),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (ctx, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/admin/eventos',
        builder: (ctx, _) => const CapPlaceholderScreen(
          title: 'Admin Events',
          path: '/admin/eventos',
        ),
      ),
      GoRoute(
        path: '/admin/photos',
        builder: (ctx, _) => const CapPlaceholderScreen(
          title: 'Admin Photos',
          path: '/admin/photos',
        ),
      ),
      GoRoute(
        path: '/admin/category-photos',
        builder: (ctx, _) => const CapPlaceholderScreen(
          title: 'Admin Category Photos',
          path: '/admin/category-photos',
        ),
      ),
      GoRoute(
        path: '/admin/performance',
        builder: (ctx, _) => const CapPlaceholderScreen(
          title: 'Admin Performance',
          path: '/admin/performance',
        ),
      ),
      GoRoute(
        path: '*',
        builder: (ctx, state) => NotFoundScreen(
          path: state.uri.toString(),
        ),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _authSub = ref.listen(authStateProvider, (_, _) => notifyListeners());
    _grantSub = ref.listen(accessGrantedProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<AsyncValue<dynamic>> _authSub;
  late final ProviderSubscription<AsyncValue<bool>> _grantSub;

  @override
  void dispose() {
    _authSub.close();
    _grantSub.close();
    super.dispose();
  }
}
