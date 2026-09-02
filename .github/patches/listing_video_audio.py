from pathlib import Path

ROOT = Path('.')


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = ROOT / path
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'Pattern not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, count))


def write(path: str, content: str) -> None:
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content)


# ---------------------------------------------------------------------------
# Shared original, royalty-free Swipess soundtrack library + playback helper.
# ---------------------------------------------------------------------------
write(
    'lib/src/features/swipes/domain/listing_soundtrack.dart',
    r'''import 'dart:math' as math;
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
  bytes.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
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

  Future<void> play({
    String? presetId,
    String? url,
    XFile? file,
    double volume = .64,
  }) async {
    final preset = presetId?.trim();
    final remote = url?.trim();
    final key = preset != null && preset.isNotEmpty
        ? 'preset:$preset'
        : remote != null && remote.isNotEmpty
        ? 'url:$remote'
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
  }

  Future<void> stop() async {
    _key = null;
    _active = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
''',
)

# ---------------------------------------------------------------------------
# Reusable upload/preset picker shared by manual and AI listing creation.
# ---------------------------------------------------------------------------
write(
    'lib/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart',
    r'''import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';
import 'package:google_fonts/google_fonts.dart';

class ListingVideoSoundtrackPicker extends StatefulWidget {
  const ListingVideoSoundtrackPicker({
    super.key,
    required this.customMusic,
    required this.presetId,
    required this.soundtrackName,
    required this.onCustomPicked,
    required this.onPresetSelected,
    required this.onClear,
    this.disabled = false,
  });

  final XFile? customMusic;
  final String? presetId;
  final String? soundtrackName;
  final ValueChanged<XFile> onCustomPicked;
  final void Function(String id, String label) onPresetSelected;
  final VoidCallback onClear;
  final bool disabled;

  @override
  State<ListingVideoSoundtrackPicker> createState() =>
      _ListingVideoSoundtrackPickerState();
}

class _ListingVideoSoundtrackPickerState
    extends State<ListingVideoSoundtrackPicker> {
  final ListingSoundtrackPlayer _preview = ListingSoundtrackPlayer();
  String? _previewing;

  @override
  void dispose() {
    unawaited(_preview.dispose());
    super.dispose();
  }

  Future<void> _pickOwnAudio() async {
    if (widget.disabled) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      allowMultiple: false,
      withData: true,
    );
    final picked = result?.files.singleOrNull;
    if (picked == null || !mounted) return;
    if (picked.size > 15 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Music file must be under 15MB.')),
      );
      return;
    }

    final XFile file;
    if (picked.bytes != null) {
      file = XFile.fromData(
        picked.bytes!,
        name: picked.name,
        mimeType: _audioMimeType(picked.name),
        length: picked.size,
      );
    } else if (picked.path != null && picked.path!.isNotEmpty) {
      file = XFile(
        picked.path!,
        name: picked.name,
        mimeType: _audioMimeType(picked.name),
      );
    } else {
      return;
    }

    widget.onCustomPicked(file);
    setState(() => _previewing = 'custom:${file.name}');
    try {
      await _preview.play(file: file, volume: .62);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected song saved. Preview is not available on this device.')),
      );
    }
  }

  Future<void> _selectPreset(ListingSoundtrackPreset preset) async {
    if (widget.disabled) return;
    widget.onPresetSelected(preset.id, preset.label);
    setState(() => _previewing = 'preset:${preset.id}');
    try {
      await _preview.play(presetId: preset.id, volume: .58);
    } catch (_) {}
  }

  Future<void> _clear() async {
    await _preview.stop();
    if (!mounted) return;
    setState(() => _previewing = null);
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final selectedName = widget.soundtrackName?.trim();
    final hasSelection =
        widget.customMusic != null || (widget.presetId?.trim().isNotEmpty ?? false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.library_music_rounded,
                color: AppTheme.brandPrimary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ADD SOUNDTRACK',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.disabled ? null : _pickOwnAudio,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('YOUR MUSIC'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Tap a Swipess sound to select + preview it. Choosing music mutes the original video by default; you can turn the original sound back on anytime.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white60,
              fontSize: 9.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: listingSoundtrackPresets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = listingSoundtrackPresets[index];
                final selected = widget.presetId == preset.id;
                final previewing = _previewing == 'preset:${preset.id}';
                return InkWell(
                  onTap: widget.disabled ? null : () => _selectPreset(preset),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 116,
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.brandPrimary.withValues(alpha: .18)
                          : Colors.white.withValues(alpha: .045),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppTheme.brandPrimary
                            : Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(preset.emoji, style: const TextStyle(fontSize: 17)),
                            const Spacer(),
                            Icon(
                              previewing
                                  ? Icons.graphic_eq_rounded
                                  : selected
                                  ? Icons.check_circle_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 16,
                              color: selected
                                  ? AppTheme.brandPrimary
                                  : Colors.white54,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.bestFor,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 7.5,
                            height: 1.18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (hasSelection) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
              decoration: BoxDecoration(
                color: const Color(0x1410B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFF34D399),
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      selectedName != null && selectedName.isNotEmpty
                          ? selectedName
                          : widget.customMusic?.name ?? 'Soundtrack selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove soundtrack',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.disabled ? null : _clear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white60,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Upload only music you own or have permission to use. Built-in Swipess sounds are original procedural loops.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 8.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _audioMimeType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  return 'audio/mpeg';
}
''',
)

