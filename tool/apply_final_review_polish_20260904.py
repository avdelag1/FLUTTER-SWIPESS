from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text)


def replace_once(path: str, old: str, new: str, label: str) -> None:
    text = read(path)
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'{label}: target not found in {path}')
    write(path, text.replace(old, new, 1))


# 1) HLS is usable only when the processing pipeline explicitly says READY.
replace_once(
    'lib/src/features/swipes/domain/models/listing.dart',
    """    final processing = videoProcessingStatus?.trim().toLowerCase() ?? '';
    if (processing == 'failed' || processing == 'error') return false;
    return true;
""",
    """    final processing = videoProcessingStatus?.trim().toLowerCase() ?? '';
    return processing == 'ready';
""",
    'HLS ready gate',
)


# 2) Android background audio must loop for the full video composition.
replace_once(
    'android/app/src/main/kotlin/com/swipess/app/MainActivity.kt',
    """            Composition.Builder(
                EditedMediaItemSequence(edited),
                EditedMediaItemSequence(musicItem),
            ).build()
""",
    """            val backgroundAudioSequence = EditedMediaItemSequence
                .withAudioFrom(listOf(musicItem))
                .buildUpon()
                .setIsLooping(true)
                .build()
            Composition.Builder(
                EditedMediaItemSequence(edited),
                backgroundAudioSequence,
            ).build()
""",
    'Android looping soundtrack sequence',
)


# 3) Native music byte fallbacks retain a real, supported audio extension.
replace_once(
    'lib/src/features/camera/data/video_recut_v2_io.dart',
    """      final temp = File(
        '${Directory.systemTemp.path}/swipess_music_${DateTime.now().microsecondsSinceEpoch}.bin',
      );
""",
    """      final safeExtension = _nativeAudioExtension(file.name);
      final temp = File(
        '${Directory.systemTemp.path}/swipess_music_${DateTime.now().microsecondsSinceEpoch}.$safeExtension',
      );
""",
    'native music extension',
)

io_path = 'lib/src/features/camera/data/video_recut_v2_io.dart'
io_text = read(io_path)
helper = """
String _nativeAudioExtension(String name) {
  final normalized = name.trim().toLowerCase();
  final match = RegExp(r'\\.([a-z0-9]+)$').firstMatch(normalized);
  final extension = match?.group(1) ?? '';
  const supported = <String>{'mp3', 'm4a', 'aac', 'wav', 'ogg'};
  return supported.contains(extension) ? extension : 'm4a';
}
"""
if helper.strip() not in io_text:
    io_text = io_text.rstrip() + '\n\n' + helper.lstrip()
    write(io_path, io_text)


