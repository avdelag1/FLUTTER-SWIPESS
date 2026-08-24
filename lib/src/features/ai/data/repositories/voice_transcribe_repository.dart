import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
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

/// Cap `useVoiceTranscribe` — MediaRecorder / `record`, then `voice-transcribe`.
class VoiceTranscribeRepository {
  VoiceTranscribeRepository({
    AudioRecorder? recorder,
    http.Client? httpClient,
    SupabaseClient? client,
  }) : _recorder = recorder ?? AudioRecorder(),
       _http = httpClient ?? http.Client(),
       _client = client ?? Supabase.instance.client;

  final AudioRecorder _recorder;
  final http.Client _http;
  final SupabaseClient _client;

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
    await _recorder.start(
      const RecordConfig(numChannels: 1, sampleRate: 16000),
      path: 'swipess_voice.m4a',
    );
    return true;
  }

  Future<String> stop({String language = 'en-US'}) async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) return '';
    final bytes = await _readBytes(path);
    if (bytes.length < 800) {
      throw VoiceTranscribeException(
        'Recording too short — please speak longer',
      );
    }
    return transcribe(bytes, mimeType: _mimeFor(path), language: language);
  }

  Future<void> cancel() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<String> transcribe(
    Uint8List bytes, {
    required String mimeType,
    String language = 'en-US',
  }) async {
    final url = Uri.parse(
      '${SupabaseService.supabaseUrl}/functions/v1/voice-transcribe',
    );
    final token =
        _client.auth.currentSession?.accessToken ?? SupabaseService.anonKey;
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
            body: jsonEncode({
              'audio': base64Encode(bytes),
              'mimeType': mimeType,
              'language': language,
            }),
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
