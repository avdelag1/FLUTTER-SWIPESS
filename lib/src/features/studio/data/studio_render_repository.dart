import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/studio/data/cinematic_catalog.dart';
import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final studioRenderRepositoryProvider = Provider<StudioRenderRepository>((ref) {
  return StudioRenderRepository();
});

class StudioRenderResult {
  const StudioRenderResult({
    required this.videoUrl,
    this.posterUrl,
    required this.durationSeconds,
  });

  final String videoUrl;
  final String? posterUrl;
  final double durationSeconds;
}

class StudioRenderRepository {
  StudioRenderRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? _mapError(dynamic data) {
    if (data is! Map) return null;
    final value = data['error']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<http.Response> _postWorker(String url, Map payload) {
    return http
        .post(
          Uri.parse(url),
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(Map<String, dynamic>.from(payload)),
        )
        .timeout(const Duration(minutes: 4));
  }

  Future<StudioRenderResult> render({
    required List<String> imageUrls,
    required StudioProject project,
  }) async {
    if (imageUrls.length < 3 || imageUrls.length > 6) {
      throw Exception('Studio needs 3 to 6 photos.');
    }
    if (_client.auth.currentUser == null) {
      throw Exception('Sign in again before generating a Studio video.');
    }

    final template = CinematicCatalog.byId(project.templateId);
    if (template.id != project.templateId ||
        template.version != project.templateVersion) {
      throw Exception('This Studio template changed. Choose it again.');
    }

    final prepare = await _client.functions
        .invoke(
          'studio-render',
          body: <String, dynamic>{
            'action': 'prepare',
            'image_urls': imageUrls,
            'project': project.toJson(),
            'template': template.toRenderJson(
              photoCount: imageUrls.length,
              focalPoints: project.focalPoints,
            ),
          },
        )
        .timeout(const Duration(seconds: 30));

    if (prepare.status < 200 || prepare.status >= 300) {
      throw Exception(
        _mapError(prepare.data) ??
            'Studio could not prepare the video render. Please retry.',
      );
    }

    final prepared = prepare.data;
    if (prepared is! Map) {
      throw Exception('Studio returned an invalid render preparation.');
    }

    final workerUrl = prepared['worker_url']?.toString().trim() ?? '';
    final workerPayload = prepared['worker_payload'];
    final videoUrl = prepared['video_url']?.toString().trim() ?? '';
    final posterUrl = prepared['poster_url']?.toString().trim();
    if (workerUrl.isEmpty || workerPayload is! Map || videoUrl.isEmpty) {
      throw Exception('Studio render preparation was incomplete. Please retry.');
    }

    late http.Response workerResponse;
    try {
      workerResponse = await _postWorker(workerUrl, workerPayload);

      // Older production deployments may not yet expose the browser-only
      // /api/studio-render-client alias. If that alias 404s, retry the already
      // deployed renderer endpoint instead of failing the listing publish.
      if (workerResponse.statusCode == 404 &&
          workerUrl.contains('/api/studio-render-client')) {
        final fallbackUrl = workerUrl.replaceFirst(
          '/api/studio-render-client',
          '/api/studio-render',
        );
        workerResponse = await _postWorker(fallbackUrl, workerPayload);
      }
    } on TimeoutException {
      throw Exception(
        'Studio video took too long to render. Please retry — your photos are still here.',
      );
    } catch (error) {
      throw Exception('Studio renderer connection failed. Please retry. ($error)');
    }

    dynamic workerData;
    try {
      workerData = jsonDecode(workerResponse.body);
    } catch (_) {
      workerData = null;
    }

    if (workerResponse.statusCode < 200 ||
        workerResponse.statusCode >= 300 ||
        workerData is! Map ||
        workerData['ok'] != true) {
      final message = _mapError(workerData);
      throw Exception(
        message ??
            'Studio renderer failed (${workerResponse.statusCode}). Please retry.',
      );
    }

    return StudioRenderResult(
      videoUrl: videoUrl,
      posterUrl: posterUrl == null || posterUrl.isEmpty ? null : posterUrl,
      durationSeconds:
          (workerData['duration_seconds'] as num?)?.toDouble() ??
          (prepared['duration_seconds'] as num?)?.toDouble() ??
          template.totalDurationFor(imageUrls.length),
    );
  }

  /// Best-effort cleanup for a Studio render that never became a live listing.
  /// The Edge Function revalidates the signed-in owner and the generated path,
  /// so a client cannot use this to delete another user's media.
  Future<void> cleanup(StudioRenderResult render) async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.functions.invoke(
        'studio-render',
        body: <String, dynamic>{
          'action': 'cleanup',
          'video_url': render.videoUrl,
          'poster_url': render.posterUrl,
        },
      );
    } catch (_) {
      // Cleanup must never hide the original listing publish error.
    }
  }
}
