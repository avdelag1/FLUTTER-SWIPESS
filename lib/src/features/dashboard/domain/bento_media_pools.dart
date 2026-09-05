import 'package:flutter_swipes/src/core/constants/app_assets.dart';

/// Quick-filter media pools provide editorial fallbacks when a live category
/// has no current media. These assets never carry a listing/profile id, so
/// tapping them opens the category itself instead of impersonating inventory.
class BentoMediaPools {
  BentoMediaPools._();

  static List<String> forId(String id) {
    switch (id) {
      case 'property':
        return const [AppAssets.filterProperty];
      case 'services':
        return const [AppAssets.filterPros];
      case 'yacht':
        return const [
          'https://images.unsplash.com/photo-1549026841-dc1939a05b67?auto=format&fit=crop&w=1200&q=90',
        ];
      case 'motorcycle':
        return const [AppAssets.filterMotorcycle];
      case 'bicycle':
        return const [AppAssets.filterBicycle];
      case 'buyers':
        return const [AppAssets.filterBuyers];
      case 'renters':
        return const [AppAssets.filterRenters];
      case 'seekers':
        return const [AppAssets.filterLeads];

      // Events has its own live EventsTeaserCard. Keep this pool only as an
      // editorial asset source for any non-live context that explicitly asks.
      case 'events':
        return const [
          AppAssets.filterEvents,
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1000&q=92',
        ];
      case 'jets':
        return const [
          'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1000&q=92',
        ];
      case 'legal':
        return const [
          'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?auto=format&fit=crop&w=1000&q=92',
        ];
      case 'premium':
        return const [
          AppAssets.filterProperty,
          'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=1000&q=92',
        ];
      default:
        return const [];
    }
  }
}
