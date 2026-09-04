import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/studio/data/cinematic_catalog.dart';
import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';

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

    final response = await _client.functions.invoke(
      'studio-render',
      body: <String, dynamic>{
        'action': 'render',
        'image_urls': imageUrls,
        'project': project.toJson(),
        'template': template.toRenderJson(
          photoCount: imageUrls.length,
          focalPoints: project.focalPoints,
        ),
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final message = response.data is Map
          ? (response.data as Map)['error']?.toString()
          : null;
      throw Exception(
        message == null || message.trim().isEmpty
            ? 'Studio render failed. Please try again.'
            : message,
      );
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('Studio returned an invalid render response.');
    }
    final videoUrl = data['video_url']?.toString().trim() ?? '';
    if (videoUrl.isEmpty) {
      throw Exception('Studio finished without a playable video URL.');
    }
    final posterUrl = data['poster_url']?.toString().trim();
    return StudioRenderResult(
      videoUrl: videoUrl,
      posterUrl: posterUrl == null || posterUrl.isEmpty ? null : posterUrl,
      durationSeconds:
          (data['duration_seconds'] as num?)?.toDouble() ??
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
