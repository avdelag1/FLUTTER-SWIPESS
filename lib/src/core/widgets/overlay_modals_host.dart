import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/widgets/app_notification_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/fresh_mapbox_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/vap_id_modal.dart';

/// Root overlay stack for VAP, map, and concierge overlays.
class OverlayModalsHost extends ConsumerWidget {
  const OverlayModalsHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modals = ref.watch(overlayModalsProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (modals.showVapId) const VapIdModal(),
        if (modals.showPassportMap)
          Positioned.fill(
            child: FreshMapboxScreen(
              onClose: () =>
                  ref.read(overlayModalsProvider.notifier).closePassportMap(),
              showCitiesOnOpen: modals.mapShowCities,
            ),
          ),
        if (modals.showConcierge)
          Positioned.fill(
            child: ConciergeOverlay(
              initialQuery: modals.conciergeQuery,
              onClose: () =>
                  ref.read(overlayModalsProvider.notifier).closeConcierge(),
            ),
          ),
        const AppNotificationBar(),
      ],
    );
  }
}
