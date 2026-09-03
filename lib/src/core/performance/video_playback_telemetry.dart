import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'video_platform_context.dart';

class VideoPlaybackTelemetry {
  VideoPlaybackTelemetry._();

  static final Connectivity _connectivity = Connectivity();
  static final Random _random = Random.secure();

  static String newSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(0x7fffffff).toRadixString(36);
    return 'v-$now-$salt';
  }

  static String platformLabel() {
    final target = defaultTargetPlatform.name;
    if (!kIsWeb) return target;
    return '${isInstalledWebApp ? 'pwa' : 'web'}-$target';
  }

  static Future<String> currentNetworkType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty) return 'unknown';
      final names = results.map((e) => e.name).toSet().toList()..sort();
      return names.join('+');
    } catch (_) {
      return 'unknown';
    }
  }

  static String mediaHash(String? url) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) return '';
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static void emit({
    required String sessionId,
    required String eventType,
    String surface = 'quick_filter',
    String? listingId,
    String? mediaUrl,
    int? initMs,
    int? ttffMs,
    int? bufferMs,
    int? rebufferCount,
    int? positionMs,
    int? durationMs,
    String? errorCode,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    unawaited(
      _emit(
        sessionId: sessionId,
        eventType: eventType,
        surface: surface,
        listingId: listingId,
        mediaUrl: mediaUrl,
        initMs: initMs,
        ttffMs: ttffMs,
        bufferMs: bufferMs,
        rebufferCount: rebufferCount,
        positionMs: positionMs,
        durationMs: durationMs,
        errorCode: errorCode,
        extra: extra,
      ),
    );
  }

  static Future<void> _emit({
    required String sessionId,
    required String eventType,
    required String surface,
    String? listingId,
    String? mediaUrl,
    int? initMs,
    int? ttffMs,
    int? bufferMs,
    int? rebufferCount,
    int? positionMs,
    int? durationMs,
    String? errorCode,
    required Map<String, Object?> extra,
  }) async {
    try {
      final networkType = await currentNetworkType();
      await Supabase.instance.client.rpc(
        'record_video_playback_event',
        params: <String, dynamic>{
          'p_session_id': sessionId,
          'p_event_type': eventType,
          'p_listing_id': listingId,
          'p_surface': surface,
          'p_platform': platformLabel(),
          'p_network_type': networkType,
          'p_media_url_hash': mediaHash(mediaUrl),
          'p_init_ms': initMs,
          'p_ttff_ms': ttffMs,
          'p_buffer_ms': bufferMs,
          'p_rebuffer_count': rebufferCount,
          'p_position_ms': positionMs,
          'p_duration_ms': durationMs,
          'p_error_code': errorCode,
          'p_extra': extra,
        },
      );
    } catch (_) {
      // Observability must never become a playback dependency.
    }
  }
}
