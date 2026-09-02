import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

class ListingSoundtrackPreset {
  const ListingSoundtrackPreset({
    required this.id,
    required this.label,
    required this.emoji,
    required this.bestFor,
  });

  final String id;
  final String label;
  final String emoji;
  final String bestFor;
}

/// Original procedural Swipess soundscapes. They are synthesized locally rather
/// than bundling commercial songs, so the built-in library is safe to use on
/// listings without music licensing ambiguity.
const listingSoundtrackPresets = <ListingSoundtrackPreset>[
  ListingSoundtrackPreset(
    id: 'ocean',
    label: 'Ocean Waves',
    emoji: '🌊',
    bestFor: 'Stays · yachts · wellness',
  ),
  ListingSoundtrackPreset(
    id: 'chill',
    label: 'Chill Sunset',
    emoji: '🌅',
    bestFor: 'Homes · lifestyle · travel',
  ),
  ListingSoundtrackPreset(
    id: 'singing_bowl',
    label: 'Singing Bowl',
    emoji: '🔔',
    bestFor: 'Yoga · healing · retreats',
  ),
  ListingSoundtrackPreset(
    id: 'om_drone',
    label: 'Mantra Drone',
    emoji: '🕉️',
    bestFor: 'Spiritual · meditation',
  ),
  ListingSoundtrackPreset(
    id: 'jungle',
    label: 'Jungle Air',
    emoji: '🌿',
    bestFor: 'Tulum · nature · stays',
  ),
  ListingSoundtrackPreset(
    id: 'luxury',
    label: 'Luxury Lounge',
    emoji: '✨',
    bestFor: 'Villas · yachts · premium',
  ),
  ListingSoundtrackPreset(
    id: 'road',
    label: 'Road Pulse',
    emoji: '🏍️',
    bestFor: 'Motos · mobility · action',
  ),
  ListingSoundtrackPreset(
    id: 'workshop',
    label: 'Workshop Groove',
    emoji: '🛠️',
    bestFor: 'Workers · makers · services',
  ),
  ListingSoundtrackPreset(
    id: 'clean_ambient',
    label: 'Clean Ambient',
    emoji: '☁️',
    bestFor: 'Products · services · studios',
  ),
  ListingSoundtrackPreset(
    id: 'night_beach',
    label: 'Night Beach',
    emoji: '🌙',
    bestFor: 'Events · stays · nightlife',
  ),
];

ListingSoundtrackPreset? listingSoundtrackPresetById(String? id) {
  if (id == null || id.trim().isEmpty) return null;
  for (final preset in listingSoundtrackPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}

final Map<String, Uint8List> _wavCache = <String, Uint8List>{};

/// Builds a short seamless-enough PCM WAV loop for a built-in preset.
Uint8List buildListingSoundtrackWav(String presetId) {
  return _wavCache.putIfAbsent(presetId, () => _synthesize(presetId));
}

Uint8List _synthesize(String presetId) {
  const sampleRate = 16000;
  const seconds = 6;
  const channels = 1;
  const bitsPerSample = 16;
  final sampleCount = sampleRate * seconds;
  final dataLength = sampleCount * 2;
  final bytes = ByteData(44 + dataLength);

  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(
    28,
    sampleRate * channels * bitsPerSample ~/ 8,
    Endian.little,
  );
  bytes.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);

  final seed = presetId.codeUnits.fold<int>(71, (a, b) => a * 31 + b);
  final random = math.Random(seed);
  var smoothNoise = 0.0;

  double tone(double t, double hz) => math.sin(2 * math.pi * hz * t);
  double pulse(double t, double period, double decay) {
    final phase = t % period;
    return math.exp(-phase * decay);
  }

  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final rawNoise = random.nextDouble() * 2 - 1;
    smoothNoise = smoothNoise * .965 + rawNoise * .035;
    double sample;

    switch (presetId) {
      case 'ocean':
        final swell = .68 + .32 * tone(t, .11);
        sample = smoothNoise * .42 * swell + tone(t, 52) * .035;
      case 'chill':
        final breathe = .72 + .28 * tone(t, .18);
        sample =
            breathe *
            (.105 * tone(t, 196) +
                .08 * tone(t, 246.94) +
                .065 * tone(t, 293.66));
      case 'singing_bowl':
        final local = t % 3;
        final env = math.exp(-local * .72);
        sample = env * (.25 * tone(t, 432) + .075 * tone(t, 864));
      case 'om_drone':
        final breathe = .78 + .22 * tone(t, .08);
        sample = breathe * (.18 * tone(t, 136.1) + .075 * tone(t, 272.2));
      case 'jungle':
        final chirp = pulse(t, 1.7, 10) * tone(t, 720 + 90 * tone(t, .4));
        sample = smoothNoise * .16 + chirp * .10 + tone(t, 78) * .025;
      case 'luxury':
        final bass = pulse(t, .75, 12) * tone(t, 72);
        sample =
            bass * .14 +
            tone(t, 220) * .075 +
            tone(t, 277.18) * .055 +
            tone(t, 329.63) * .045;
      case 'road':
        final kick = pulse(t, .5, 18) * tone(t, 68);
        final tick = pulse(t + .25, .5, 32) * smoothNoise;
        sample = kick * .24 + tick * .10 + tone(t, 110) * .035;
      case 'workshop':
        final knock = pulse(t, .4, 24) * tone(t, 175);
        final offbeat = pulse(t + .2, .8, 30) * smoothNoise;
        sample = knock * .20 + offbeat * .13 + tone(t, 88) * .035;
      case 'night_beach':
        final swell = .70 + .30 * tone(t, .09);
        sample =
            smoothNoise * .25 * swell +
            tone(t, 164.81) * .07 +
            tone(t, 196) * .05 +
            tone(t, 246.94) * .035;
      case 'clean_ambient':
      default:
        final breathe = .70 + .30 * tone(t, .10);
        sample =
            smoothNoise * .07 +
            breathe * (.08 * tone(t, 261.63) + .055 * tone(t, 392));
    }

    // Short fades prevent a click when the generated six-second loop restarts.
    final fadeIn = (t / .08).clamp(0.0, 1.0);
    final remaining = seconds - t;
    final fadeOut = (remaining / .08).clamp(0.0, 1.0);
    final shaped = (sample * math.min(fadeIn, fadeOut)).clamp(-.92, .92);
    bytes.setInt16(44 + i * 2, (shaped * 32767).round(), Endian.little);
  }

  return bytes.buffer.asUint8List();
}

