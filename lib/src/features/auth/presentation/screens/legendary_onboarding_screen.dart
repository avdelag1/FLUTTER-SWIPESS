import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `LegendaryOnboarding` — first-run cinematic slides after access grant.
class LegendaryOnboardingScreen extends StatefulWidget {
  const LegendaryOnboardingScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  static const prefsKey = 'swipess_legendary_onboarding_done';

  static Future<bool> hasCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return true; // Don't trap users on a spinner if prefs hang.
    }
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
  }

  @override
  State<LegendaryOnboardingScreen> createState() =>
      _LegendaryOnboardingScreenState();
}

class _LegendaryOnboardingScreenState extends State<LegendaryOnboardingScreen> {
  int _index = 0;

  static const _slides = [
    _Slide(
      title: 'Discover Properties',
      desc:
          'Find your ideal client. Buyers, tenants. And connect with direct owners.',
      networkImage:
          'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&q=80&w=1200',
      assetImage: null,
      icon: Icons.place_rounded,
    ),
    _Slide(
      title: 'Trusted Network',
      desc:
          'Find the perfect roommate or tenant. Connect with trusted people and rent together.',
      networkImage:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=1200',
      assetImage: null,
      icon: Icons.groups_rounded,
    ),
    _Slide(
      title: 'AI Concierge',
      desc:
          'Your personal assistant for finding the best local deals and private parties.',
      networkImage: null,
      assetImage: 'assets/images/onboarding/ai_chat_onboarding.png',
      icon: Icons.auto_awesome_rounded,
    ),
    _Slide(
      title: 'Resident Identity',
      desc:
          'Your digital VAP card proves you belong to the elite Swipess community.',
      networkImage: null,
      assetImage: 'assets/images/onboarding/resident_girl_onboarding.png',
      icon: Icons.verified_user_rounded,
      showVapCard: true,
    ),
  ];

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await LegendaryOnboardingScreen.markCompleted();
    widget.onFinish();
  }

  void _next() {
    HapticFeedback.mediumImpact();
    if (_index >= _slides.length - 1) {
      _finish();
      return;
    }
    setState(() => _index += 1);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: _Background(slide: slide),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x99000000),
                  Colors.black,
                ],
                stops: [0.35, 0.65, 1],
              ),
            ),
          ),
          if (slide.showVapCard)
            Align(
              alignment: const Alignment(0, -0.15),
              child: _VapPreviewCard(),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: isLast
                        ? const SizedBox(height: 44)
                        : TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              'SKIP →',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                  const Spacer(),
                  Icon(slide.icon, color: Colors.white70, size: 28),
                  const SizedBox(height: 14),
                  Text(
                    slide.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slide.desc,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? AppTheme.brandPrimary
                                : Colors.white.withAlpha(50),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      const Spacer(),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            isLast ? 'ENTER SWIPESS' : 'NEXT',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _Slide {
  const _Slide({
    required this.title,
    required this.desc,
    required this.icon,
    required this.networkImage,
    required this.assetImage,
    this.showVapCard = false,
  });

  final String title;
  final String desc;
  final IconData icon;
  final String? networkImage;
  final String? assetImage;
  final bool showVapCard;
}

class _Background extends StatelessWidget {
  const _Background({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final image = slide.assetImage != null
        ? Image.asset(slide.assetImage!, fit: BoxFit.cover)
        : Image.network(
            slide.networkImage!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: Colors.black),
          );
    return Opacity(opacity: 0.62, child: SizedBox.expand(child: image));
  }
}

class _VapPreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Colors.white70),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RESIDENT',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'VERIFIED',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF34D399),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'ORIGIN',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          Text(
            'New York',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'DURATION',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          Text(
            '1 Year Lease',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