# 4) iOS keeps explicit audio track references and applies an AVAudioMix when
#    original audio and/or a soundtrack are exported together.
ios = 'ios/Runner/AppDelegate.swift'
replace_once(
    ios,
    """    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(
""",
    """    let composition = AVMutableComposition()
    var exportAudioTracks: [(track: AVMutableCompositionTrack, volume: Float)] = []
    guard let videoTrack = composition.addMutableTrack(
""",
    'iOS audio track registry',
)
replace_once(
    ios,
    """        try? audioTrack.insertTimeRange(sourceRange, of: sourceAudio, at: .zero)
      }

      if !musicPath.isEmpty {
        Self.mixLoopedMusic(
          into: composition,
          musicPath: musicPath,
          musicStartMs: musicStartMs,
          musicEndMs: musicEndMs,
          duration: rangeDuration
        )
      }
""",
    """        try? audioTrack.insertTimeRange(sourceRange, of: sourceAudio, at: .zero)
        exportAudioTracks.append((track: audioTrack, volume: 1.0))
      }

      if !musicPath.isEmpty,
         let musicTrack = Self.mixLoopedMusic(
          into: composition,
          musicPath: musicPath,
          musicStartMs: musicStartMs,
          musicEndMs: musicEndMs,
          duration: rangeDuration
         ) {
        exportAudioTracks.append((
          track: musicTrack,
          volume: includeOriginalAudio ? 0.72 : 1.0
        ))
      }
""",
    'iOS capture mixed tracks',
)
replace_once(
    ios,
    """    guard let exporter = AVAssetExportSession(asset: composition, presetName: preset) else {
      result(FlutterError(code: "export_unavailable", message: "Could not create video exporter", details: nil))
      return
    }

    if portraitCrop {
""",
    """    guard let exporter = AVAssetExportSession(asset: composition, presetName: preset) else {
      result(FlutterError(code: "export_unavailable", message: "Could not create video exporter", details: nil))
      return
    }

    if !exportAudioTracks.isEmpty {
      let audioMix = AVMutableAudioMix()
      audioMix.inputParameters = exportAudioTracks.map { entry in
        let parameters = AVMutableAudioMixInputParameters(track: entry.track)
        parameters.setVolume(entry.volume, at: .zero)
        return parameters
      }
      exporter.audioMix = audioMix
    }

    if portraitCrop {
""",
    'iOS explicit AVAudioMix',
)
replace_once(
    ios,
    """  static func mixLoopedMusic(
    into composition: AVMutableComposition,
    musicPath: String,
    musicStartMs: Int64,
    musicEndMs: Int64,
    duration: CMTime
  ) {
    let musicURL = URL(fileURLWithPath: musicPath)
    guard FileManager.default.fileExists(atPath: musicURL.path) else { return }
    let musicAsset = AVURLAsset(url: musicURL)
    guard let sourceMusic = musicAsset.tracks(withMediaType: .audio).first,
          let dest = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
          )
    else { return }
""",
    """  static func mixLoopedMusic(
    into composition: AVMutableComposition,
    musicPath: String,
    musicStartMs: Int64,
    musicEndMs: Int64,
    duration: CMTime
  ) -> AVMutableCompositionTrack? {
    let musicURL = URL(fileURLWithPath: musicPath)
    guard FileManager.default.fileExists(atPath: musicURL.path) else { return nil }
    let musicAsset = AVURLAsset(url: musicURL)
    guard let sourceMusic = musicAsset.tracks(withMediaType: .audio).first,
          let dest = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
          )
    else { return nil }
""",
    'iOS music helper return type',
)
replace_once(
    ios,
    """    guard CMTimeCompare(window, .zero) > 0 else { return }

    var cursor = CMTime.zero
""",
    """    guard CMTimeCompare(window, .zero) > 0 else { return nil }

    var cursor = CMTime.zero
""",
    'iOS invalid music window return',
)
replace_once(
    ios,
    """      cursor = CMTimeAdd(cursor, slice)
    }
  }
}
""",
    """      cursor = CMTimeAdd(cursor, slice)
    }
    return dest
  }
}
""",
    'iOS return soundtrack track',
)


# 5) Quick-filter images: no forced decode dimensions on web; native uses only
#    cacheWidth. Also replace dead-black failure/empty states with a clearly
#    editorial category backdrop (never a fake listing ID).
qf = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
replace_once(
    qf,
    """        final logicalW = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : viewport.width;
        final logicalH = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : viewport.height;
        final cacheW = (logicalW * dpr).round().clamp(480, 1440).toInt();
        final cacheH = (logicalH * dpr).round().clamp(480, 1920).toInt();
""",
    """        final logicalW = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : viewport.width;
        final cacheW = (logicalW * dpr).round().clamp(480, 1440).toInt();
""",
    'quick filter decode dimensions',
)
replace_once(
    qf,
    """          cacheWidth: cacheW,
          cacheHeight: cacheH,
""",
    """          cacheWidth: kIsWeb ? null : cacheW,
""",
    'quick filter web/native cache width',
)

