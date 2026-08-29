import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final voiceTranscribeRepositoryProvider = Provider<VoiceTranscribeRepository>((
  ref,
) {
  return VoiceTranscribeRepository();
});

/// High-accuracy voice capture backed by the `voice-transcribe` Edge Function.
///
/// The default language is automatic. Passing a concrete locale such as
/// `es-MX` or `en-US` gives Whisper a useful hint, while an empty value lets it
/// auto-detect bilingual/code-switched speech.
class VoiceTranscribeRepository {
  VoiceTranscribeRepository({
    AudioRecorder? recorder,
    http.Client? httpClient,
    SupabaseClient? client,
  }) : _recorder = recorder ?? AudioRecorder(),
       _http = httpClient ?? http.Client(),
       _client = client;

  final AudioRecorder _recorder;
  final http.Client _http;

  // Keep Supabase lazy. The Dashboard creates this repository when the search
  // field is mounted, including in widget tests and during very early app boot.
  // Resolving Supabase.instance in the constructor used to throw before
  // Supabase.initialize() had completed, which could prevent the whole search
  // field from rendering. We only need the client when transcription is sent.
  final SupabaseClient? _client;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> isRecording() => _recorder.isRecording();

  /// Live microphone level used for the in-field waveform. `Amplitude.current`
  /// is dBFS on supported platforms/web, so callers can normalize it visually.
  Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 100),
  }) => _recorder.onAmplitudeChanged(interval);

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    if (await _recorder.isRecording()) return true;

    // Chrome/Edge/Firefox do not reliably support AAC MediaRecorder output,
    // while WAV works across modern browsers. Native iOS/Android use compact
    // AAC/M4A. Auto gain / echo cancellation / noise suppression are best-effort
    // and are ignored on platforms that do not support them.
    final config = RecordConfig(
      encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
      numChannels: 1,
      sampleRate: 16000,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );
    await _recorder.start(
      config,
      path: kIsWeb ? '' : 'swipess_voice.m4a',
    );
    return true;
  }

  Future<String> stop({String language = ''}) async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) return '';
    final bytes = await _readBytes(path);
    if (bytes.length < 500) {
      throw VoiceTranscribeException(
        'Recording too short — keep speaking, then wait for 3-2-1',
      );
    }
    return transcribe(bytes, mimeType: _mimeFor(path), language: language);
  }

  Future<void> cancel() async {
    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }
  }

  String _authorizationToken() {
    final injected = _client;
    if (injected != null) {
      return injected.auth.currentSession?.accessToken ?? SupabaseService.anonKey;
    }

    try {
      return Supabase.instance.client.auth.currentSession?.accessToken ??
          SupabaseService.anonKey;
    } catch (_) {
      // Early boot/tests can legitimately have no global Supabase instance yet.
      // The edge function accepts the public anon JWT, so voice remains usable
      // as soon as networking is available instead of crashing the dashboard.
      return SupabaseService.anonKey;
    }
  }

  Future<String> transcribe(
    Uint8List bytes, {
    required String mimeType,
    String language = '',
  }) async {
    final url = Uri.parse(
      '${SupabaseService.supabaseUrl}/functions/v1/voice-transcribe',
    );
    final token = _authorizationToken();
    final requestedLanguage = language.trim();
    final payload = <String, Object>{
      'audio': base64Encode(bytes),
      'mimeType': mimeType,
    };
    if (requestedLanguage.isNotEmpty) {
      payload['language'] = requestedLanguage;
    }

    late http.Response resp;
    try {
      resp = await _http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'apikey': SupabaseService.anonKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw VoiceTranscribeException('Network error — check your connection');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw VoiceTranscribeException(
        'Voice transcription failed — please try again',
      );
    }
    try {
      final data = jsonDecode(resp.body);
      if (data is Map && data['text'] is String) {
        return (data['text'] as String).trim();
      }
    } catch (_) {}
    return resp.body.trim();
  }

  Future<Uint8List> _readBytes(String path) {
    return XFile(path).readAsBytes();
  }

  static String _mimeFor(String path) {
    if (kIsWeb) return 'audio/wav';
    final lower = path.toLowerCase();
    if (lower.contains('.wav')) return 'audio/wav';
    if (lower.contains('.mp4') || lower.contains('.m4a')) return 'audio/mp4';
    if (lower.contains('.ogg')) return 'audio/ogg';
    if (lower.contains('.mp3')) return 'audio/mpeg';
    return 'audio/webm';
  }
}

class VoiceTranscribeException implements Exception {
  VoiceTranscribeException(this.message);
  final String message;
  @override
  String toString() => message;
}