# ---------------------------------------------------------------------------
# Draft state: persist original-audio + soundtrack choice through both flows.
# ---------------------------------------------------------------------------
replace(
    'lib/src/features/add/domain/listing_draft.dart',
    "    this.video,\n    this.legalDocuments = const [],",
    "    this.video,\n    this.videoAudioEnabled = true,\n    this.backgroundMusic,\n    this.backgroundMusicPreset,\n    this.backgroundMusicName,\n    this.legalDocuments = const [],",
)
replace(
    'lib/src/features/add/domain/listing_draft.dart',
    "  /// Optional Cap 10s loop video for the swipe card.\n  final XFile? video;",
    "  /// Optional short loop video for the swipe card.\n  final XFile? video;\n\n  /// Whether the video's own recorded audio should play when deck sound is on.\n  final bool videoAudioEnabled;\n\n  /// Optional user-uploaded soundtrack before it is uploaded to Storage.\n  final XFile? backgroundMusic;\n\n  /// Optional built-in original Swipess soundtrack id.\n  final String? backgroundMusicPreset;\n\n  /// Human-friendly selected soundtrack/file name.\n  final String? backgroundMusicName;\n\n  bool get hasBackgroundMusic =>\n      backgroundMusic != null ||\n      (backgroundMusicPreset != null && backgroundMusicPreset!.trim().isNotEmpty);",
)
replace(
    'lib/src/features/add/domain/listing_draft.dart',
    "    XFile? video,\n    bool clearVideo = false,\n    List<XFile>? legalDocuments,",
    "    XFile? video,\n    bool clearVideo = false,\n    bool? videoAudioEnabled,\n    XFile? backgroundMusic,\n    bool clearBackgroundMusic = false,\n    String? backgroundMusicPreset,\n    bool clearBackgroundMusicPreset = false,\n    String? backgroundMusicName,\n    bool clearBackgroundMusicName = false,\n    List<XFile>? legalDocuments,",
)
replace(
    'lib/src/features/add/domain/listing_draft.dart',
    "      video: clearVideo ? null : (video ?? this.video),\n      legalDocuments: legalDocuments ?? this.legalDocuments,",
    "      video: clearVideo ? null : (video ?? this.video),\n      videoAudioEnabled: videoAudioEnabled ?? this.videoAudioEnabled,\n      backgroundMusic: clearBackgroundMusic\n          ? null\n          : (backgroundMusic ?? this.backgroundMusic),\n      backgroundMusicPreset: clearBackgroundMusicPreset\n          ? null\n          : (backgroundMusicPreset ?? this.backgroundMusicPreset),\n      backgroundMusicName: clearBackgroundMusicName\n          ? null\n          : (backgroundMusicName ?? this.backgroundMusicName),\n      legalDocuments: legalDocuments ?? this.legalDocuments,",
)

