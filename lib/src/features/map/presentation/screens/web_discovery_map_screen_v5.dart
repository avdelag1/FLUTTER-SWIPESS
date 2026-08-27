import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_locations.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/web_discovery_map_screen_v8.dart'
    as legacy;

@JS('eval')
external JSAny? _eval(JSString code);

/// Web entry point for the discovery map.
///
/// V8 owns the visual map UI. This wrapper fixes an important browser-specific
/// gap: Flutter web's text field was only filtering visible cards while typing,
/// so pressing Enter/Search did not navigate to a city. We listen at the
/// hardware-keyboard level, read the active browser text input, and route known
/// city searches through the same discovery-location provider used by the city
/// chips and GPS controls.
class WebDiscoveryMapScreenV5 extends ConsumerStatefulWidget {
  const WebDiscoveryMapScreenV5({
    super.key,
    this.onClose,
    this.showCitiesOnOpen = false,
  });

  final VoidCallback? onClose;
  final bool showCitiesOnOpen;

  @override
  ConsumerState<WebDiscoveryMapScreenV5> createState() =>
      _WebDiscoveryMapScreenV5State();
}

class _WebDiscoveryMapScreenV5State
    extends ConsumerState<WebDiscoveryMapScreenV5> {
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return false;
    }

    final value = _activeTextInputValue();
    if (value == null || value.trim().isEmpty) return false;
    unawaited(_submitMapSearch(value));
    // Do not swallow Enter. The TextField can still complete its normal search
    // action while this wrapper performs geographic navigation.
    return false;
  }

  String? _activeTextInputValue() {
    try {
      final result = _eval(
        r'''
        (function () {
          var e = document.activeElement;
          if (!e) return '';
          var tag = String(e.tagName || '').toLowerCase();
          if (tag !== 'input' && tag !== 'textarea') return '';
          return String(e.value || '');
        })()
        '''
            .toJS,
      );
      if (result is JSString) return result.toDart;
    } catch (_) {}
    return null;
  }

  Future<void> _submitMapSearch(String raw) async {
    if (_submitting || !mounted) return;
    final query = raw.trim();
    final city = ListingLocations.resolve(query);
    if (city == null) return;

    _submitting = true;
    try {
      ref.read(discoveryLocationProvider.notifier).setCoordinates(
            city: query,
            country: city.country,
            latitude: city.lat,
            longitude: city.lng,
          );
      final radius = ref.read(discoveryLocationProvider).radiusKm;
      if (radius > 250) {
        ref.read(discoveryLocationProvider.notifier).setRadiusKm(25);
      }
      FocusManager.instance.primaryFocus?.unfocus();
    } finally {
      _submitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return legacy.WebDiscoveryMapScreenV5(
      onClose: widget.onClose,
      showCitiesOnOpen: widget.showCitiesOnOpen,
    );
  }
}