qf_text = read(qf)
empty_method = """
  Widget _emptyCategoryBackdrop() {
    final category = (widget.handoffCategoryId ?? '').trim().toLowerCase();
    final asset = switch (category) {
      'services' || 'worker' || 'workers' => 'assets/filters/pros.jpg',
      'motorcycle' => 'assets/filters/motorcycle.jpg',
      'bicycle' => 'assets/filters/bicycle.jpg',
      _ => null,
    };
    final icon = switch (category) {
      'services' || 'worker' || 'workers' => Icons.handyman_rounded,
      'yacht' => Icons.sailing_rounded,
      'motorcycle' => Icons.two_wheeler_rounded,
      'bicycle' => Icons.pedal_bike_rounded,
      _ => Icons.explore_rounded,
    };
    final base = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202631), Color(0xFF0C0F14)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 22,
            right: 16,
            child: Icon(icon, size: 68, color: Colors.white.withAlpha(18)),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withAlpha(22)),
              ),
              child: const Text(
                'EXPLORE LIVE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (asset == null) return base;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => base,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x10000000), Color(0x52000000)],
            ),
          ),
        ),
      ],
    );
  }
"""
anchor = """  Widget _localFallbackFor(String failedUrl) {
"""
if empty_method.strip() not in qf_text:
    if anchor not in qf_text:
        raise SystemExit('quick filter empty backdrop anchor missing')
    qf_text = qf_text.replace(anchor, empty_method + '\n' + anchor, 1)
qf_text = qf_text.replace(
    """    return const ColoredBox(color: Color(0xFF15171C));
  }

  Widget _buildStill(String url) {
""",
    """    return _emptyCategoryBackdrop();
  }

  Widget _buildStill(String url) {
""",
    1,
)
qf_text = qf_text.replace(
    """        return posterWidget ?? const ColoredBox(color: Color(0xFF15171C));
""",
    """        return posterWidget ?? _emptyCategoryBackdrop();
""",
)
qf_text = qf_text.replace(
    """      return posterWidget ?? const ColoredBox(color: Color(0xFF15171C));
""",
    """      return posterWidget ?? _emptyCategoryBackdrop();
""",
)
qf_text = qf_text.replace(
    """    if (sources.isEmpty) {
      return const ColoredBox(color: Color(0xFF15171C));
    }
""",
    """    if (sources.isEmpty) {
      return _emptyCategoryBackdrop();
    }
""",
    1,
)
write(qf, qf_text)


# Properties use a dedicated teaser; give its empty/error state a polished
# category cover rather than a dead black rectangle.
property_card = 'lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart'
replace_once(
    property_card,
    """  Widget _still(String url) {
    if (url.isEmpty) return const ColoredBox(color: Color(0xFF15171C));
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF15171C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return const ColoredBox(color: Color(0xFF15171C));
    }
""",
    """  Widget _propertyBackdrop() => Image.asset(
    'assets/filters/property.jpg',
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, _, _) => const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202631), Color(0xFF0C0F14)],
        ),
      ),
    ),
  );

  Widget _still(String url) {
    if (url.isEmpty) return _propertyBackdrop();
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _propertyBackdrop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return _propertyBackdrop();
    }
""",
    'property empty/error backdrop',
)
replace_once(
    property_card,
    """              if (poster != null)
                _still(poster)
              else
                const ColoredBox(color: Color(0xFF15171C)),
""",
    """              if (poster != null)
                _still(poster)
              else
                _propertyBackdrop(),
""",
    'property missing poster backdrop',
)


# 6) Header geometry: avatar, AI bar, map, and burger share one 44px centerline.
topbar = 'lib/src/core/widgets/app_top_bar.dart'
replace_once(
    topbar,
    '      crossAxisAlignment: CrossAxisAlignment.start,\n',
    '      crossAxisAlignment: CrossAxisAlignment.center,\n',
    'header vertical alignment',
)
replace_once(
    topbar,
    """        if (effectiveSearchBar != null) ...[
          const SizedBox(width: 10),
          Expanded(child: effectiveSearchBar),
          const SizedBox(width: 10),
""",
    """        if (effectiveSearchBar != null) ...[
          const SizedBox(width: 8),
          Expanded(child: effectiveSearchBar),
          const SizedBox(width: 8),
""",
    'header balanced AI gaps',
)