# ---------------------------------------------------------------------------
# Publish provider: setters, custom audio upload and DB payload metadata.
# ---------------------------------------------------------------------------
replace(
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    "  void setVideo(XFile file) {\n    state = state.copyWith(video: file, clearError: true);\n  }",
    "  void setVideo(XFile file) {\n    state = state.copyWith(video: file, clearError: true);\n  }\n\n  void setVideoAudioEnabled(bool enabled) {\n    state = state.copyWith(videoAudioEnabled: enabled, clearError: true);\n  }\n\n  void setBackgroundMusicPreset(String id, String name) {\n    state = state.copyWith(\n      videoAudioEnabled: false,\n      clearBackgroundMusic: true,\n      backgroundMusicPreset: id,\n      backgroundMusicName: name,\n      clearError: true,\n    );\n  }\n\n  void setBackgroundMusicFile(XFile file) {\n    state = state.copyWith(\n      videoAudioEnabled: false,\n      backgroundMusic: file,\n      clearBackgroundMusicPreset: true,\n      backgroundMusicName: file.name,\n      clearError: true,\n    );\n  }\n\n  void clearBackgroundMusic() {\n    state = state.copyWith(\n      clearBackgroundMusic: true,\n      clearBackgroundMusicPreset: true,\n      clearBackgroundMusicName: true,\n      clearError: true,\n    );\n  }",
)
replace(
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    "  void removeVideo() => state = state.copyWith(clearVideo: true);",
    "  void removeVideo() => state = state.copyWith(\n    clearVideo: true,\n    videoAudioEnabled: true,\n    clearBackgroundMusic: true,\n    clearBackgroundMusicPreset: true,\n    clearBackgroundMusicName: true,\n  );",
)
replace(
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    "      String? videoUrl;\n      final video = state.video;\n      if (video != null) {\n        videoUrl = await repo.uploadListingVideo(userId: user.id, file: video);\n      }\n      final payload = _payload(user.id, urls, coords, videoUrl: videoUrl);",
    "      String? videoUrl;\n      final video = state.video;\n      if (video != null) {\n        videoUrl = await repo.uploadListingVideo(userId: user.id, file: video);\n      }\n      String? backgroundMusicUrl;\n      final backgroundMusic = state.backgroundMusic;\n      if (video != null && backgroundMusic != null) {\n        backgroundMusicUrl = await repo.uploadListingAudio(\n          userId: user.id,\n          file: backgroundMusic,\n        );\n      }\n      final payload = _payload(\n        user.id,\n        urls,\n        coords,\n        videoUrl: videoUrl,\n        backgroundMusicUrl: backgroundMusicUrl,\n      );",
)
replace(
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    "    ({double lat, double lng, String country, String state}) coords, {\n    String? videoUrl,\n  }) {",
    "    ({double lat, double lng, String country, String state}) coords, {\n    String? videoUrl,\n    String? backgroundMusicUrl,\n  }) {",
)
replace(
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    "      'video_url': videoUrl,\n      'amenities': draft.amenities,",
    "      'video_url': videoUrl,\n      'video_audio_enabled': draft.videoAudioEnabled,\n      'background_music_url': backgroundMusicUrl,\n      'background_music_preset': draft.backgroundMusicPreset,\n      'background_music_name': draft.backgroundMusicName,\n      'amenities': draft.amenities,",
)

# ---------------------------------------------------------------------------
# Repository: fetch new metadata and upload custom listing soundtrack files.
# ---------------------------------------------------------------------------
replace(
    'lib/src/features/swipes/data/repositories/listing_repository.dart',
    "    id, title, description, price, images, video_url,\n    city, neighborhood, beds, baths, category,",
    "    id, title, description, price, images, video_url,\n    video_audio_enabled, background_music_url, background_music_preset,\n    background_music_name, city, neighborhood, beds, baths, category,",
)
needle = """  Future<void> uploadListingLegalDocuments({
"""
insert = r'''  Future<String?> uploadListingAudio({
    required String userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Selected music file is empty.');
    if (bytes.lengthInBytes > 15 * 1024 * 1024) {
      throw Exception('Music file must be under 15MB.');
    }
    final lower = file.name.toLowerCase();
    final ext = lower.endsWith('.m4a')
        ? 'm4a'
        : lower.endsWith('.aac')
        ? 'aac'
        : lower.endsWith('.wav')
        ? 'wav'
        : lower.endsWith('.ogg')
        ? 'ogg'
        : 'mp3';
    final contentType = switch (ext) {
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'audio/mpeg',
    };
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('listing-audio')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from('listing-audio').getPublicUrl(path);
  }

'''
replace('lib/src/features/swipes/data/repositories/listing_repository.dart', needle, insert + needle)

