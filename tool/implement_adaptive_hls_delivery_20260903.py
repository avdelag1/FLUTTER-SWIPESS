from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)

# ---------------------------------------------------------------------------
# Vercel FFmpeg worker: progressive MP4 remains authoritative fallback; HLS is
# best-effort and is published only after the MP4 job is already ready.
# ---------------------------------------------------------------------------
worker = Path('api/video-transcode.js')
text = worker.read_text()
text = replace_once(
    text,
    "import { readFile, rm, stat } from 'node:fs/promises';",
    "import { mkdtemp, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises';",
    'worker fs imports',
)
text = replace_once(
    text,
    "const PIPELINE_URL = `https://${PROJECT_HOST}/functions/v1/video-pipeline`;\n",
    "const PIPELINE_URL = `https://${PROJECT_HOST}/functions/v1/video-pipeline`;\n"
    "const HLS_CONTROL_URL = `https://${PROJECT_HOST}/functions/v1/video-hls-control`;\n",
    'worker HLS control URL',
)

insert_anchor = "async function uploadSigned(storage, bucket, path, token, bytes, contentType) {\n"
hls_helpers = r'''async function makeHlsVariant(videoPath, hlsDir, config) {
  const playlistPath = join(hlsDir, `${config.name}.m3u8`);
  const segmentPattern = join(hlsDir, `${config.name}_%03d.ts`);
  await runFfmpeg([
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    videoPath,
    '-map',
    '0:v:0',
    '-map',
    '0:a:0?',
    '-vf',
    `scale=${config.box}:${config.box}:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1,fps=30`,
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-profile:v',
    'main',
    '-pix_fmt',
    'yuv420p',
    '-b:v',
    config.videoBitrate,
    '-maxrate',
    config.maxRate,
    '-bufsize',
    config.bufferSize,
    '-g',
    '60',
    '-keyint_min',
    '60',
    '-sc_threshold',
    '0',
    '-c:a',
    'aac',
    '-b:a',
    config.audioBitrate,
    '-ar',
    '48000',
    '-ac',
    '2',
    '-hls_time',
    '2',
    '-hls_playlist_type',
    'vod',
    '-hls_flags',
    'independent_segments',
    '-hls_segment_filename',
    segmentPattern,
    playlistPath,
  ], 240000);
}

async function makeAdaptiveHls(videoPath, hlsDir) {
  const variants = [
    {
      name: '360',
      box: 640,
      videoBitrate: '600k',
      maxRate: '750k',
      bufferSize: '1200k',
      audioBitrate: '64k',
    },
    {
      name: '540',
      box: 960,
      videoBitrate: '1250k',
      maxRate: '1550k',
      bufferSize: '2500k',
      audioBitrate: '96k',
    },
    {
      name: '720',
      box: 1280,
      videoBitrate: '2400k',
      maxRate: '2900k',
      bufferSize: '4800k',
      audioBitrate: '128k',
    },
  ];

  // Encode sequentially. This deliberately trades a few seconds of background
  // processing for bounded CPU/RAM so several uploads cannot thrash the worker.
  for (const variant of variants) {
    await makeHlsVariant(videoPath, hlsDir, variant);
  }

  const master = [
    '#EXTM3U',
    '#EXT-X-VERSION:3',
    '#EXT-X-INDEPENDENT-SEGMENTS',
    '#EXT-X-STREAM-INF:BANDWIDTH=750000,AVERAGE-BANDWIDTH=650000',
    '360.m3u8',
    '#EXT-X-STREAM-INF:BANDWIDTH=1500000,AVERAGE-BANDWIDTH=1350000',
    '540.m3u8',
    '#EXT-X-STREAM-INF:BANDWIDTH=2900000,AVERAGE-BANDWIDTH=2550000',
    '720.m3u8',
    '',
  ].join('\n');
  await writeFile(join(hlsDir, 'master.m3u8'), master, 'utf8');
}

async function publishAdaptiveHls({ jobId, token, hlsDir }) {
  const names = (await readdir(hlsDir)).filter(
    (name) => name.endsWith('.m3u8') || name.endsWith('.ts'),
  ).sort();
  if (!names.includes('master.m3u8')) throw new Error('hls_master_missing');

  const files = [];
  let totalSize = 0;
  for (const name of names) {
    const bytes = await readFile(join(hlsDir, name));
    totalSize += bytes.length;
    files.push({ name, bytes });
  }

  const authorization = await postPipeline(HLS_CONTROL_URL, {
    action: 'authorize',
    job_id: jobId,
    token,
    files: files.map((file) => ({ name: file.name })),
  });

  const storageUrl = String(authorization.storage_url ?? '');
  const storageKey = String(authorization.storage_anon_key ?? '');
  const bucket = String(authorization.bucket ?? '');
  const uploads = Array.isArray(authorization.uploads) ? authorization.uploads : [];
  const parsedStorage = new URL(storageUrl);
  if (parsedStorage.protocol !== 'https:' || parsedStorage.host !== PROJECT_HOST) {
    throw new Error('hls_storage_host_not_allowed');
  }
  if (!storageKey || bucket !== 'listing-videos') {
    throw new Error('invalid_hls_storage_authorization');
  }

  const signedByName = new Map(uploads.map((item) => [String(item.name), item]));
  const supabase = createClient(storageUrl, storageKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Upload in small groups: enough parallelism for segments without exploding
  // sockets/memory when several listings are processing at once.
  for (let offset = 0; offset < files.length; offset += 6) {
    const batch = files.slice(offset, offset + 6);
    await Promise.all(batch.map(async (file) => {
      const signed = signedByName.get(file.name);
      if (!signed?.path || !signed?.token || !signed?.content_type) {
        throw new Error(`missing_hls_upload:${file.name}`);
      }
      await uploadSigned(
        supabase.storage,
        bucket,
        String(signed.path),
        String(signed.token),
        file.bytes,
        String(signed.content_type),
      );
    }));
  }

  await postPipeline(HLS_CONTROL_URL, {
    action: 'complete',
    job_id: jobId,
    token,
    total_size_bytes: totalSize,
    output_count: files.length,
  });
}

'''
text = replace_once(text, insert_anchor, hls_helpers + insert_anchor, 'worker HLS helpers')