# 7) BlueFuse/AI prompt is a deterministic marquee, not a static/swap effect.
glow = 'lib/src/core/widgets/glow_search_bar.dart'
replace_once(
    glow,
    """    _promptTimer = Timer(
      Duration(milliseconds: 6000 + _random.nextInt(2001)),
      () {
        if (!mounted) return;
        if (_showPrompt) {
          final prompts = _rotatingPrompts;
          var next = _random.nextInt(prompts.length);
          while (next == _promptIndex && prompts.length > 1) {
            next = _random.nextInt(prompts.length);
          }
          setState(() => _promptIndex = next);
        }
        _schedulePrompt();
      },
    );
""",
    """    _promptTimer = Timer(
      const Duration(milliseconds: 5200),
      () {
        if (!mounted) return;
        if (_showPrompt) {
          final prompts = _rotatingPrompts;
          setState(() => _promptIndex = (_promptIndex + 1) % prompts.length);
        }
        _schedulePrompt();
      },
    );
""",
    'sequential sensory prompt timer',
)

# The random field is no longer needed after deterministic marquee rotation.
glow_text = read(glow)
glow_text = glow_text.replace('  final _random = math.Random();\n\n', '', 1)

old_prompt = """                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 800),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final isEntering =
                                      child.key ==
                                      ValueKey<String>(displayHint);
                                  final offsetAnimation = Tween<Offset>(
                                    begin: isEntering
                                        ? const Offset(1.2, 0.0)
                                        : const Offset(-1.2, 0.0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return SlideTransition(
                                    position: offsetAnimation,
                                    child: child,
                                  );
                                },
                                layoutBuilder:
                                    (currentChild, previousChildren) {
                                      return Stack(
                                        alignment: Alignment.centerLeft,
                                        children: <Widget>[
                                          ...previousChildren,
                                          if (currentChild != null)
                                            currentChild,
                                        ],
                                      );
                                    },
                                child: Text(
                                  displayHint,
                                  key: ValueKey<String>(displayHint),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: ink.withAlpha(isLight ? 190 : 225),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
"""
new_prompt = """                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final promptStyle = GoogleFonts.plusJakartaSans(
                                    color: ink.withAlpha(isLight ? 190 : 225),
                                    fontWeight: FontWeight.w650,
                                    fontSize: widget.compactHeader ? 12.5 : 14.0,
                                  );
                                  final painter = TextPainter(
                                    text: TextSpan(text: displayHint, style: promptStyle),
                                    maxLines: 1,
                                    textDirection: Directionality.of(context),
                                  )..layout();
                                  final travel = math.max(
                                    painter.width + 18,
                                    constraints.maxWidth + 18,
                                  );
                                  return ClipRect(
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey<String>(displayHint),
                                      tween: Tween<double>(begin: 0, end: 1),
                                      duration: const Duration(milliseconds: 5000),
                                      curve: Curves.linear,
                                      builder: (context, progress, child) {
                                        return Transform.translate(
                                          offset: Offset(-travel * progress, 0),
                                          child: child,
                                        );
                                      },
                                      child: Text(
                                        displayHint,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: promptStyle,
                                      ),
                                    ),
                                  );
                                },
                              ),
"""
if new_prompt not in glow_text:
    if old_prompt not in glow_text:
        raise SystemExit('AI marquee prompt target missing')
    glow_text = glow_text.replace(old_prompt, new_prompt, 1)

# Compact header is physically aligned with the avatar/HUD row: no hidden 10px
# top offset. Non-header placements retain the historical spacing.
glow_text = glow_text.replace(
    '      padding: const EdgeInsets.only(top: 10),\n',
    '      padding: EdgeInsets.only(top: widget.compactHeader ? 0 : 10),\n',
    2,
)
write(glow, glow_text)