# ---------------------------------------------------------------------------
# Public listing model: expose persisted audio choices to every listing surface.
# ---------------------------------------------------------------------------
replace(
    'lib/src/features/swipes/domain/models/listing.dart',
    "  final String? videoUrl;\n  final String? status;",
    "  final String? videoUrl;\n  final bool videoAudioEnabled;\n  final String? backgroundMusicUrl;\n  final String? backgroundMusicPreset;\n  final String? backgroundMusicName;\n  final String? status;",
)
replace(
    'lib/src/features/swipes/domain/models/listing.dart',
    "    this.videoUrl,\n    this.status,",
    "    this.videoUrl,\n    this.videoAudioEnabled = true,\n    this.backgroundMusicUrl,\n    this.backgroundMusicPreset,\n    this.backgroundMusicName,\n    this.status,",
)
replace(
    'lib/src/features/swipes/domain/models/listing.dart',
    "      videoUrl: json['video_url'] as String?,\n      status: json['status'] as String?,",
    "      videoUrl: json['video_url'] as String?,\n      videoAudioEnabled: json['video_audio_enabled'] != false,\n      backgroundMusicUrl: json['background_music_url'] as String?,\n      backgroundMusicPreset: json['background_music_preset'] as String?,\n      backgroundMusicName: json['background_music_name'] as String?,\n      status: json['status'] as String?,",
)
replace(
    'lib/src/features/swipes/domain/models/listing.dart',
    "  /// Primary image URL for the swipe card.\n  String? get primaryImage",
    "  bool get hasBackgroundMusic =>\n      (backgroundMusicUrl?.trim().isNotEmpty ?? false) ||\n      (backgroundMusicPreset?.trim().isNotEmpty ?? false);\n\n  /// Primary image URL for the swipe card.\n  String? get primaryImage",
)

# ---------------------------------------------------------------------------
# Manual uploader: video first/left + inline mute + soundtrack library.
# ---------------------------------------------------------------------------
replace(
    'lib/src/features/add/presentation/screens/add_listing_screen.dart',
    "import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';",
    "import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';\nimport 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart';",
)
old_manual_buttons = r'''            Expanded(
              child: _MediaPickCard(
                icon: Icons.photo_library_rounded,
                title: 'Photos',
                subtitle: 'Up to ${draft.maxPhotos}',
                onTap: () => ref.read(addListingProvider.notifier).pickPhotos(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MediaPickCard(
                icon: draft.video == null
                    ? Icons.video_call_rounded
                    : Icons.edit_rounded,
                title: draft.video == null ? 'Video' : 'Edit video',
                subtitle: '1 video · trim 5 / 10 / 15 / 20s',
                onTap: () => draft.video == null
                    ? _pickVideo(context, ref)
                    : _editVideo(context, ref),
              ),
            ),'''
new_manual_buttons = r'''            Expanded(
              child: _MediaPickCard(
                icon: draft.video == null
                    ? Icons.video_call_rounded
                    : Icons.edit_rounded,
                title: draft.video == null ? 'Video' : 'Edit video',
                subtitle: '1 video · trim 5 / 10 / 15 / 20s',
                onTap: () => draft.video == null
                    ? _pickVideo(context, ref)
                    : _editVideo(context, ref),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MediaPickCard(
                icon: Icons.photo_library_rounded,
                title: 'Photos',
                subtitle: 'Up to ${draft.maxPhotos}',
                onTap: () => ref.read(addListingProvider.notifier).pickPhotos(),
              ),
            ),'''
