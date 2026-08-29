import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared iOS-style motion tokens and transition helpers.
abstract final class IosMotion {
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 420);

  /// Standard iOS ease — snappy without bounce.
  static const Curve enter = Cubic(0.25, 0.1, 0.25, 1);
  static const Curve exit = Cubic(0.4, 0, 0.2, 1);

  static const sheetAnimation = AnimationStyle(
    duration: medium,
    reverseDuration: fast,
    curve: enter,
    reverseCurve: exit,
  );

  static const modalBarrier = Color(0x99000000);

  static Widget crossFade({
    required Widget child,
    required Object key,
    Duration duration = medium,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: enter,
      switchOutCurve: exit,
      transitionBuilder: _fadeSlide,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }

  static Widget _fadeSlide(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: enter);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.028),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  static CustomTransitionPage<T> fadeSlidePage<T>({
    required LocalKey key,
    required Widget child,
    Duration duration = medium,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      transitionDuration: duration,
      reverseTransitionDuration: fast,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: enter,
          reverseCurve: exit,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
