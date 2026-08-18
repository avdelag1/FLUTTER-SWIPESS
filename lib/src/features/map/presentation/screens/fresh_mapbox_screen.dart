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
      _refreshData();
    });
  }

  void _refreshData() {
    ref.invalidate(mapListingsProvider);
    ref.invalidate(mapProfilesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(mapListingsProvider);
    final profiles = ref.watch(mapProfilesProvider);
    final loading = listings.isLoading || profiles.isLoading;
    final failed = listings.hasError || profiles.hasError;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        RealMapboxScreen(
          onClose: widget.onClose,
          showCitiesOnOpen: widget.showCitiesOnOpen,
        ),
        if (loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: Color(0xFF60A5FA),
            ),
          ),
        if (failed)
          Positioned(
            left: 12,
            bottom: bottom + 18,
            child: Material(
              color: Colors.black.withAlpha(170),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _refreshData,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withAlpha(65),
                      width: .7,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'RETRY MAP DATA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