text = replace_once(
    text,
    "  const posterPath = join(tmpdir(), `swipess-poster-${tempId}.jpg`);\n\n  try {\n",
    "  const posterPath = join(tmpdir(), `swipess-poster-${tempId}.jpg`);\n"
    "  let hlsDir = null;\n"
    "  let progressiveCompleted = false;\n\n"
    "  try {\n"
    "    hlsDir = await mkdtemp(join(tmpdir(), 'swipess-hls-'));\n",
    'worker HLS temp directory',
)
text = replace_once(
    text,
    "    await postPipeline(authorizeUrl, {\n      action: 'complete',\n      job_id: jobId,\n      token,\n      source_size_bytes: sourceSize,\n      output_size_bytes: videoInfo.size,\n    });\n",
    "    await postPipeline(authorizeUrl, {\n"
    "      action: 'complete',\n"
    "      job_id: jobId,\n"
    "      token,\n"
    "      source_size_bytes: sourceSize,\n"
    "      output_size_bytes: videoInfo.size,\n"
    "    });\n"
    "    progressiveCompleted = true;\n\n"
    "    // Adaptive output is additive. A transient HLS problem must never make\n"
    "    // the already-uploaded fast-start MP4 unavailable to the listing.\n"
    "    try {\n"
    "      await makeAdaptiveHls(outputPath, hlsDir);\n"
    "      await publishAdaptiveHls({ jobId, token, hlsDir });\n"
    "    } catch (hlsError) {\n"
    "      console.warn('[video-hls]', jobId, compactError(hlsError));\n"
    "    }\n",
    'worker HLS after progressive complete',
)
text = replace_once(
    text,
    "    try {\n      await postPipeline(authorizeUrl, {\n        action: 'fail',\n        job_id: jobId,\n        token,\n        error: message,\n      });\n    } catch (_) {\n      // The original failure is the useful error. A failed callback is visible\n      // in Vercel runtime logs and must not recursively retry from the worker.\n    }\n    console.error('[video-transcode]', jobId, message);\n",
    "    if (!progressiveCompleted) {\n"
    "      try {\n"
    "        await postPipeline(authorizeUrl, {\n"
    "          action: 'fail',\n"
    "          job_id: jobId,\n"
    "          token,\n"
    "          error: message,\n"
    "        });\n"
    "      } catch (_) {\n"
    "        // The original failure is the useful error. A failed callback is visible\n"
    "        // in runtime logs and must not recursively retry from the worker.\n"
    "      }\n"
    "    }\n"
    "    console.error('[video-transcode]', jobId, message);\n",
    'worker progressive failure isolation',
)
text = replace_once(
    text,
    "      rm(posterPath, { force: true }).catch(() => {}),\n    ]);\n",
    "      rm(posterPath, { force: true }).catch(() => {}),\n"
    "      hlsDir\n"
    "        ? rm(hlsDir, { recursive: true, force: true }).catch(() => {})\n"
    "        : Promise.resolve(),\n"
    "    ]);\n",
    'worker HLS cleanup',
)
worker.write_text(text)

