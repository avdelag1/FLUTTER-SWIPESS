import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  test('listing deck keeps the same tiny decoder budget as Events', () {
    final stack = _source(
      'lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart',
    );

    expect(stack, contains('static const _videoPreloadAhead = 1;'));
    expect(stack, contains('static const _videoPreloadBehind = 0;'));
    expect(stack, contains('_videoWarmGeneration'));
    expect(stack, contains('_videoWarmInFlight'));
  });

  test('listing and quick-filter photos use physical display density', () {
    final deck = _source(
      'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',
    );
    final quickFilter = _source(
      'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart',
    );

    expect(deck, contains('MediaQuery.devicePixelRatioOf(context)'));
    expect(deck, contains('FilterQuality.high'));
    expect(quickFilter, contains('cacheHeight: cacheH'));
    expect(quickFilter, contains('FilterQuality.high'));
  });

  test('browser uploads attempt a compact Apple-playable delivery export', () {
    final optimizer = _source(
      'lib/src/features/camera/data/video_upload_optimizer_html.dart',
    );
    final exporter = _source(
      'lib/src/features/camera/data/video_recut_v3_html.dart',
    );

    expect(optimizer, contains('Try\n  // the delivery export'));
    expect(optimizer, isNot(contains('final sourceIsMp4')));
    expect(exporter, contains('canvasWidth = 720;'));
    expect(exporter, contains('canvasHeight = 1280;'));
    // The source element must not be pushed off-screen: iOS PWA throttles
    // an occluded source and bakes a visibly low-frame-rate upload.
    expect(exporter, contains("..left = '0'"));
    expect(exporter, isNot(contains("..left = '-10000px'")));
    expect(exporter, contains('requestVideoFrameCallback'));
  });

  test('worker creates stable 30fps listing delivery renditions', () {
    final worker = _source('api/video-transcode.js');

    expect(worker, contains("'-fps_mode'"));
    expect(worker, contains("'cfr'"));
  });

  test('an untouched listing video is never silently made into a short crop', () {
    final editor = _source(
      'lib/src/features/camera/presentation/screens/video_cropper_screen_v2.dart',
    );
    final nativeOptimizer = _source(
      'lib/src/features/camera/data/video_upload_optimizer_io.dart',
    );
    final draftProvider = _source(
      'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    );

    expect(editor, contains('.preset(VideoCropperScreen.maxSeconds)'));
    expect(editor, contains('final noExplicitTrim ='));
    expect(
      nativeOptimizer,
      contains('optimizeVideoForUpload(XFile source) async => source;'),
    );
    expect(nativeOptimizer, isNot(contains('portraitCrop: true')));
    expect(
      draftProvider,
      contains('maxDuration: const Duration(seconds: 60)'),
    );
  });
}
