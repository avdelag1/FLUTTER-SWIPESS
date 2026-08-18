import 'package:flutter/material.dart';

/// Legacy auth/background surface.
///
/// The old animated starfield and shooting-star painter were intentionally
/// removed. Keeping this widget as a plain black surface lets every existing
/// auth/splash caller stay compatible without reintroducing decorative motion
/// or background repaint work.
class StarfieldBackground extends StatelessWidget {
  const StarfieldBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ColoredBox(color: Colors.black),
    );
  }
}
