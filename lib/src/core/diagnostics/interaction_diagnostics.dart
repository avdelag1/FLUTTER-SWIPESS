import 'dart:async';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_navigation_history.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production-safe interaction telemetry for diagnosing dead taps, accidental
/// overlays, bad back routes and runtime exceptions from real sessions.
///
/// Privacy contract: this captures route names, normalized touch positions and
/// sanitized exception text only. It never records text-field values, messages,
/// search text, contacts, passwords or raw screen pixels.
abstract final class AppInteractionDiagnostics {
  static final String sessionId = _makeSessionId();
  static final List<Map<String, dynamic>> _pending = <Map<String, dynamic>>[];
  static Timer? _flushTimer;
  static Future<void>? _flushInFlight;
  static bool _hooksInstalled = false;

  static String _makeSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    var random = 0;
    try {
      random = Random.secure().nextInt(1 << 32);
    } catch (_) {
      random = Random().nextInt(1 << 32);
    }
    return 'ui-$now-${random.toRadixString(36)}';
  }

  static void installErrorHooks() {
    if (_hooksInstalled) return;
    _hooksInstalled = true;

    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (previousFlutterError != null) {
        previousFlutterError(details);
      } else {
        FlutterError.presentError(details);
      }
      recordError(
        kind: 'flutter_error',
        error: details.exception,
        stack: details.stack,
      );
    };

    final previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(kind: 'platform_error', error: error, stack: stack);
      return previousPlatformError?.call(error, stack) ?? false;
    };
  }

  static void recordTap({
    required String routeBefore,
    required String routeAfter,
    required double xNorm,
    required double yNorm,
    required String pointerKind,
    required Size screenSize,
  }) {
    _enqueue({
      'event_kind': 'tap',
      'route_before': _cleanRoute(routeBefore),
      'route_after': _cleanRoute(routeAfter),
      'x_norm': xNorm.clamp(0.0, 1.0),
      'y_norm': yNorm.clamp(0.0, 1.0),
      'outcome': routeBefore == routeAfter ? 'same_route' : 'route_changed',
      'metadata': <String, dynamic>{
        'pointer_kind': pointerKind,
        'screen_w': screenSize.width.round(),
        'screen_h': screenSize.height.round(),
      },
    });
  }

  static void recordNavigation({
    required String routeBefore,
    required String routeAfter,
    String outcome = 'navigated',
  }) {
    if (routeBefore == routeAfter) return;
    _enqueue({
      'event_kind': 'navigation',
      'route_before': _cleanRoute(routeBefore),
      'route_after': _cleanRoute(routeAfter),
      'outcome': outcome,
      'metadata': const <String, dynamic>{},
    });
  }

  static void recordError({
    required String kind,
    required Object error,
    StackTrace? stack,
  }) {
    final stackLines = stack
            ?.toString()
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .take(5)
            .map(_sanitize)
            .toList(growable: false) ??
        const <String>[];
    _enqueue({
      'event_kind': kind,
      'route_before': AppNavigationHistory.current,
      'route_after': AppNavigationHistory.current,
      'outcome': 'error',
      'error_type': error.runtimeType.toString(),
      'error_message': _sanitize(error.toString()),
      'metadata': <String, dynamic>{'stack_head': stackLines},
    }, flushSoon: true);
  }

  static void _enqueue(Map<String, dynamic> event, {bool flushSoon = false}) {
    event['session_id'] = sessionId;
    _pending.add(event);
    if (_pending.length > 120) {
      _pending.removeRange(0, _pending.length - 120);
    }
    if (_pending.length >= 12 || flushSoon) {
      unawaited(flush());
      return;
    }
    _flushTimer ??= Timer(const Duration(seconds: 8), () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  static Future<void> flush() {
    return _flushInFlight ??= _flushInternal().whenComplete(() {
      _flushInFlight = null;
    });
  }

  static Future<void> _flushInternal() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return;

    SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return;
    }
    final user = client.auth.currentUser;
    if (user == null) return;

    final batch = List<Map<String, dynamic>>.from(_pending);
    _pending.clear();
    final rows = <Map<String, dynamic>>[
      for (final event in batch)
        <String, dynamic>{...event, 'user_id': user.id},
    ];

    try {
      await client.from('app_interaction_diagnostics').insert(rows);
    } catch (error) {
      // Diagnostics must never slow or break the app. Keep a bounded in-memory
      // retry buffer and try again after the next interaction.
      _pending.insertAll(0, batch);
      if (_pending.length > 120) {
        _pending.removeRange(0, _pending.length - 120);
      }
      if (kDebugMode) {
        debugPrint('[InteractionDiagnostics] flush skipped: $error');
      }
    }
  }

  static String _cleanRoute(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return value.trim();
    // Query parameters can contain search/user input. Store only the path.
    return uri.path.isEmpty ? '/' : uri.path;
  }

  static String _sanitize(String value) {
    var clean = value;
    clean = clean.replaceAll(
      RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
      '<email>',
    );
    clean = clean.replaceAll(
      RegExp(
        r'([?&](?:token|key|secret|password|code)=)[^&\s]+',
        caseSensitive: false,
      ),
      r'$1<redacted>',
    );
    clean = clean.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+\-/=]+', caseSensitive: false),
      'Bearer <redacted>',
    );
    if (clean.length > 800) clean = clean.substring(0, 800);
    return clean;
  }
}

