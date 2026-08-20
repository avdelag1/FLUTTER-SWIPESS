import 'dart:math';

import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Best-effort event analytics. Tracking must never block the user's action.
abstract final class EventEngagementTracker {
  static final String _sessionId = _makeSessionId();
  static final Set<String> _once = <String>{};

  static String _makeSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    String random;
    try {
      random = Random.secure().nextInt(1 << 32).toRadixString(36);
    } catch (_) {
      random = Random().nextInt(1 << 32).toRadixString(36);
    }
    return 'flutter-$now-$random';
  }

  static Future<void> track(
    Event event,
    String action, {
    String source = 'flutter_event',
    Map<String, dynamic> metadata = const <String, dynamic>{},
    bool oncePerSession = false,
  }) async {
    final key = '${event.id}:$action:$source';
    if (oncePerSession && !_once.add(key)) return;

    try {
      await Supabase.instance.client.rpc(
        'track_event_engagement',
        params: <String, dynamic>{
          'p_event_id': event.id,
          'p_action': action,
          'p_source': source,
          'p_session_id': _sessionId,
          'p_metadata': metadata,
        },
      );
    } catch (_) {
      // Analytics is intentionally non-blocking. Contact/share/navigation must
      // still work if the network or analytics backend is unavailable.
    }
  }
}
