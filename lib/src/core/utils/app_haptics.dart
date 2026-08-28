import 'package:flutter/services.dart';

/// Advanced Haptic Engine for Swipess
/// Centralizes all haptic patterns to ensure a consistent, premium feel.
class AppHaptics {
  /// Slight bump. Use for minor UI interactions (opening menus, toggling switches).
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Solid bump. Use for primary button presses and successful state changes.
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Deep bump. Use for destructive actions or major transitions.
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Subtle click. Use for selection changes (picker wheels, sliders, map pins).
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Double vibration pattern. Use for successful purchases or matches.
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// Stutter vibration. Use for errors or rejections (running out of tokens).
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.heavyImpact();
  }

  /// A satisfying "snap" when a swipe is registered (like Tinder).
  static Future<void> swipeSnap() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    await HapticFeedback.lightImpact();
  }

  /// Tiny native-style acknowledgement when voice input opens. This deliberately
  /// uses the platform sound API instead of an audio package/asset so it is
  /// instant, respects the device's sound policy, and adds no playback engine.
  static Future<void> voiceStart() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.lightImpact();
  }

  /// One crisp tick for the visible 3 → 2 → 1 hands-free countdown.
  static Future<void> countdownTick(int value) async {
    await SystemSound.play(SystemSoundType.click);
    if (value <= 1) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.selectionClick();
    }
  }

  /// Confirms an automatic voice send without introducing a long sound effect.
  static Future<void> voiceCommit() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.mediumImpact();
  }

  /// Shared in-app notification tone. Important events get the platform alert;
  /// routine confirmations stay on the subtle system click.
  static Future<void> notification({bool important = false}) async {
    await SystemSound.play(
      important ? SystemSoundType.alert : SystemSoundType.click,
    );
    if (important) {
      await HapticFeedback.selectionClick();
    }
  }
}
