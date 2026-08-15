import 'package:flutter/material.dart';

/// Transparent spacing well for the dashboard quick-filter photo cards.
///
/// The previous animated wash looked like a red/colored backing card around
/// the filters. Keeping this compatibility wrapper avoids framing the photos.
class QfWellGlow extends StatelessWidget {
  const QfWellGlow({
    super.key,
    required this.child,
    required this.isLight,
    this.padding = const EdgeInsets.all(6),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  final Widget child;
  final bool isLight;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}
