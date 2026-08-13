import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `GuidedTour` + `useGuidedTour` elite steps — cinematic post-login intro.
class GuidedTourOverlay extends StatefulWidget {
  const GuidedTourOverlay({super.key, required this.enabled});

  final bool enabled;

  static const prefsKey = 'guidedTourCompleted';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
  }

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay> {
  bool _active = false;
  int _step = 0;

  static const _steps = [
    (
      'Welcome to Swipess',
      'Right here you will be able to find properties, yachts, motorcycles, bicycles, and workers. You can also promote your job or work by posting your own listings.',
      Icons.place_rounded,
      [Color(0xFFFF4D00), Color(0xFFEB4898)],
    ),
    (
      'The Power of AI',
      'Use the AI to effortlessly create your profile or upload listings. You can also generate legal contracts and talk directly to our AI legal advisors.',
      Icons.auto_awesome_rounded,
      [Color(0xFF6366F1), Color(0xFF22D3EE)],
    ),
    (
      'Trust & Local Identity',
      'Get the benefit of a Virtual ID Card. This helps identify you as a trusted local person within the community ecosystem.',
      Icons.verified_user_rounded,
      [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
    (
      'Events & Opportunities',
      'Promote your local events, and remember—you can also make money by posting jobs and connecting with workers.',
      Icons.apartment_rounded,
      [Color(0xFFF59E0B), Color(0xFFFF4D00)],
    ),
    (
      'A Real Tool for the Community',
      "This isn't something we just want to sell. This is a real tool built to help the community. This is a place where everybody must respect each other, help each other, and connect in the best way possible.",
      Icons.check_circle_rounded,
      [Color(0xFF10B981), Color(0xFF06B6D4)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _maybeStart();
  }

  @override
  void didUpdateWidget(covariant GuidedTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) _maybeStart();
  }

  Future<void> _maybeStart() async {
    final done = await GuidedTourOverlay.hasCompleted();
    if (!mounted || done) return;
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _active = true);
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await GuidedTourOverlay.markCompleted();
    if (!mounted) return;
    setState(() {
      _active = false;
      _step = 0;
    });
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_step >= _steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _step += 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: step.$4,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.1,
                colors: [
                  Colors.white.withAlpha(50),
                  Colors.transparent,
                  Colors.black.withAlpha(160),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                children: [
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Column(
                      key: ValueKey(_step),
                      children: [
                        Icon(step.$3, color: Colors.white, size: 64),
                        const SizedBox(height: 24),
                        Text(
                          step.$1,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          step.$2,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(230),
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _steps.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _step ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _step
                                ? Colors.white
                                : Colors.white.withAlpha(80),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        isLast ? 'Start Exploring' : 'Next',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white.withAlpha(180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Skip intro',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'SWIPESS',
                    style: AppTheme.displayItalic.copyWith(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
