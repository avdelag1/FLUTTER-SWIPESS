import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap `modalStore` — PEARL, Passport map, and Concierge are overlays, not tabs.
class OverlayModals {
  const OverlayModals({
    this.showVapId = false,
    this.showPassportMap = false,
    this.showConcierge = false,
    this.conciergeQuery = '',
    this.mapShowCities = false,
  });

  final bool showVapId;
  final bool showPassportMap;
  final bool showConcierge;
  final String conciergeQuery;
  final bool mapShowCities;

  OverlayModals copyWith({
    bool? showVapId,
    bool? showPassportMap,
    bool? showConcierge,
    String? conciergeQuery,
    bool? mapShowCities,
  }) {
    return OverlayModals(
      showVapId: showVapId ?? this.showVapId,
      showPassportMap: showPassportMap ?? this.showPassportMap,
      showConcierge: showConcierge ?? this.showConcierge,
      conciergeQuery: conciergeQuery ?? this.conciergeQuery,
      mapShowCities: mapShowCities ?? this.mapShowCities,
    );
  }
}

class OverlayModalsNotifier extends Notifier<OverlayModals> {
  @override
  OverlayModals build() => const OverlayModals();

  void closeAll() => state = const OverlayModals();

  // PEARL is exclusive because it is a focused identity presentation surface.
  // Opening it must never leave a hidden full-screen layer swallowing the
  // persistent header/dock.
  void openVapId() => state = const OverlayModals(showVapId: true);

  void closeVapId() => state = state.copyWith(showVapId: false);

  // Map is allowed to sit above an existing concierge session. That preserves
  // the live AI conversation/camera context so Back can reveal it exactly as it
  // was instead of silently starting a new session.
  void openPassportMap({bool showCities = false}) => state = state.copyWith(
    showVapId: false,
    showPassportMap: true,
    mapShowCities: showCities,
  );

  void closePassportMap() => state = state.copyWith(showPassportMap: false);

  void openConcierge([String query = '']) =>
      state = OverlayModals(showConcierge: true, conciergeQuery: query);

  void closeConcierge() =>
      state = state.copyWith(showConcierge: false, conciergeQuery: '');
}

final overlayModalsProvider =
    NotifierProvider<OverlayModalsNotifier, OverlayModals>(
      OverlayModalsNotifier.new,
    );
