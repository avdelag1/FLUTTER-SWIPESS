import 'package:flutter_swipes/src/core/constants/app_assets.dart';

/// Quick-filter media pools are intentionally disjoint by category so every
/// card reads as its own destination. Local assets are mixed with editorial
/// photography where possible so a temporary CDN failure never turns the most
/// important discovery cards into an empty black tile.
class BentoMediaPools {
  BentoMediaPools._();

  static List<String> forId(String id) {
    switch (id) {
      case 'property':
        return const [
          AppAssets.filterPropertyJungle,
          'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1000&q=92',
        ];
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
      case 'buyers':
        return const [
          AppAssets.filterBuyers,
          AppAssets.filterProperty,
        ];
      case 'renters':
        return const [
          AppAssets.filterRenters,
          AppAssets.filterPropertyJungle,
        ];
      case 'services': // Workers: cleaning, maintenance, wellness and pros.
        return const [
          AppAssets.filterPros,
          'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=1000&q=92',
        ];
      case 'yacht':
        return const [
          'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1605281317010-fe5ffe798166?auto=format&fit=crop&w=1000&q=92',
        ];
      case 'motorcycle':
        // Keep the first and last frames local. The previous ATV Unsplash URL
        // now returns 404 and was filling the web console on every dashboard
        // rotation. Local fallbacks make this rail deterministic and quiet.
        return const [
          AppAssets.filterMotorcycle,
          'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=1000&q=92',
          AppAssets.filterMotorcycle,
        ];
      case 'bicycle':
        return const [
          AppAssets.filterBicycle,
          // Fat-tire electric bike with an ocean backdrop.
          'https://images.unsplash.com/photo-1485965120184-e220f721d03e?auto=format&fit=crop&w=1000&q=92',
          // Beach cruiser / fat-bike pairing.
          'https://images.unsplash.com/photo-1532298229144-0ec0c57515c7?auto=format&fit=crop&w=1000&q=92',
          AppAssets.filterBicycleSunset,
        ];
      case 'seekers':
        return const [
          AppAssets.filterLeads,
          'https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1556155092-490a1ba16284?auto=format&fit=crop&w=1000&q=92',
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
        return const [AppAssets.filterProperty];
    }
  }
}
