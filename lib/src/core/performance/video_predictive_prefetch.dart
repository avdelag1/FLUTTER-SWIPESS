import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'video_playback_telemetry.dart';

class VideoPredictivePrefetch {
  VideoPredictivePrefetch._();

  static final Set<String> _attempted = <String>{};
  static const int _rangeBytes = 256 * 1024;

  static Future<void> prefetchOne({
    required String url,
    String? listingId,
    String surface = 'quick_filter',
  }) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;
    if (!_attempted.add(normalized)) return;
    if (_attempted.length > 96) {
      final keep = normalized;
      _attempted
        ..clear()
        ..add(keep);
    }

    final network = await VideoPlaybackTelemetry.currentNetworkType();
    final onWifi = network.contains('wifi') || network.contains('ethernet');
    final browserSafe =
        kIsWeb && !network.contains('mobile') && !network.contains('none');
    if (!onWifi && !browserSafe) return;

    final session = VideoPlaybackTelemetry.newSessionId();
    try {
      final response = await http
          .get(
            uri,
            headers: const <String, String>{
              'Range': 'bytes=0-262143',
              'Accept': 'video/*,*/*;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 4));

      final accepted = response.statusCode == 206 || response.statusCode == 200;
      VideoPlaybackTelemetry.emit(
        sessionId: session,
        eventType: 'prefetch',
        surface: surface,
        listingId: listingId,
        mediaUrl: normalized,
        extra: <String, Object?>{
          'status': response.statusCode,
          'bytes': response.bodyBytes.length,
          'range_bytes': _rangeBytes,
          'accepted': accepted,
        },
      );
    } catch (error) {
      VideoPlaybackTelemetry.emit(
        sessionId: session,
        eventType: 'prefetch',
        surface: surface,
        listingId: listingId,
        mediaUrl: normalized,
        errorCode: error.runtimeType.toString(),
        extra: const <String, Object?>{'accepted': false},
      );
    }
  }
}
