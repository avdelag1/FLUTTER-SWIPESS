import 'dart:math';

import 'package:flutter_swipes/src/core/diagnostics/interaction_diagnostics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Best-effort profile CRM analytics. Must never block user actions.
abstract final class ProfileInsightTracker {
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
    return 'flutter-insights-$now-$random';
  }

  static Future<void> track({
    required String ownerUserId,
    required String eventType,
    String channel = 'in_app',
    String source = 'flutter',
    Map<String, dynamic> metadata = const <String, dynamic>{},
    bool oncePerSession = false,
  }) async {
    if (ownerUserId.trim().isEmpty) return;

    final key = '$ownerUserId:$eventType:$channel:$source';
    if (oncePerSession && !_once.add(key)) return;

    try {
      await Supabase.instance.client.rpc(
        'track_profile_insight_event',
        params: <String, dynamic>{
          'p_owner_user_id': ownerUserId,
          'p_event_type': eventType,
          'p_channel': channel,
          'p_source': source,
          'p_session_id': _sessionId,
          'p_metadata': metadata,
        },
      );
    } catch (error, stack) {
      // CRM tracking stays non-blocking, but failures are now visible in the
      // developer diagnostics stream instead of disappearing silently.
      AppInteractionDiagnostics.recordError(
        kind: 'platform_error',
        error: error,
        stack: stack,
      );
    }
  }
}
