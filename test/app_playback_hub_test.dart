import 'package:flutter_swipes/src/core/services/app_playback_hub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hub = AppPlaybackHub.instance;

  setUp(hub.resetForTest);
  tearDown(hub.resetForTest);

  test('claiming a new holder pauses the previous one', () {
    var firstPaused = 0;
    var secondPaused = 0;
    hub.register('one', pause: () => firstPaused++);
    hub.register('two', pause: () => secondPaused++);

    hub.claim('one');
    hub.claim('two');

    expect(hub.holder, 'two');
    expect(firstPaused, 1);
    expect(secondPaused, 0);
  });

  test('background pauses everyone and resume restores only the holder', () {
    var onePaused = 0;
    var oneResumed = 0;
    var twoPaused = 0;
    var twoResumed = 0;
    hub.register('one', pause: () => onePaused++, resume: () => oneResumed++);
    hub.register('two', pause: () => twoPaused++, resume: () => twoResumed++);

    hub.claim('two');
    hub.pauseForBackground();
    expect(hub.backgrounded, isTrue);
    expect(onePaused, 1);
    expect(twoPaused, 1);

    hub.resumeFromBackground();
    expect(hub.backgrounded, isFalse);
    expect(hub.holder, 'two');
    expect(oneResumed, 0);
    expect(twoResumed, 1);
  });
}
