import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/map/data/map_camera.dart';

/// Widget-level airplane pitch. Raster tiles stay unrotated (web-safe);
/// the whole map stage is perspective-tilted like Cap's Mapbox fly view.
class MapPerspectiveStage extends StatelessWidget {
  const MapPerspectiveStage({
    super.key,
    required this.progress,
    required this.child,
  });

  /// 0 = high-altitude dive, 1 = cruise.
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final pitch = MapCameraMath.openPitch +
        (MapCameraMath.cruisePitch - MapCameraMath.openPitch) * t;
    final bank = MapCameraMath.openBankDegrees *
        (1 - t) *
        3.141592653589793 /
        180;
    return ClipRect(
      child: Transform(
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        transform: Matrix4.identity()
          ..setEntry(3, 2, MapCameraMath.perspective)
          ..rotateX(-pitch)
          ..rotateZ(bank)
          ..translate(0.0, MapCameraMath.stageTranslateY, 0.0)
          ..scaleByDouble(
            MapCameraMath.stageScale,
            MapCameraMath.stageScale,
            MapCameraMath.stageScale,
            1,
          ),
        child: child,
      ),
    );
  }
}
