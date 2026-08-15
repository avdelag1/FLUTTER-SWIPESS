import 'package:flutter/material.dart';

/// Flattens the map view entirely as requested by user.
class MapPerspectiveStage extends StatelessWidget {
  const MapPerspectiveStage({
    super.key,
    required this.progress,
    required this.child,
  });

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
