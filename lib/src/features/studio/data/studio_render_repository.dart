import 'dart:async';

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

  Map<String, dynamic> _renderBody({
    required String action,
    required List<String> imageUrls,
    required StudioProject project,
    required CinematicTemplate template,
  }) {
    return <String, dynamic>{
      'action': action,
      'image_urls': imageUrls,
      'project': project.toJson(),
      'template': template.toRenderJson(
        photoCount: imageUrls.length,
        focalPoints: project.focalPoints,
      ),
    };
  }

  Future<bool> _publicObjectReady(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;

    // A cache-busting query is important here: the public Storage URL can be
    // probed before the renderer uploads the file, and a CDN must not keep that
    // first 404 around while Studio waits for the finished movie.
    final probe = uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        '_studio_probe': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );

    try {
      final response = await http
          .head(
            probe,
            headers: const <String, String>{
              'cache-control': 'no-cache, no-store',
              'pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) return true;

      // Some storage/CDN combinations reject HEAD. Fall back to a one-byte
      // range request rather than ever downloading the whole MP4 just to test
      // whether it exists.
      if (response.statusCode == 405 || response.statusCode == 501) {
        final ranged = await http
            .get(
              probe,
              headers: const <String, String>{
                'range': 'bytes=0-0',
                'cache-control': 'no-cache, no-store',
                'pragma': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 6));
        return ranged.statusCode == 200 || ranged.statusCode == 206;
      }
    } catch (_) {
      // Rendering can still be in progress. The bounded poll below retries.
    }
    return false;
  }

  Future<void> _waitForRealMp4(
    String videoUrl, {
    Duration timeout = const Duration(minutes: 2, seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _publicObjectReady(videoUrl)) return;
      await Future<void>.delayed(const Duration(milliseconds: 1800));
    }
    throw Exception(
      'Studio started the video render, but the real MP4 never became ready. '
      'Please retry — your photos are still here.',
    );
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

    // The browser no longer owns FFmpeg execution. Asking Supabase to start the
    // render lets the Edge function call the server renderer from server to
    // server, avoiding the CORS/404/500 browser-worker handoff that repeatedly
    // made Studio appear to work while no movie was actually created.
    final response = await _client.functions
        .invoke(
          'studio-render',
          body: _renderBody(
            action: 'render',
            imageUrls: imageUrls,
            project: project,
            template: template,
          ),
        )
        .timeout(const Duration(seconds: 30));

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        _mapError(response.data) ??
            'Studio could not start the real MP4 render. Please retry.',
      );
    }

    final data = response.data;
    if (data is! Map || data['ok'] != true) {
      throw Exception(
        _mapError(data) ?? 'Studio returned an invalid render response.',
      );
    }

    final videoUrl = data['video_url']?.toString().trim() ?? '';
    final posterUrl = data['poster_url']?.toString().trim();
    if (videoUrl.isEmpty) {
      throw Exception('Studio did not return a destination for the real MP4.');
    }

    // Critical contract: NEVER tell the composer that rendering succeeded just
    // because a future Storage URL was allocated. Wait until that URL physically
    // serves bytes. Only then may the real video player / USE THIS REAL VIDEO UI
    // appear and only then may Publish reuse it.
    await _waitForRealMp4(videoUrl);

    return StudioRenderResult(
      videoUrl: videoUrl,
      posterUrl: posterUrl == null || posterUrl.isEmpty ? null : posterUrl,
      durationSeconds:
          (data['duration_seconds'] as num?)?.toDouble() ??
          template.totalDurationFor(imageUrls.length),
    );
  }

  /// Best-effort cleanup for a Studio render that never became a live listing.
  /// The Edge Function revalidates the signed-in owner and generated path.
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
