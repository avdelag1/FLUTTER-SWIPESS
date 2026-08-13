import 'package:flutter/material.dart';

/// Pulsing cyan GPS dot — Cap `syncUserGpsDotOnMap`.
class MapGpsDot extends StatefulWidget {
  const MapGpsDot({super.key});

  @override
  State<MapGpsDot> createState() => _MapGpsDotState();
}

class _MapGpsDotState extends State<MapGpsDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        final ring = 10.0 + 18.0 * t;
        return SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromRGBO(0, 198, 255, 0.35 * (1 - t)),
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x8800C6FF), blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
