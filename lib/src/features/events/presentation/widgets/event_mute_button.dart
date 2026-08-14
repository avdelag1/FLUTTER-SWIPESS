import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/features/dashboard/data/deck_media_unlock.dart';

/// Cap `EventVideoMuteButton` — 44pt hit, glass chip, unlocks audio
/// in the same pointer-down as the volume change.
class EventMuteButton extends StatelessWidget {
  const EventMuteButton({
    super.key,
    required this.soundOn,
    required this.onToggle,
    this.size = 28,
  });

  final bool soundOn;
  final VoidCallback onToggle;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => unlockDeckMedia(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          unlockDeckMedia();
          onToggle();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: BreathingWidget(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0x8C000000),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  soundOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: size * 0.54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
