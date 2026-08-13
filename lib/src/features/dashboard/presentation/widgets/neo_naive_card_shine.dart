import 'package:flutter/material.dart';

/// Cap `neo-naive-card-shine` — rim light + specular highlight on quick-filter cards.
///
/// Replicates the Capacitor CSS:
/// - `::before` → inset box-shadow rim light (white edges)
/// - `::after` → radial gradient blob (soft-light specular highlight)
class NeoNaiveCardShine extends StatelessWidget {
  const NeoNaiveCardShine({
    super.key,
    required this.borderRadius,
  });

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Rim light (::before equivalent)
            Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withAlpha(100),
                  width: 1.5,
                ),
              ),
            ),
            // Top edge highlight
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withAlpha(0),
                      Colors.white.withAlpha(130),
                      Colors.white.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
            // Specular highlight blob (::after equivalent)
            Positioned(
              top: -20,
              left: -30,
              width: 200,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.6),
                    radius: 1.2,
                    colors: [
                      Colors.white.withAlpha(50),
                      Colors.white.withAlpha(18),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.32, 0.68],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