replace('lib/src/features/add/presentation/screens/add_listing_screen.dart', old_manual_buttons, new_manual_buttons)
replace(
    'lib/src/features/add/presentation/screens/add_listing_screen.dart',
    "                IconButton(\n                  tooltip: 'Preview and trim',",
    "                IconButton(\n                  tooltip: draft.videoAudioEnabled\n                      ? 'Mute original video sound'\n                      : 'Turn original video sound on',\n                  onPressed: () => ref\n                      .read(addListingProvider.notifier)\n                      .setVideoAudioEnabled(!draft.videoAudioEnabled),\n                  icon: Icon(\n                    draft.videoAudioEnabled\n                        ? Icons.volume_up_rounded\n                        : Icons.volume_off_rounded,\n                    color: draft.videoAudioEnabled\n                        ? Colors.white\n                        : AppTheme.brandPrimary,\n                  ),\n                ),\n                IconButton(\n                  tooltip: 'Preview and trim',",
)
replace(
    'lib/src/features/add/presentation/screens/add_listing_screen.dart',
    "          ),\n        ],\n        if (draft.photos.isNotEmpty) ...[",
    "          ),\n          const SizedBox(height: 10),\n          ListingVideoSoundtrackPicker(\n            customMusic: draft.backgroundMusic,\n            presetId: draft.backgroundMusicPreset,\n            soundtrackName: draft.backgroundMusicName,\n            onCustomPicked: (file) => ref\n                .read(addListingProvider.notifier)\n                .setBackgroundMusicFile(file),\n            onPresetSelected: (id, name) => ref\n                .read(addListingProvider.notifier)\n                .setBackgroundMusicPreset(id, name),\n            onClear: () => ref\n                .read(addListingProvider.notifier)\n                .clearBackgroundMusic(),\n          ),\n        ],\n        if (draft.photos.isNotEmpty) ...[",
)

# ---------------------------------------------------------------------------
# AI uploader: same media order and audio state, then copy to shared draft.
# ---------------------------------------------------------------------------
replace(
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    "import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';",
    "import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';\nimport 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart';",
)
replace(
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    "  XFile? _video;\n  ListingMode? _modeOverride;",
    "  XFile? _video;\n  bool _videoAudioEnabled = true;\n  XFile? _backgroundMusic;\n  String? _backgroundMusicPreset;\n  String? _backgroundMusicName;\n  ListingMode? _modeOverride;",
)
replace(
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    "          video: _video,\n          legalDocuments: verificationDocuments,",
    "          video: _video,\n          videoAudioEnabled: _videoAudioEnabled,\n          backgroundMusic: _backgroundMusic,\n          clearBackgroundMusic: _backgroundMusic == null,\n          backgroundMusicPreset: _backgroundMusicPreset,\n          clearBackgroundMusicPreset: _backgroundMusicPreset == null,\n          backgroundMusicName: _backgroundMusicName,\n          clearBackgroundMusicName: _backgroundMusicName == null,\n          legalDocuments: verificationDocuments,",
)
old_ai_buttons = r'''            Expanded(
              child: _mediaActionButton(
                icon: Icons.photo_library_rounded,
                label: _photos.isEmpty ? 'ADD PHOTOS' : 'ADD MORE',
                sublabel: 'Choose from gallery',
                onTap: _pickPhotos,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _mediaActionButton(
                icon: _video == null
                    ? Icons.video_call_rounded
                    : Icons.edit_rounded,
                label: _video == null ? 'ADD VIDEO' : 'EDIT VIDEO',
                sublabel: '1 video · trim 5 / 10 / 15 / 20s',
                onTap: _video == null ? _pickVideo : _editVideo,
              ),
            ),'''
new_ai_buttons = r'''            Expanded(
              child: _mediaActionButton(
                icon: _video == null
                    ? Icons.video_call_rounded
                    : Icons.edit_rounded,
                label: _video == null ? 'ADD VIDEO' : 'EDIT VIDEO',
                sublabel: '1 video · trim 5 / 10 / 15 / 20s',
                onTap: _video == null ? _pickVideo : _editVideo,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _mediaActionButton(
                icon: Icons.photo_library_rounded,
                label: _photos.isEmpty ? 'ADD PHOTOS' : 'ADD MORE',
                sublabel: 'Choose from gallery',
                onTap: _pickPhotos,
              ),
            ),'''
