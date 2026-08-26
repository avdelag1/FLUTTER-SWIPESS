import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `CAMERA_FILTERS` — ColorFilter matrices for listing camera preview.
enum CapCameraFilter {
  none,
  vivid,
  warm,
  cool,
  vintage,
  noir,
  dramatic,
  silvertone,
  fade,
}

extension CapCameraFilterX on CapCameraFilter {
  String get label => switch (this) {
    CapCameraFilter.none => 'Original',
    CapCameraFilter.vivid => 'Vivid',
    CapCameraFilter.warm => 'Warm',
    CapCameraFilter.cool => 'Cool',
    CapCameraFilter.vintage => 'Vintage',
    CapCameraFilter.noir => 'Noir',
    CapCameraFilter.dramatic => 'Dramatic',
    CapCameraFilter.silvertone => 'Silver',
    CapCameraFilter.fade => 'Fade',
  };

  /// Approximate Cap CSS filters as a ColorFilter matrix.
  ColorFilter get colorFilter {
    return switch (this) {
      CapCameraFilter.none => const ColorFilter.matrix(<double>[
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      CapCameraFilter.vivid => ColorFilter.matrix(_satContrast(1.4, 1.1)),
      CapCameraFilter.warm => ColorFilter.matrix(_warm()),
      CapCameraFilter.cool => ColorFilter.matrix(_cool()),
      CapCameraFilter.vintage => ColorFilter.matrix(_vintage()),
      CapCameraFilter.noir => ColorFilter.matrix(_noir()),
      CapCameraFilter.dramatic => ColorFilter.matrix(_satContrast(1.1, 1.3)),
      CapCameraFilter.silvertone => ColorFilter.matrix(_silver()),
      CapCameraFilter.fade => ColorFilter.matrix(_satContrast(0.8, 0.9)),
    };
  }
}

List<double> _satContrast(double sat, double contrast) {
  final s = sat;
  final c = contrast;
  final t = (1 - c) / 2 * 255;
  final rw = 0.2126, gw = 0.7152, bw = 0.0722;
  return [
    (rw * (1 - s) + s) * c,
    gw * (1 - s) * c,
    bw * (1 - s) * c,
    0,
    t,
    rw * (1 - s) * c,
    (gw * (1 - s) + s) * c,
    bw * (1 - s) * c,
    0,
    t,
    rw * (1 - s) * c,
    gw * (1 - s) * c,
    (bw * (1 - s) + s) * c,
    0,
    t,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _warm() => [
  1.15,
  0.05,
  0,
  0,
  8,
  0.05,
  1.05,
  0,
  0,
  4,
  0,
  0,
  0.9,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> _cool() => [
  0.92,
  0,
  0.08,
  0,
  6,
  0,
  1.0,
  0.05,
  0,
  4,
  0.05,
  0.05,
  1.15,
  0,
  8,
  0,
  0,
  0,
  1,
  0,
];

List<double> _vintage() => [
  0.9,
  0.2,
  0.1,
  0,
  12,
  0.15,
  0.85,
  0.1,
  0,
  8,
  0.1,
  0.15,
  0.7,
  0,
  4,
  0,
  0,
  0,
  1,
  0,
];

List<double> _noir() => [
  0.33,
  0.33,
  0.33,
  0,
  0,
  0.33,
  0.33,
  0.33,
  0,
  0,
  0.33,
  0.33,
  0.33,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> _silver() => [
  0.6,
  0.25,
  0.15,
  0,
  8,
  0.25,
  0.55,
  0.15,
  0,
  8,
  0.15,
  0.2,
  0.55,
  0,
  8,
  0,
  0,
  0,
  1,
  0,
];

class CameraFiltersStrip extends StatelessWidget {
  const CameraFiltersStrip({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CapCameraFilter selected;
  final ValueChanged<CapCameraFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final f in CapCameraFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  onSelected(f);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected == f
                        ? Colors.white
                        : Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected == f
                          ? Colors.white
                          : Colors.white.withAlpha(30),
                    ),
                  ),
                  child: Text(
                    f.label.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: selected == f ? Colors.black : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
