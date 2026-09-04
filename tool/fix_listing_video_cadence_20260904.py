from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        print(f"{label}: already applied")
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    p.write_text(text.replace(old, new, 1))
    print(f"{label}: patched")


replace_once(
    "api/video-transcode.js",
    """    '-vf',
    'scale=1280:1280:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1,fps=30',
    '-r',
    '30',
""",
    """    '-vf',
    'scale=1280:1280:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1',
""",
    "progressive source cadence",
)

replace_once(
    "lib/src/features/camera/presentation/screens/video_cropper_screen_v2.dart",
    "  bool _portraitCrop = true;\n",
    "  bool _portraitCrop = false;\n",
    "non-destructive default fit",
)

replace_once(
    "lib/src/features/camera/presentation/screens/video_cropper_screen_v2.dart",
    """      await _player?.pause();
      await _soundtrack.stop();
      await _uploadedMusic.pause();
      final output = await recutVideoWindowV2(
""",
    """      await _player?.pause();
      await _soundtrack.stop();
      await _uploadedMusic.pause();

      // On web/PWA, selecting a normal video must never silently re-record
      // it through canvas.captureStream/MediaRecorder. That browser export
      // can collapse real motion cadence before the backend ever sees the
      // file. If the user did not actually trim/crop/mute/mix anything,
      // return the exact selected source and let the backend create the
      // lightweight delivery rendition. Portrait presentation is handled
      // by the card's BoxFit.cover and does not require destructive pixels.
      final noTrim =
          _selection.start <= .03 &&
          (_duration - _selection.end).abs() <= .08;
      final canUseSourceDirectly =
          kIsWeb &&
          noTrim &&
          !_portraitCrop &&
          _music == null &&
          _musicPreset == null &&
          _videoAudioEnabled &&
          widget.videoAudioEnabled;
      if (canUseSourceDirectly) {
        if (mounted) Navigator.pop(context, widget.file);
        return;
      }

      final output = await recutVideoWindowV2(
""",
    "web no-op editor passthrough",
)