# ---------------------------------------------------------------------------
# Listing model and playback URL selection. Native players and WebKit can use
# HLS natively; Chrome/Firefox web retain the fast-start MP4 fallback.
# ---------------------------------------------------------------------------
model = Path('lib/src/features/swipes/domain/models/listing.dart')
text = model.read_text()
text = replace_once(text, "  final String? videoUrl;\n", "  final String? videoUrl;\n  final String? videoHlsUrl;\n", 'listing hls field')
text = replace_once(text, "    this.videoUrl,\n", "    this.videoUrl,\n    this.videoHlsUrl,\n", 'listing hls constructor')
text = replace_once(
    text,
    "      videoUrl: json['video_url'] as String?,\n",
    "      videoUrl: json['video_url'] as String?,\n      videoHlsUrl: json['video_hls_url'] as String?,\n",
    'listing hls json',
)
getter_anchor = "  bool get hasBackgroundMusicMetadata =>\n"
getter = r'''  String? get preferredVideoUrl {
    final mp4 = videoUrl?.trim();
    final hls = videoHlsUrl?.trim();
    final nativeHls = !kIsWeb;
    final webkitHls =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if ((nativeHls || webkitHls) && hls != null && hls.isNotEmpty) {
      return hls;
    }
    return mp4 == null || mp4.isEmpty ? null : mp4;
  }

'''
text = replace_once(text, getter_anchor, getter + getter_anchor, 'listing preferred video getter')
model.write_text(text)

repo = Path('lib/src/features/swipes/data/repositories/listing_repository.dart')
text = repo.read_text()
text = replace_once(
    text,
    "    id, title, description, price, images, video_url,\n",
    "    id, title, description, price, images, video_url, video_hls_url,\n",
    'swipe fields hls',
)
repo.write_text(text)

# Dashboard quick filters prefer HLS where supported and recognize m3u8 media.
bento = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
text = bento.read_text()
text = replace_once(
    text,
    "      final video = (listing.videoUrl ?? '').trim();\n",
    "      final video = (listing.preferredVideoUrl ?? '').trim();\n",
    'dashboard preferred video',
)
bento.write_text(text)

quick = Path('lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart')
text = quick.read_text()
text = replace_once(
    text,
    "      lower.contains('.m4v') ||\n      lower.contains('/videos/');\n",
    "      lower.contains('.m4v') ||\n      lower.contains('.m3u8') ||\n      lower.contains('/videos/');\n",
    'quick filter m3u8 recognition',
)
quick.write_text(text)

