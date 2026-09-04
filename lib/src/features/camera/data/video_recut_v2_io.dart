import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';
import 'package:image_picker/image_picker.dart';

const MethodChannel _videoOptimizer = MethodChannel('swipess/video_optimizer');

/// Exports a delivery-grade listing clip on iOS/Android.
///
/// The previous implementation tried to launch a system `ffmpeg` executable.
/// Phones do not ship that binary, so production builds silently returned the
/// original HEVC/MOV camera file. The native bridges now transcode through
/// AVFoundation (iOS) / Media3 Transformer (Android) to a network-friendly MP4.
Future<XFile> recutVideoWindowV2({
  required XFile source,
  required double start,
  required double end,
  bool portraitCrop = false,
  double cropX = 0.5,
  XFile? backgroundMusic,
  String? backgroundMusicPreset,
  double musicStart = 0,
  double? musicEnd,
  bool includeOriginalAudio = true,
}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return source;
  if (source.path.isEmpty || !File(source.path).existsSync()) return source;

  final startMs = (start.clamp(0.0, double.infinity) * 1000).round();
  final endMs = (end.clamp(start + .2, 60.0) * 1000).round();
  final musicStartMs = (musicStart.clamp(0.0, double.infinity) * 1000).round();
  final musicEndMs = musicEnd == null
      ? null
      : (musicEnd.clamp(musicStart + .05, double.infinity) * 1000).round();
  final musicPath = await _materializeNativeMusicPath(
    file: backgroundMusic,
    presetId: backgroundMusicPreset,
  );

  try {
    final response = await _videoOptimizer
        .invokeMapMethod<String, dynamic>('optimize', <String, dynamic>{
          'path': source.path,
          'startMs': startMs,
          'endMs': endMs,
          'portraitCrop': portraitCrop,
          'cropX': cropX.clamp(0.0, 1.0),
          'includeOriginalAudio': includeOriginalAudio,
          if (musicPath != null) 'musicPath': musicPath,
          'musicStartMs': musicStartMs,
          if (musicEndMs != null) 'musicEndMs': musicEndMs,
        });

    final path = response?['path']?.toString().trim() ?? '';
    if (path.isEmpty) return source;
    final output = File(path);
    if (!output.existsSync() || output.lengthSync() < 64) return source;

    return XFile(
      path,
      name: response?['name']?.toString().trim().isNotEmpty == true
          ? response!['name'].toString()
          : 'swipess-${DateTime.now().millisecondsSinceEpoch}.mp4',
      mimeType: 'video/mp4',
      length: output.lengthSync(),
    );
  } catch (_) {
    // Never destroy a user's selected media because one device cannot transcode
    // it. Upload can still continue with the source file as a safe fallback.
    return source;
  }
}

Future<String?> _materializeNativeMusicPath({
  XFile? file,
  String? presetId,
}) async {
  final path = file?.path.trim() ?? '';
  if (path.isNotEmpty && File(path).existsSync()) return path;

  final preset = presetId?.trim() ?? '';
  if (preset.isEmpty) {
    if (file == null) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final temp = File(
        '${Directory.systemTemp.path}/swipess_music_${DateTime.now().microsecondsSinceEpoch}.bin',
      );
      await temp.writeAsBytes(bytes, flush: true);
      return temp.path;
    } catch (_) {
      return null;
    }
  }

  try {
    final wav = buildListingSoundtrackWav(preset);
    final temp = File(
      '${Directory.systemTemp.path}/swipess_preset_$preset.wav',
    );
    await temp.writeAsBytes(wav, flush: true);
    return temp.path;
  } catch (_) {
    return null;
  }
}
