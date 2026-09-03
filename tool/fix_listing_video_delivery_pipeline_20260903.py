from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    s = p.read_text()
    if new in s:
        print(f"already applied: {label}")
        return
    if old not in s:
        raise SystemExit(f"missing anchor for {label}: {path}")
    p.write_text(s.replace(old, new, 1))
    print(f"patched: {label}")


# 1) Do not needlessly canvas-reencode an already portable MP4 on web/PWA.
# Raw camera MP4s have stable source timestamps/keyframes and are generally much
# smoother than a real-time MediaRecorder re-recording. Keep the 48 MB ceiling
# so the repository's 50 MB upload limit still has headroom.
replace_once(
    "lib/src/features/camera/data/video_upload_optimizer_html.dart",
    """  if (alreadyOptimized && _isApplePlayableVideo(source)) return source;\n\n  try {\n""",
    """  final sourceMime = source.mimeType?.trim().toLowerCase() ?? '';\n  final sourceIsMp4 = sourceMime == 'video/mp4' || lowerName.endsWith('.mp4');\n  if (sourceIsMp4) {\n    final sourceBytes = await source.length();\n    if (sourceBytes > 0 && sourceBytes <= 48 * 1024 * 1024) {\n      // Preserve the original frame cadence/keyframes. This is the same reason\n      // the Events videos feel fluid: a good MP4 should not be re-recorded in\n      // real time just to upload it.\n      return source;\n    }\n  }\n\n  if (alreadyOptimized && _isApplePlayableVideo(source)) return source;\n\n  try {\n""",
    "web mp4 passthrough",
)

# 2) The browser fallback still needs to crop/transcode MOV/WebM sources. Paint
# the canvas on requestAnimationFrame instead of a Dart Timer. Timer jitter under
# Safari/Chrome load was baked into the exported movie as visible stutter.
replace_once(
    "lib/src/features/camera/data/video_recut_v3_html.dart",
    "  Timer? paintTimer;\n",
    "  int? paintFrameId;\n",
    "browser frame scheduler field",
)
replace_once(
    "lib/src/features/camera/data/video_recut_v3_html.dart",
    """    paintFrame();\n    paintTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => paintFrame());\n    exportStream = canvas.captureStream(30);\n""",
    """    paintFrame();\n    late void Function(num) schedulePaint;\n    schedulePaint = (num _) {\n      paintFrame();\n      paintFrameId = html.window.requestAnimationFrame(schedulePaint);\n    };\n    paintFrameId = html.window.requestAnimationFrame(schedulePaint);\n    exportStream = canvas.captureStream(30);\n""",
    "browser requestAnimationFrame export",
)
replace_once(
    "lib/src/features/camera/data/video_recut_v3_html.dart",
    """    video.pause();\n    paintTimer?.cancel();\n    if (recorder.state != 'inactive') recorder.stop();\n""",
    """    video.pause();\n    if (paintFrameId != null) html.window.cancelAnimationFrame(paintFrameId!);\n    paintFrameId = null;\n    if (recorder.state != 'inactive') recorder.stop();\n""",
    "browser stop frame scheduler",
)
replace_once(
    "lib/src/features/camera/data/video_recut_v3_html.dart",
    """  } finally {\n    paintTimer?.cancel();\n""",
    """  } finally {\n    if (paintFrameId != null) html.window.cancelAnimationFrame(paintFrameId!);\n    paintFrameId = null;\n""",
    "browser cleanup frame scheduler",
)

# 3) Every native listing upload is capped at 60 s. This prevents a 2-5 minute
# camera file from becoming a huge progressive download for every dashboard.
replace_once(
    "lib/src/features/camera/data/video_upload_optimizer_io.dart",
    """        // -1 means full source duration. The native bridges clamp safely.\n        'endMs': -1,\n""",
    """        // Delivery clips are capped at 60 seconds. The native bridges\n        // clamp this to the real source duration when the clip is shorter.\n        'endMs': 60000,\n""",
    "native 60 second cap",
)

# 4) iOS must create a delivery-sized 720p MP4, not HighestQuality. The render
# canvas remains 720x1280 portrait and shouldOptimizeForNetworkUse keeps the
# moov atom at the front for progressive playback.
replace_once(
    "ios/Runner/AppDelegate.swift",
    "    let preset = portraitCrop ? AVAssetExportPresetHighestQuality : AVAssetExportPreset1280x720\n",
    "    let preset = AVAssetExportPreset1280x720\n",
    "ios delivery preset",
)

# 5) Old/low-memory iPhones should never decode four listing previews plus the
# Events teaser at once. Only one web/PWA listing preview gets a decoder warmup;
# native can keep two. The user-selected card still evicts an idle warm preview.
replace_once(
    "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart",
    "  static int get maxActive => 4;\n",
    "  static int get maxActive => kIsWeb ? 1 : 2;\n",
    "quick filter decoder budget",
)

print("listing video delivery pipeline hardening complete")
