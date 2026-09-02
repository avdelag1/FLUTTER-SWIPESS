import 'package:flutter_swipes/src/features/camera/domain/video_trim_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts with a ten second window when video is long enough', () {
    final selection = VideoTrimSelection.initial(75);
    expect(selection.start, 0);
    expect(selection.end, 10);
    expect(selection.length, 10);
  });

  test('preset buttons create 5 10 15 and 20 second windows', () {
    var selection = VideoTrimSelection.initial(90).moveTo(25);
    selection = selection.preset(20);
    expect(selection.start, 25);
    expect(selection.end, 45);

    selection = selection.preset(5);
    expect(selection.start, 25);
    expect(selection.end, 30);
  });

  test('moving the middle snaps the whole window every five seconds', () {
    final selection = VideoTrimSelection.initial(90);
    expect(selection.moveTo(12.4).start, 10);
    expect(selection.moveTo(12.6).start, 15);
    expect(selection.moveTo(83).start, 80);
    expect(selection.moveTo(83).end, 90);
  });

  test('left and right edges resize in five second steps', () {
    final base = VideoTrimSelection.initial(90).preset(20);
    final left = base.resizeStartTo(7.8);
    expect(left.start, 10);
    expect(left.end, 20);

    final moved = base.moveTo(20);
    final right = moved.resizeEndTo(37.9);
    expect(right.start, 20);
    expect(right.end, 40);
  });

  test('selection never exceeds twenty seconds', () {
    final selection = VideoTrimSelection.initial(90)
        .preset(20)
        .resizeEndTo(65);
    expect(selection.length, 20);
  });

  test('short videos keep their real full duration', () {
    final selection = VideoTrimSelection.initial(3.4);
    expect(selection.start, 0);
    expect(selection.end, 3.4);
    expect(selection.length, 3.4);
  });
}
