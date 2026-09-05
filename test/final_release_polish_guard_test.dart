import 'dart:io';

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
