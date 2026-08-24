import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';

/// Capacitor `App.tsx` path parity for Flutter GoRouter.
abstract final class AppPaths {
  static const splash = '/splash';
  static const gate = '/gate';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const resetPassword = '/reset-password';

  static const clientDashboard = '/client/dashboard';
  static const clientProfile = '/client/profile';
  static const clientSettings = '/client/settings';
  static const clientLikedProperties = '/client/liked-properties';
  static const clientWhoLikedYou = '/client/who-liked-you';
  static const clientSavedSearches = '/client/saved-searches';
  static const clientSecurity = '/client/security';
  static const clientServices = '/client/services';
  static const clientContracts = '/client/contracts';
  static const clientLegal = '/client/legal';
  static const clientLegalServices = '/client/legal-services';
  static const legalServices = '/legal-services';
  static const clientCamera = '/client/camera';
  static const clientFilters = '/client/filters';
  static const clientMaintenance = '/client/maintenance';
  static const clientAdvertise = '/client/advertise';
  static const clientPerks = '/client/perks';
  static const clientVapId = '/client/vap-id';
  static const clientVapIdEdit = '/client/vap-id/edit';

  static const ownerDashboard = '/owner/dashboard';
  static const businessDashboard = '/business/dashboard';
  static const businessScan = '/business/scan';
  static const ownerProfile = '/owner/profile';
  static const ownerSettings = '/owner/settings';
  static const ownerProperties = '/owner/properties';
  static const ownerListings = '/owner/listings';
  static const ownerListingsNew = '/owner/listings/new';
  static const ownerLikedClients = '/owner/liked-clients';
  static const ownerInterestedClients = '/owner/interested-clients';
  static const ownerSavedSearches = '/owner/saved-searches';
  static const ownerSecurity = '/owner/security';
  static const ownerContracts = '/owner/contracts';
  static const ownerLegalServices = '/owner/legal-services';
  static const ownerCamera = '/owner/camera';
  static const ownerCameraListing = '/owner/camera/listing';
  static const ownerFilters = '/owner/filters';

  static const messages = '/messages';
  static const notifications = '/notifications';
  static const subscriptionPackages = '/subscription/packages';

  static const exploreEvents = '/explore/events';
  static const exploreEventsLikes = '/explore/events/likes';
  static const explorePrices = '/explore/prices';
  static const exploreTours = '/explore/tours';
  static const exploreIntel = '/explore/intel';
  static const exploreRoommates = '/explore/roommates';
  static const exploreServices = '/explore/services';
  static const exploreSeekers = '/explore/seekers';

  static const documents = '/documents';
  static const escrow = '/escrow';
  static const legal = '/legal';
  static const about = '/about';
  static const contact = '/contact';
  static const faqClient = '/faq/client';
  static const faqOwner = '/faq/owner';
  static const map = '/map';

  static const adminDashboard = '/admin/dashboard';
  static const legalAdminDashboard = '/admin/legal';
  static const lawyerDashboard = '/lawyer/dashboard';
  static const adminEventos = '/admin/eventos';
  static const adminPhotos = '/admin/photos';
  static const adminCategoryPhotos = '/admin/category-photos';
  static const adminPerformance = '/admin/performance';

  static const paymentSuccess = '/payment/success';
  static const paymentCancel = '/payment/cancel';

  static const legacyDashboard = '/dashboard';

  static String exploreEvent(String id) => '/explore/events/$id';
  static String listing(String id) => '/listing/$id';
  static String profile(String id) => '/profile/$id';
  static String previewListing(String id) => '/preview/listing/$id';
  static String previewProfile(String id) => '/preview/profile/$id';
  static String messagesConversation(String id) => '/messages/$id';
  static String vapValidate(String id) => '/vap-validate/$id';
  static String ownerViewClient(String clientId) =>
      '/owner/view-client/$clientId';

  /// Bottom-dock destinations that mirror Capacitor primary URLs.
  static String pathForTab(NavTab tab) {
    switch (tab) {
      case NavTab.dashboard:
        return clientDashboard;
      case NavTab.likes:
        return clientLikedProperties;
      case NavTab.messages:
        return messages;
      case NavTab.idCard:
        return clientVapId;
      case NavTab.seekers:
        return exploreSeekers;
      case NavTab.legal:
        return clientLegalServices;
      case NavTab.events:
        return exploreEvents;
      case NavTab.ai:
      case NavTab.add:
      case NavTab.filter:
        return clientDashboard;
    }
  }

  static NavTab? tabForLocation(String location) {
    if (location == clientDashboard || location == legacyDashboard) {
      return NavTab.dashboard;
    }
    if (location == clientLikedProperties || location == ownerLikedClients) {
      return NavTab.likes;
    }
    if (location == messages || location.startsWith('$messages/')) {
      return NavTab.messages;
    }
    if (location == clientVapId) return NavTab.idCard;
    if (location == exploreSeekers) return NavTab.seekers;
    if (location == clientLegal ||
        location == legal ||
        location == clientLegalServices ||
        location == clientContracts ||
        location == legalServices ||
        location == ownerLegalServices ||
        location == ownerContracts) {
      return NavTab.legal;
    }
    if (location == exploreEvents ||
        location == exploreEventsLikes ||
        (location.startsWith('$exploreEvents/') &&
            location != exploreEventsLikes)) {
      if (location == exploreEvents || location == exploreEventsLikes) {
        return NavTab.events;
      }
      return null;
    }
    return null;
  }

  static bool isShellLocation(String location) {
    const shellExact = {
      clientDashboard,
      clientProfile,
      clientLikedProperties,
      messages,
      exploreEvents,
      exploreSeekers,
      clientLegal,
      clientLegalServices,
      clientContracts,
      clientVapId,
      legacyDashboard,
    };
    return shellExact.contains(location);
  }
}
