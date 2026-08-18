import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_listings_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_profiles_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/real_mapbox_screen.dart';

/// Ensures every map opening starts with a fresh discovery request instead of
/// reusing an old cached empty/error FutureProvider result.
class FreshMapboxScreen extends ConsumerStatefulWidget {
  const FreshMapboxScreen({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<FreshMapboxScreen> createState() => _FreshMapboxScreenState();
}

class _FreshMapboxScreenState extends ConsumerState<FreshMapboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(mapListingsProvider);
      ref.invalidate(mapProfilesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RealMapboxScreen(
      onClose: widget.onClose,
      showCitiesOnOpen: widget.showCitiesOnOpen,
    );
  }
}