# 8) Ten sensory/desire prompts. If admin has fewer, merge them with defaults so
#    the ticker still has a full ten-topic loop without discarding admin copy.
copy_path = 'lib/src/core/content/app_copy_provider.dart'
copy_text = read(copy_path)
old_defaults = """const defaultDashboardAiPrompts = <String>[
  'What are you looking for?',
  'Craving the flavor of the best pizza?',
  'Smell fresh flowers nearby?',
  'Looking for a relaxing massage?',
  'Taste a juicy local burger?',
];
"""
new_defaults = """const defaultDashboardAiPrompts = <String>[
  'What are you looking for?',
  'Craving hot pizza right now?',
  'Want fresh flowers you can almost smell?',
  'Need a chauffeur for a smooth ride?',
  'Ready for a relaxing massage?',
  'Looking for a beach house with an ocean view?',
  'Want a yacht escape with salt air and sunset?',
  'Hungry for a private chef tonight?',
  'Looking for live music and a night out?',
  'Need someone local to make life easier?',
];
"""
if new_defaults not in copy_text:
    if old_defaults not in copy_text:
        raise SystemExit('default dashboard prompt target missing')
    copy_text = copy_text.replace(old_defaults, new_defaults, 1)
old_return = """    final prompts = raw
        .split(RegExp(r'[\\r\\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(12)
        .toList(growable: false);
    return prompts.isEmpty ? defaultDashboardAiPrompts : prompts;
"""
new_return = """    final prompts = raw
        .split(RegExp(r'[\\r\\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(12)
        .toList(growable: false);
    if (prompts.isEmpty) return defaultDashboardAiPrompts;
    final merged = <String>[];
    final seen = <String>{};
    for (final prompt in <String>[...prompts, ...defaultDashboardAiPrompts]) {
      if (seen.add(prompt.toLowerCase())) merged.add(prompt);
      if (merged.length == 10) break;
    }
    return merged;
"""
if new_return not in copy_text:
    if old_return not in copy_text:
        raise SystemExit('dashboard prompt merge target missing')
    copy_text = copy_text.replace(old_return, new_return, 1)
write(copy_path, copy_text)


# 9) Add a small source-level guard for the exact release regressions we just
#    repaired. This complements the existing functional media/privacy tests.
guard = ROOT / 'test/final_release_polish_guard_test.dart'
guard.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HLS requires ready processing', () {
    final source = File('lib/src/features/swipes/domain/models/listing.dart')
        .readAsStringSync();
    expect(source, contains("return processing == 'ready';"));
  });

  test('native soundtrack delivery is explicit and looped', () {
    final android = File(
      'android/app/src/main/kotlin/com/swipess/app/MainActivity.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final recut = File(
      'lib/src/features/camera/data/video_recut_v2_io.dart',
    ).readAsStringSync();

    expect(android, contains('.setIsLooping(true)'));
    expect(android, contains('withAudioFrom(listOf(musicItem))'));
    expect(ios, contains('AVMutableAudioMix()'));
    expect(ios, contains('exporter.audioMix = audioMix'));
    expect(recut, isNot(contains('.bin')));
    expect(recut, contains("'mp3', 'm4a', 'aac', 'wav', 'ogg'"));
  });

  test('quick filters preserve web aspect and never use dead black empty cards', () {
    final source = File(
      'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart',
    ).readAsStringSync();
    expect(source, contains('cacheWidth: kIsWeb ? null : cacheW'));
    expect(source, isNot(contains('cacheHeight: cacheH')));
    expect(source, contains('_emptyCategoryBackdrop()'));
  });

  test('dashboard header uses ten sequential sensory marquee prompts', () {
    final topBar = File('lib/src/core/widgets/app_top_bar.dart').readAsStringSync();
    final search = File('lib/src/core/widgets/glow_search_bar.dart').readAsStringSync();
    final copy = File('lib/src/core/content/app_copy_provider.dart').readAsStringSync();

    expect(topBar, contains('crossAxisAlignment: CrossAxisAlignment.center'));
    expect(search, contains('TweenAnimationBuilder<double>'));
    expect(search, contains('const Duration(milliseconds: 5200)'));
    expect(search, contains('widget.compactHeader ? 0 : 10'));
    expect(copy, contains('Need a chauffeur for a smooth ride?'));
    expect(copy, contains('Want a yacht escape with salt air and sunset?'));
  });
}
""")

print('Final Swipess native/media/dashboard review polish applied.')