replace('lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart', old_ai_buttons, new_ai_buttons)
replace(
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    "                IconButton(\n                  onPressed: _busy ? null : _editVideo,",
    "                IconButton(\n                  tooltip: _videoAudioEnabled\n                      ? 'Mute original video sound'\n                      : 'Turn original video sound on',\n                  onPressed: _busy\n                      ? null\n                      : () => setState(\n                          () => _videoAudioEnabled = !_videoAudioEnabled,\n                        ),\n                  icon: Icon(\n                    _videoAudioEnabled\n                        ? Icons.volume_up_rounded\n                        : Icons.volume_off_rounded,\n                    color: _videoAudioEnabled ? Colors.white : _pink,\n                    size: 19,\n                  ),\n                ),\n                IconButton(\n                  onPressed: _busy ? null : _editVideo,",
)
replace(
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    "                IconButton(\n                  onPressed: _busy ? null : () => setState(() => _video = null),",
    "                IconButton(\n                  onPressed: _busy\n                      ? null\n                      : () => setState(() {\n                          _video = null;\n                          _videoAudioEnabled = true;\n                          _backgroundMusic = null;\n                          _backgroundMusicPreset = null;\n                          _backgroundMusicName = null;\n                        }),",
)
replace(
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    "          ),\n        ],\n        if (_photos.isNotEmpty) ...[",
    "          ),\n          const SizedBox(height: 10),\n          ListingVideoSoundtrackPicker(\n            customMusic: _backgroundMusic,\n            presetId: _backgroundMusicPreset,\n            soundtrackName: _backgroundMusicName,\n            disabled: _busy,\n            onCustomPicked: (file) => setState(() {\n              _backgroundMusic = file;\n              _backgroundMusicPreset = null;\n              _backgroundMusicName = file.name;\n              _videoAudioEnabled = false;\n            }),\n            onPresetSelected: (id, name) => setState(() {\n              _backgroundMusic = null;\n              _backgroundMusicPreset = id;\n              _backgroundMusicName = name;\n              _videoAudioEnabled = false;\n            }),\n            onClear: () => setState(() {\n              _backgroundMusic = null;\n              _backgroundMusicPreset = null;\n              _backgroundMusicName = null;\n            }),\n          ),\n        ],\n        if (_photos.isNotEmpty) ...[",
)

# ---------------------------------------------------------------------------
# Swipe playback: global mute remains authoritative; listing mute controls only
# original video, and optional soundtrack loops alongside it when sound is on.
# ---------------------------------------------------------------------------
replace(
    'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',
    "import 'package:flutter_swipes/src/features/swipes/domain/listing_match_score.dart';",
    "import 'package:flutter_swipes/src/features/swipes/domain/listing_match_score.dart';\nimport 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';",
)
replace(
    'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',
    "  VideoPlayerController? _video;\n  String? _boundVideo;",
    "  VideoPlayerController? _video;\n  String? _boundVideo;\n  final ListingSoundtrackPlayer _soundtrack = ListingSoundtrackPlayer();",
)
replace(
    'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',
    "    _disposeVideo();\n    super.dispose();",
    "    _disposeVideo();\n    unawaited(_soundtrack.dispose());\n    super.dispose();",
)
replace(
    'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',
    "    _video = null;\n    _boundVideo = null;\n    if (player == null) return;",
    "    _video = null;\n    _boundVideo = null;\n    unawaited(_soundtrack.stop());\n    if (player == null) return;",
)
replace(
    'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',
    "    if (!widget.isTop) {\n      try {\n        await player.setVolume(0);\n        if (player.value.isPlaying) await player.pause();\n      } catch (_) {}\n      return;\n    }",
    "    if (!widget.isTop) {\n      await _soundtrack.stop();\n      try {\n        await player.setVolume(0);\n        if (player.value.isPlaying) await player.pause();\n      } catch (_) {}\n      return;\n    }",
)
old_playback = r'''    try {
      await player.setVolume(0);
      await player.play();
      if (wantSound) await player.setVolume(1);
    } catch (_) {
      try {
        await player.setVolume(0);
        await player.play();
        if (wantSound && widget.isTop) {
          try {
            await player.setVolume(1);
          } catch (_) {}
        }
      } catch (_) {}
    }
  }
'''
new_playback = r'''    final playOriginal = wantSound && widget.listing.videoAudioEnabled;
    try {
      await player.setVolume(0);
      await player.play();
      if (playOriginal) await player.setVolume(1);
    } catch (_) {
      try {
        await player.setVolume(0);
        await player.play();
        if (playOriginal && widget.isTop) {
          try {
            await player.setVolume(1);
          } catch (_) {}
        }
      } catch (_) {}
    }
    await _syncSoundtrack(wantSound);
  }

  Future<void> _syncSoundtrack(bool wantSound) async {
    if (!widget.isTop || !wantSound || !widget.listing.hasBackgroundMusic) {
      await _soundtrack.stop();
      return;
    }
    try {
      await _soundtrack.play(
        presetId: widget.listing.backgroundMusicPreset,
        url: widget.listing.backgroundMusicUrl,
        volume: .62,
      );
    } catch (_) {
      await _soundtrack.stop();
    }
  }
'''
replace('lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart', old_playback, new_playback)
replace(
    'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',
    "      final wantSound = on && (unlocked || !kIsWeb);\n      _video?.setVolume(wantSound ? 1 : 0);",
    "      final wantSound = on && (unlocked || !kIsWeb);\n      final playOriginal = wantSound && widget.listing.videoAudioEnabled;\n      _video?.setVolume(playOriginal ? 1 : 0);\n      unawaited(_syncSoundtrack(wantSound));",
)

