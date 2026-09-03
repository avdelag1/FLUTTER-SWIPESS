import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class DashboardDiscoveryMenuActions {
  const DashboardDiscoveryMenuActions({
    this.openLocation,
    this.openDates,
    this.openGuests,
  });

  final VoidCallback? openLocation;
  final VoidCallback? openDates;
  final VoidCallback? openGuests;

  bool get available =>
      openLocation != null && openDates != null && openGuests != null;
}

class DashboardDiscoveryMenuActionsNotifier
    extends Notifier<DashboardDiscoveryMenuActions> {
  @override
  DashboardDiscoveryMenuActions build() =>
      const DashboardDiscoveryMenuActions();

  void register({
    required VoidCallback openLocation,
    required VoidCallback openDates,
    required VoidCallback openGuests,
  }) {
    state = DashboardDiscoveryMenuActions(
      openLocation: openLocation,
      openDates: openDates,
      openGuests: openGuests,
    );
  }

  void clear() => state = const DashboardDiscoveryMenuActions();
}

final dashboardDiscoveryMenuActionsProvider =
    NotifierProvider<
      DashboardDiscoveryMenuActionsNotifier,
      DashboardDiscoveryMenuActions
    >(DashboardDiscoveryMenuActionsNotifier.new);