# Full swipe card: HLS selection + playback telemetry.
cap = Path('lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart')
text = cap.read_text()
text = replace_once(
    text,
    "import 'package:flutter_swipes/src/core/performance/video_predictive_prefetch.dart';\n",
    "import 'package:flutter_swipes/src/core/performance/video_playback_telemetry.dart';\n"
    "import 'package:flutter_swipes/src/core/performance/video_predictive_prefetch.dart';\n",
    'cap telemetry import',
)
text = replace_once(
    text,
    "  String? _boundVideo;\n",
    "  String? _boundVideo;\n"
    "  VideoPlayerController? _telemetryPlayer;\n"
    "  String? _telemetrySessionId;\n"
    "  String? _telemetryUrl;\n"
    "  DateTime? _initStartedAt;\n"
    "  DateTime? _playRequestedAt;\n"
    "  DateTime? _bufferStartedAt;\n"
    "  bool _firstFrameReported = false;\n"
    "  bool _wasBuffering = false;\n"
    "  bool _telemetryErrorReported = false;\n"
    "  int _rebufferCount = 0;\n",
    'cap telemetry fields',
)
text = replace_once(
    text,
    "    final video = widget.listing.videoUrl;\n",
    "    final video = widget.listing.preferredVideoUrl;\n",
    'cap preferred media',
)
text = replace_once(
    text,
    "    final explicit = widget.listing.videoUrl?.trim();\n",
    "    final explicit = widget.listing.preferredVideoUrl?.trim();\n",
    'cap preferred explicit video',
)
text = replace_once(
    text,
    "        l.contains('.m4v') ||\n        l.contains('/videos/');\n",
    "        l.contains('.m4v') ||\n        l.contains('.m3u8') ||\n        l.contains('/videos/');\n",
    'cap m3u8 recognition',
)
cap_helper_anchor = "  void _disposeVideo() {\n"
cap_helpers = r'''  void _beginVideoTelemetry(String url) {
    if (_telemetrySessionId != null && _telemetryUrl == url) return;
    _telemetrySessionId = VideoPlaybackTelemetry.newSessionId();
    _telemetryUrl = url;
    _initStartedAt = null;
    _playRequestedAt = null;
    _bufferStartedAt = null;
    _firstFrameReported = false;
    _wasBuffering = false;
    _telemetryErrorReported = false;
    _rebufferCount = 0;
  }

  void _emitVideoTelemetry(
    String eventType, {
    int? initMs,
    int? ttffMs,
    int? bufferMs,
    int? positionMs,
    int? durationMs,
    String? errorCode,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    final session = _telemetrySessionId;
    final url = _telemetryUrl;
    if (session == null || url == null) return;
    VideoPlaybackTelemetry.emit(
      sessionId: session,
      eventType: eventType,
      surface: 'swipe_deck',
      listingId: widget.listing.id,
      mediaUrl: url,
      initMs: initMs,
      ttffMs: ttffMs,
      bufferMs: bufferMs,
      rebufferCount: _rebufferCount,
      positionMs: positionMs,
      durationMs: durationMs,
      errorCode: errorCode,
      extra: <String, Object?>{
        'category': widget.listing.category,
        'is_top': widget.isTop,
        'adaptive_hls': url.toLowerCase().contains('.m3u8'),
        ...extra,
      },
    );
  }

  void _attachVideoTelemetry(VideoPlayerController player) {
    if (identical(_telemetryPlayer, player)) return;
    _telemetryPlayer?.removeListener(_onVideoTelemetryTick);
    _telemetryPlayer = player;
    player.removeListener(_onVideoTelemetryTick);
    player.addListener(_onVideoTelemetryTick);
  }

  void _detachVideoTelemetry(VideoPlayerController? player) {
    player?.removeListener(_onVideoTelemetryTick);
    if (identical(_telemetryPlayer, player)) _telemetryPlayer = null;
  }

  void _onVideoTelemetryTick() {
    final player = _telemetryPlayer;
    if (player == null) return;
    final value = player.value;
    final now = DateTime.now();
    final positionMs = value.position.inMilliseconds;
    final durationMs = value.duration.inMilliseconds;

    if (value.hasError && !_telemetryErrorReported) {
      _telemetryErrorReported = true;
      _emitVideoTelemetry(
        'playback_error',
        positionMs: positionMs,
        durationMs: durationMs,
        errorCode: value.errorDescription ?? 'video_player_error',
      );
    }

    if (!_firstFrameReported &&
        widget.isTop &&
        value.isPlaying &&
        positionMs > 0 &&
        _playRequestedAt != null) {
      _firstFrameReported = true;
      _emitVideoTelemetry(
        'first_frame',
        ttffMs: now.difference(_playRequestedAt!).inMilliseconds,
        positionMs: positionMs,
        durationMs: durationMs,
      );
    }

    if (value.isBuffering && !_wasBuffering && _firstFrameReported) {
      _bufferStartedAt = now;
    } else if (!value.isBuffering && _wasBuffering && _bufferStartedAt != null) {
      _rebufferCount += 1;
      _emitVideoTelemetry(
        'rebuffer',
        bufferMs: now.difference(_bufferStartedAt!).inMilliseconds,
        positionMs: positionMs,
        durationMs: durationMs,
      );
      _bufferStartedAt = null;
    }
    _wasBuffering = value.isBuffering;
  }

  void _resetVideoTelemetry() {
    _telemetryPlayer?.removeListener(_onVideoTelemetryTick);
    _telemetryPlayer = null;
    _telemetrySessionId = null;
    _telemetryUrl = null;
    _initStartedAt = null;
    _playRequestedAt = null;
    _bufferStartedAt = null;
    _firstFrameReported = false;
    _wasBuffering = false;
    _telemetryErrorReported = false;
    _rebufferCount = 0;
  }

'''
text = replace_once(text, cap_helper_anchor, cap_helpers + cap_helper_anchor, 'cap telemetry helpers')
text = replace_once(
    text,
    "    final player = _video;\n    _video = null;\n",
    "    final player = _video;\n    _detachVideoTelemetry(player);\n    _video = null;\n",
    'cap detach telemetry on dispose',
)
text = replace_once(
    text,
    "    unawaited(_soundtrack.stop());\n    if (player == null) return;\n",
    "    unawaited(_soundtrack.stop());\n"
    "    _resetVideoTelemetry();\n"
    "    if (player == null) return;\n",
    'cap telemetry reset on dispose',
)
text = replace_once(
    text,
    "    await _SwipeCardPlaybackCoordinator.activate(this);\n\n    final soundOn = ref.read(deckSoundOnProvider);\n",
    "    await _SwipeCardPlaybackCoordinator.activate(this);\n"
    "    _playRequestedAt ??= DateTime.now();\n\n"
    "    final soundOn = ref.read(deckSoundOnProvider);\n",
    'cap play request telemetry',
)
text = replace_once(
    text,
    "    _video = prepared;\n    _boundVideo = url;\n",
    "    _detachVideoTelemetry(previous);\n"
    "    _beginVideoTelemetry(url);\n"
    "    _video = prepared;\n"
    "    _boundVideo = url;\n"
    "    _playRequestedAt ??= DateTime.now();\n"
    "    _attachVideoTelemetry(prepared);\n",
    'cap adopted telemetry',
)
text = replace_once(
    text,
    "      await _applyPlaybackRole(prepared);\n      if (mounted) setState(() {});\n",
    "      await _applyPlaybackRole(prepared);\n"
    "      _onVideoTelemetryTick();\n"
    "      if (mounted) setState(() {});\n",
    'cap adopted first frame tick',
)
text = replace_once(
    text,
    "    final previous = _video;\n    if (previous != null) {\n",
    "    final previous = _video;\n"
    "    _detachVideoTelemetry(previous);\n"
    "    _beginVideoTelemetry(url);\n"
    "    _initStartedAt = DateTime.now();\n"
    "    if (previous != null) {\n",
    'cap fresh telemetry start',
)
text = replace_once(
    text,
    "      await next.initialize();\n      if (!mounted || !widget.isTop || _boundVideo != url) {\n",
    "      await next.initialize();\n"
    "      final initStarted = _initStartedAt;\n"
    "      if (initStarted != null) {\n"
    "        _emitVideoTelemetry(\n"
    "          'init',\n"
    "          initMs: DateTime.now().difference(initStarted).inMilliseconds,\n"
    "          durationMs: next.value.duration.inMilliseconds,\n"
    "        );\n"
    "        _initStartedAt = null;\n"
    "      }\n"
    "      if (!mounted || !widget.isTop || _boundVideo != url) {\n",
    'cap init metric',
)
text = replace_once(
    text,
    "      await next.setLooping(true);\n      await _applyPlaybackRole(next);\n",
    "      await next.setLooping(true);\n"
    "      _playRequestedAt = DateTime.now();\n"
    "      _attachVideoTelemetry(next);\n"
    "      await _applyPlaybackRole(next);\n"
    "      _onVideoTelemetryTick();\n",
    'cap attach fresh telemetry',
)
text = replace_once(
    text,
    "    } catch (_) {\n      if (mounted) setState(() {});\n    } finally {\n      await previous?.dispose();\n",
    "    } catch (error) {\n"
    "      if (!_telemetryErrorReported) {\n"
    "        _telemetryErrorReported = true;\n"
    "        _emitVideoTelemetry(\n"
    "          'playback_error',\n"
    "          errorCode: error.runtimeType.toString(),\n"
    "          extra: const <String, Object?>{'phase': 'initialize_or_play'},\n"
    "        );\n"
    "      }\n"
    "      if (mounted) setState(() {});\n"
    "    } finally {\n"
    "      await previous?.dispose();\n",
    'cap playback error telemetry',
)
cap.write_text(text)

