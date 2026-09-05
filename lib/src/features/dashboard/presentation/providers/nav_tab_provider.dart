import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavTab {
  dashboard,
  profile,
  likes,
  ai,
  add,
  messages,
  idCard,
  seekers,
  filter,
  legal,
  events,
}

class NavTabNotifier extends Notifier<NavTab> {
  @override
  NavTab build() => NavTab.dashboard;

  void set(NavTab tab) => state = tab;
}

final navTabProvider = NotifierProvider<NavTabNotifier, NavTab>(
  NavTabNotifier.new,
);

class DashboardHomeTappedNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Incremented every time the user taps the Home icon while already on the
/// Home tab. Used to trigger scroll-to-top and pull-to-refresh on the dashboard.
final dashboardHomeTappedProvider = NotifierProvider<DashboardHomeTappedNotifier, int>(
  DashboardHomeTappedNotifier.new,
);
