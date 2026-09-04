import 'package:flutter_swipes/src/core/constants/app_assets.dart';

/// Quick-filter media pools are reserved for editorial/non-inventory surfaces.
///
/// Live marketplace/profile quick filters must never fall back to canned media:
/// an empty live feed should look empty, not like a stale/deleted listing or an
/// old account snapshot. This keeps installed PWAs honest without requiring a
/// reinstall just to clear something that only looked like inventory.
class BentoMediaPools {
  BentoMediaPools._();

  static List<String> forId(String id) {
    switch (id) {
      // LIVE INVENTORY / LIVE PEOPLE — never synthesize fake cards.
      case 'property':
      case 'buyers':
      case 'renters':
      case 'services':
      case 'yacht':
      case 'motorcycle':
      case 'bicycle':
      case 'seekers':
        return const [];

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