/// Global pointer probe. A touch is considered a tap only when it moves less
/// than 14 logical pixels, so ordinary scrolling does not flood diagnostics.
class InteractionDiagnosticsProbe extends StatefulWidget {
  const InteractionDiagnosticsProbe({super.key, required this.child});

  final Widget child;

  @override
  State<InteractionDiagnosticsProbe> createState() =>
      _InteractionDiagnosticsProbeState();
}

class _InteractionDiagnosticsProbeState extends State<InteractionDiagnosticsProbe> {
  final Map<int, Offset> _down = <int, Offset>{};
  final Set<int> _moved = <int>{};

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _down[event.pointer] = event.position;
        _moved.remove(event.pointer);
      },
      onPointerMove: (event) {
        final start = _down[event.pointer];
        if (start != null && (event.position - start).distance > 14) {
          _moved.add(event.pointer);
        }
      },
      onPointerCancel: (event) {
        _down.remove(event.pointer);
        _moved.remove(event.pointer);
      },
      onPointerUp: (event) {
        final start = _down.remove(event.pointer);
        final moved = _moved.remove(event.pointer);
        if (start == null || moved) return;

        final before = _currentLocation(context);
        final size = MediaQuery.sizeOf(context);
        if (size.width <= 0 || size.height <= 0) return;
        final x = (event.position.dx / size.width).clamp(0.0, 1.0);
        final y = (event.position.dy / size.height).clamp(0.0, 1.0);
        final kind = _pointerKind(event.kind);

        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          final after = _currentLocation(context);
          AppInteractionDiagnostics.recordTap(
            routeBefore: before,
            routeAfter: after,
            xNorm: x,
            yNorm: y,
            pointerKind: kind,
            screenSize: size,
          );
        });
      },
      child: widget.child,
    );
  }

  String _currentLocation(BuildContext context) {
    try {
      final router = GoRouter.maybeOf(context);
      return router?.routeInformationProvider.value.uri.toString() ??
          AppNavigationHistory.current ??
          '';
    } catch (_) {
      return AppNavigationHistory.current ?? '';
    }
  }

  String _pointerKind(PointerDeviceKind kind) => switch (kind) {
        PointerDeviceKind.touch => 'touch',
        PointerDeviceKind.mouse => 'mouse',
        PointerDeviceKind.stylus => 'stylus',
        PointerDeviceKind.invertedStylus => 'inverted_stylus',
        PointerDeviceKind.trackpad => 'trackpad',
        PointerDeviceKind.unknown => 'unknown',
      };
}
