import 'package:flutter_swipes/src/core/constants/app_assets.dart';

/// Cap-style quick-filter media pools (4–5 items: photos + optional videos).
class BentoMediaPools {
  BentoMediaPools._();

  static const _propertyVideo =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  static const _tourVideo =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

  static List<String> forId(String id) {
    switch (id) {
      case 'property':
      case 'popular':
      case 'premium':
        return const [
          AppAssets.filterProperty,
          AppAssets.filterPropertyJungle,
          'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=800&q=90',
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=800&q=90',
          _propertyVideo,
        ];
      case 'recommended':
        return const [
          'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=800&q=90',
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=800&q=90',
          AppAssets.filterProperty,
          _tourVideo,
          'https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=800&q=90',
        ];
      case 'services':
      case 'legal':
        return const [
          AppAssets.filterPros,
          'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=800&q=90',
          'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=800&q=90',
          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=800&q=90',
          _tourVideo,
        ];
      case 'yacht':
        return const [
          'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=800&q=90',
          'https://images.unsplash.com/photo-1605281317010-fe5ffe798166?auto=format&fit=crop&w=800&q=90',
          'https://images.unsplash.com/photo-1540946485063-a40da27545f8?auto=format&fit=crop&w=800&q=90',
          _propertyVideo,
          'https://images.unsplash.com/photo-1569263979104-865ab7cd8d13?auto=format&fit=crop&w=800&q=90',
        ];
      case 'motorcycle':
        return const [
          AppAssets.filterMotorcycle,
          'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=800&q=90',
          'https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?auto=format&fit=crop&w=800&q=90',
          _tourVideo,
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=800&q=90',
        ];
      case 'bicycle':
        return const [
          AppAssets.filterBicycle,
          AppAssets.filterBicycleSunset,
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?auto=format&fit=crop&w=800&q=90',
          'https://images.unsplash.com/photo-1534723452862-4c874018d66d?auto=format&fit=crop&w=800&q=90',
          _propertyVideo,
        ];
      case 'seekers':
        return const [
          AppAssets.filterBuyers,
          AppAssets.filterRenters,
          AppAssets.filterLeads,
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=90',
          _tourVideo,
        ];
      default:
        return const [
          AppAssets.filterProperty,
          AppAssets.filterPropertyJungle,
          AppAssets.filterEvents,
          _propertyVideo,
        ];
    }
  }
}