# Swipe stack: keep dashboard controller handoff, but stop creating a second
# decoder for the next listing. Warm only the first 256 KB of exactly one URL.
stack = Path('lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart')
text = stack.read_text()
text = replace_once(
    text,
    "import 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
    "import 'package:flutter_swipes/src/core/performance/video_predictive_prefetch.dart';\n"
    "import 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
    'stack predictive prefetch import',
)
text = text.replace("  static const _videoPreloadAhead = 1;\n", "")
text = text.replace("  static const _videoPreloadBehind = 0;\n", "")
text = replace_once(
    text,
    "        l.contains('.m4v') ||\n        l.contains('/videos/');\n",
    "        l.contains('.m4v') ||\n        l.contains('.m3u8') ||\n        l.contains('/videos/');\n",
    'stack m3u8 recognition',
)
text = replace_once(
    text,
    "    final explicit = listing.videoUrl?.trim();\n",
    "    final explicit = listing.preferredVideoUrl?.trim();\n",
    'stack preferred video',
)
text = replace_once(
    text,
    "    final explicitVideo = listing.videoUrl?.trim();\n",
    "    final explicitVideo = listing.preferredVideoUrl?.trim();\n",
    'stack preferred hero exclusion',
)
start = text.index("  Future<void> _warmListingVideos(int generation) async {\n")
end = text.index("\n  int _normalize(int index) {", start)
new_warm = r'''  Future<void> _warmListingVideos(int generation) async {
    try {
      if (!mounted ||
          widget.listings.isEmpty ||
          generation != _videoWarmGeneration) {
        return;
      }

      // The map is now reserved only for a real dashboard -> deck controller
      // handoff. Predictive next-listing work must not allocate another decoder.
      final keep = <String>{};
      final currentId = _current.id;
      if (_preloadedVideos.containsKey(currentId)) keep.add(currentId);

      if (widget.listings.length > 1) {
        final nextListing = _relative(1);
        final nextUrl = _listingPrimaryVideo(nextListing);
        if (nextUrl != null && nextUrl.trim().isNotEmpty) {
          await VideoPredictivePrefetch.prefetchOne(
            url: nextUrl,
            listingId: nextListing.id,
            surface: 'swipe_stack',
          );
        }
      }

      if (!mounted || generation != _videoWarmGeneration) return;
      for (final id in _preloadedVideos.keys.toList()) {
        if (!keep.contains(id)) {
          _preloadedVideos.remove(id)?.dispose();
        }
      }
    } finally {
      _videoWarmInFlight = false;
      if (mounted &&
          widget.listings.isNotEmpty &&
          generation != _videoWarmGeneration) {
        _preloadListingVideos();
      }
    }
  }
'''
text = text[:start] + new_warm + text[end:]
stack.write_text(text)

# Other playback surfaces use adaptive HLS where supported.
detail = Path('lib/src/features/swipes/presentation/screens/listing_detail_screen.dart')
text = detail.read_text()
text = replace_once(
    text,
    "    final raw = listing.videoUrl?.trim();\n",
    "    final raw = listing.preferredVideoUrl?.trim();\n",
    'detail preferred video',
)
detail.write_text(text)

tours = Path('lib/src/features/video_tours/presentation/screens/video_tours_screen.dart')
text = tours.read_text()
text = replace_once(
    text,
    "    final url = widget.listing.videoUrl?.trim();\n",
    "    final url = widget.listing.preferredVideoUrl?.trim();\n",
    'video tours preferred video',
)
tours.write_text(text)

print('adaptive HLS, deck telemetry, and single-next network prefetch patch applied')