# ---------------------------------------------------------------------------
# Schema history mirrors the live migration applied to Supabase.
# ---------------------------------------------------------------------------
write(
    'supabase/migrations/20260902061000_listing_video_soundtracks.sql',
    r'''alter table public.listings
  add column if not exists video_audio_enabled boolean not null default true,
  add column if not exists background_music_url text,
  add column if not exists background_music_preset text,
  add column if not exists background_music_name text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'listing-audio',
  'listing-audio',
  true,
  15728640,
  array[
    'audio/mpeg',
    'audio/mp4',
    'audio/x-m4a',
    'audio/aac',
    'audio/wav',
    'audio/x-wav',
    'audio/ogg'
  ]::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "listing audio insert own folder" on storage.objects;
create policy "listing audio insert own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'listing-audio'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "listing audio update own folder" on storage.objects;
create policy "listing audio update own folder"
on storage.objects for update to authenticated
using (
  bucket_id = 'listing-audio'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'listing-audio'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "listing audio delete own folder" on storage.objects;
create policy "listing audio delete own folder"
on storage.objects for delete to authenticated
using (
  bucket_id = 'listing-audio'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
''',
)

# ---------------------------------------------------------------------------
# Focused regression coverage.
# ---------------------------------------------------------------------------
write(
    'test/listing_video_audio_test.dart',
    r'''import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships ten original listing soundtrack presets', () {
    expect(listingSoundtrackPresets, hasLength(10));
    expect(
      listingSoundtrackPresets.map((preset) => preset.id).toSet(),
      hasLength(10),
    );
  });

  test('procedural soundtrack is a valid non-empty WAV', () {
    final wav = buildListingSoundtrackWav('ocean');
    expect(wav.length, greaterThan(44));
    expect(String.fromCharCodes(wav.take(4)), 'RIFF');
    expect(String.fromCharCodes(wav.skip(8).take(4)), 'WAVE');
  });

  test('listing draft keeps mute and soundtrack state', () {
    final file = XFile.fromData(
      Uint8List.fromList(const [1, 2, 3]),
      name: 'my-song.mp3',
      mimeType: 'audio/mpeg',
    );
    final draft = ListingDraft(
      videoAudioEnabled: false,
      backgroundMusic: file,
      backgroundMusicName: 'my-song.mp3',
    );
    expect(draft.videoAudioEnabled, isFalse);
    expect(draft.hasBackgroundMusic, isTrue);
    final cleared = draft.copyWith(
      clearBackgroundMusic: true,
      clearBackgroundMusicName: true,
    );
    expect(cleared.backgroundMusic, isNull);
  });

  test('listing parses persisted audio choices', () {
    final listing = Listing.fromJson({
      'id': 'listing-1',
      'video_url': 'https://example.com/video.mp4',
      'video_audio_enabled': false,
      'background_music_preset': 'night_beach',
      'background_music_name': 'Night Beach',
    });
    expect(listing.videoAudioEnabled, isFalse);
    expect(listing.backgroundMusicPreset, 'night_beach');
    expect(listing.hasBackgroundMusic, isTrue);
  });

  test('manual and AI media rows put video before photos', () {
    final manual = File(
      'lib/src/features/add/presentation/screens/add_listing_screen.dart',
    ).readAsStringSync();
    final ai = File(
      'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    ).readAsStringSync();

    expect(
      manual.indexOf("title: draft.video == null ? 'Video' : 'Edit video'"),
      lessThan(manual.indexOf("title: 'Photos'")),
    );
    expect(
      ai.indexOf("label: _video == null ? 'ADD VIDEO' : 'EDIT VIDEO'"),
      lessThan(ai.indexOf("label: _photos.isEmpty ? 'ADD PHOTOS' : 'ADD MORE'")),
    );
  });
}
'''.replace("import 'package:flutter_test/flutter_test.dart';", "import 'dart:typed_data';\n\nimport 'package:flutter_test/flutter_test.dart';"),
)
