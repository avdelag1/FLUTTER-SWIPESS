import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `PromoteCTACard` — full-bleed end-of-events-feed promote onboarding.
class PromoteCTACard extends StatelessWidget {
  const PromoteCTACard({super.key, required this.onPromote});

  final VoidCallback onPromote;

  static const _features = [
    (
      Icons.movie_creation_outlined,
      'Video commercials',
      'Upload clips up to 1 minute — same reel-style feed users swipe',
    ),
    (
      Icons.upload_rounded,
      'Photos & covers',
      'Crop, quality, and poster frames so your event looks sharp',
    ),
    (
      Icons.bolt_rounded,
      'Direct WhatsApp leads',
      'Seekers tap your card and message you instantly',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      color: const Color(0xFF070708),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -0.85),
                radius: 1.1,
                colors: [Color(0x59FF4D00), Color(0x00050506)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.95, 0.9),
                radius: 0.9,
                colors: [Color(0x2E0EA5E9), Color(0x00050506)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0C0C0E), Color(0xFF050506)],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: bottom + 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(90),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: Color(0xFFFB923C), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'SWIPESS EVENTS',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'PUT YOUR NIGHT\n',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          height: 0.95,
                          letterSpacing: -1.4,
                        ),
                      ),
                      TextSpan(
                        text: 'ON THE FEED',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 0.95,
                          letterSpacing: -1.4,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [Color(0xFFFF4D00), Color(0xFF38BDF8)],
                            ).createShader(
                              const Rect.fromLTWH(0, 0, 280, 60),
                            ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Promote parties, dinners, and brands with photo + video commercials — reviewed in under 24h.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white60,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                for (final f in _features) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0x40F97316), Color(0x330EA5E9)],
                            ),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(f.$1,
                              color: const Color(0xFFFB923C), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.$2,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                f.$3,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onPromote();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D00), Color(0xFFEA580C)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.transparent,
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.campaign_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          'Request promotion',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Free to apply · From \$4.99/week after approval · Video up to 1 min',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