class ListingSoundtrackPlayer {
  final AudioPlayer _player = AudioPlayer();
  String? _key;
  bool _active = false;
  StreamSubscription<Duration>? _trimLoopSub;

  ({String url, int startMs, int? endMs}) _parseTrimmedUrl(String raw) {
    const marker = '#swipess_trim=';
    final index = raw.indexOf(marker);
    if (index < 0) return (url: raw, startMs: 0, endMs: null);
    final base = raw.substring(0, index);
    final values = raw.substring(index + marker.length).split(',');
    final start = values.isNotEmpty ? int.tryParse(values.first) ?? 0 : 0;
    final end = values.length > 1 && values[1].trim().isNotEmpty
        ? int.tryParse(values[1])
        : null;
    return (
      url: base,
      startMs: start < 0 ? 0 : start,
      endMs: end != null && end > start ? end : null,
    );
  }

  Future<void> play({
    String? presetId,
    String? url,
    XFile? file,
    double volume = .64,
  }) async {
    final preset = presetId?.trim();
    final remoteRaw = url?.trim();
    final trimmed = remoteRaw != null && remoteRaw.isNotEmpty
        ? _parseTrimmedUrl(remoteRaw)
        : null;
    final remote = trimmed?.url;
    final key = preset != null && preset.isNotEmpty
        ? 'preset:$preset'
        : remoteRaw != null && remoteRaw.isNotEmpty
        ? 'url:$remoteRaw'
        : file != null
        ? 'file:${file.name}:${file.path}'
        : null;
    if (key == null) {
      await stop();
      return;
    }

    if (_active && _key == key) {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      return;
    }

    await _trimLoopSub?.cancel();
    _trimLoopSub = null;
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume.clamp(0.0, 1.0));

    final Source source;
    if (preset != null && preset.isNotEmpty) {
      source = BytesSource(buildListingSoundtrackWav(preset));
    } else if (remote != null && remote.isNotEmpty) {
      source = UrlSource(remote);
    } else if (file != null && !kIsWeb && file.path.isNotEmpty) {
      source = DeviceFileSource(file.path);
    } else if (file != null) {
      source = BytesSource(await file.readAsBytes());
    } else {
      return;
    }

    await _player.play(source);
    _key = key;
    _active = true;

    final trimStart = trimmed?.startMs ?? 0;
    final trimEnd = trimmed?.endMs;
    if (trimStart > 0) {
      await _player.seek(Duration(milliseconds: trimStart));
    }
    if (trimEnd != null) {
      _trimLoopSub = _player.onPositionChanged.listen((position) async {
        if (_key != key || position.inMilliseconds < trimEnd) return;
        await _player.seek(Duration(milliseconds: trimStart));
      });
    }
  }

  Future<void> stop() async {
    _key = null;
    _active = false;
    await _trimLoopSub?.cancel();
    _trimLoopSub = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
