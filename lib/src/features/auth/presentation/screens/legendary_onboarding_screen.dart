import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run cinematic welcome slides after access grant.
class LegendaryOnboardingScreen extends StatefulWidget {
  const LegendaryOnboardingScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  static const prefsKey = 'swipess_legendary_onboarding_done';

  static Future<bool> hasCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return true;
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
      desc: 'Swipe through places worth seeing. Connect directly with owners, buyers and renters.',
      networkImage: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&q=80&w=1200',
      assetImage: null,
      icon: Icons.place_rounded,
    ),
    _Slide(
      title: 'Trusted Network',
      desc: 'Find roommates, services and local people through one connected community.',
      networkImage: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=1200',
      assetImage: null,
      icon: Icons.groups_rounded,
    ),
    _Slide(
      title: 'AI Concierge',
      desc: 'Search naturally, discover faster and let AI help you find what matters around you.',
      networkImage: null,
      assetImage: 'assets/images/onboarding/ai_chat_onboarding.png',
      icon: Icons.auto_awesome_rounded,
    ),
    _Slide(
      title: 'Resident Identity',
      desc: 'Keep your local identity, profile and verified documents together in your Swipess card.',
      networkImage: null,
      assetImage: 'assets/images/onboarding/resident_girl_onboarding.png',
      icon: Icons.verified_user_rounded,
      showVapCard: true,
    ),
  ];

  Future<void> _finish() async {
    AppHaptics.medium();
    await LegendaryOnboardingScreen.markCompleted();
    widget.onFinish();
  }

  void _next() {
    AppHaptics.medium();
    if (_index >= _slides.length - 1) {
      _finish();
      return;
    }
    setState(() => _index += 1);
  }

  void _previous() {
    if (_index == 0) return;
    AppHaptics.light();
    setState(() => _index -= 1);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) {
      _next();
    } else if (velocity > 250) {
      _previous();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 620),
              transitionBuilder: (child, animation) {
                final slideIn =
                    Tween<Offset>(
                      begin: const Offset(.045, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slideIn, child: child),
                );
              },
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
                    Color(0x22000000),
                    Color(0x33000000),
                    Color(0xD9000000),
                    Colors.black,
                  ],
                  stops: [0, .38, .73, 1],
                ),
              ),
            ),
            if (slide.showVapCard)
              Align(
                alignment: const Alignment(0, -0.12),
                child: _VapPreviewCard(),
              ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 14, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SWIPESS',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const Spacer(),
                        if (!isLast)
                          TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              'SKIP',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else
                          SizedBox(height: 40),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(115),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(slide.icon, color: Colors.white, size: 21),
                    ),
                    SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      child: Text(
                        slide.title,
                        key: ValueKey('title-$_index'),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 35,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.1,
                          height: 1.02,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      child: Text(
                        slide.desc,
                        key: ValueKey('desc-$_index'),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withAlpha(205),
                          fontSize: 14.5,
                          height: 1.42,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _slides.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.only(right: 6),
                            width: i == _index ? 24 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white.withAlpha(55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        const Spacer(),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppTheme.brandPrimary,
                              shadowColor: Colors.black.withAlpha(100),
                              elevation: 8,
                              padding: EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            iconAlignment: IconAlignment.end,
                            icon: Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              isLast ? 'ENTER SWIPESS' : 'CONTINUE',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Swipe to explore',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(115),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    return Opacity(opacity: .76, child: SizedBox.expand(child: image));
  }
}

class _VapPreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xB514171D),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(145),
            blurRadius: 34,
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
              Icon(Icons.verified_user_rounded, color: Colors.white),
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
          SizedBox(height: 28),
          Text(
            'ORIGIN',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
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
          SizedBox(height: 14),
          Text(
            'DURATION',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
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
