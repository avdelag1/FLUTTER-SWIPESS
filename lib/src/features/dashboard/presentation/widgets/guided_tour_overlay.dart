import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time post-login welcome for the complimentary Swipess access period.
///
/// The existing preference key is intentionally preserved so members who have
/// already completed onboarding are not interrupted again.
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

class _DashboardBenefit {
  const _DashboardBenefit(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay> {
  bool _active = false;
  bool _starting = false;

  static const _benefits = <_DashboardBenefit>[
    _DashboardBenefit(
      Icons.auto_awesome_rounded,
      'AI tools',
      'Concierge, smarter discovery and AI listing creation.',
    ),
    _DashboardBenefit(
      Icons.add_business_rounded,
      'Listings',
      'Post and explore properties, services, motos and more.',
    ),
    _DashboardBenefit(
      Icons.badge_rounded,
      'Virtual ID',
      'Use Swipess member identity and local community tools.',
    ),
    _DashboardBenefit(
      Icons.event_available_rounded,
      'Events & legal',
      'Explore opportunities, events and available legal tools.',
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
    if (_starting || _active) return;
    _starting = true;
    final done = await GuidedTourOverlay.hasCompleted();
    if (!mounted || done) {
      _starting = false;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() {
      _starting = false;
      _active = true;
    });
  }

  Future<void> _finish() async {
    AppHaptics.medium();
    await GuidedTourOverlay.markCompleted();
    if (!mounted) return;
    setState(() => _active = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final maxCardHeight = media.size.height - media.padding.vertical - 32;

    return Material(
      color: Colors.black.withAlpha(205),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: maxCardHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withAlpha(28)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 40,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.7, -1.0),
                                radius: 1.1,
                                colors: [
                                  AppTheme.brandPrimary.withAlpha(55),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: 'Close',
                                onPressed: _finish,
                                icon: const Icon(Icons.close_rounded),
                                color: Colors.white70,
                              ),
                            ),
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFFFC247),
                              size: 42,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Welcome to Swipess',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 28,
                                height: 1.05,
                                letterSpacing: -0.8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandPrimary.withAlpha(24),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppTheme.brandPrimary.withAlpha(150),
                                  ),
                                ),
                                child: Text(
                                  'YOUR FIRST 3 MONTHS ARE ON US',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.brandPrimary,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Explore the Swipess member experience with complimentary access for three months. Use the tools, discover what matters to you, and get to know the platform before choosing a membership.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(210),
                                fontSize: 13.5,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final benefit in _benefits)
                                  SizedBox(
                                    width: 270,
                                    child: _BenefitTile(benefit: benefit),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'AFTER YOUR COMPLIMENTARY ACCESS',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (var i = 0;
                                    i < IapCatalog.subscriptions.length;
                                    i++) ...[
                                  Expanded(
                                    child: _CompactPlan(
                                      offer: IapCatalog.subscriptions[i],
                                    ),
                                  ),
                                  if (i != IapCatalog.subscriptions.length - 1)
                                    const SizedBox(width: 7),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No paid plan is selected by this welcome screen. After the complimentary period, continued premium access requires a membership.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(120),
                                fontSize: 10.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _finish,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.brandPrimary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: Text(
                                  'CONTINUE TO SWIPESS',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    letterSpacing: 0.4,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.benefit});

  final _DashboardBenefit benefit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.brandPrimary.withAlpha(24),
              shape: BoxShape.circle,
            ),
            child: Icon(benefit.icon, color: AppTheme.brandPrimary, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  benefit.subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white60,
                    fontSize: 9.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
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

class _CompactPlan extends StatelessWidget {
  const _CompactPlan({required this.offer});

  final IapOffer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: offer.popular
              ? AppTheme.brandPrimary.withAlpha(150)
              : Colors.white.withAlpha(22),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            offer.name.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 8.5,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            offer.priceLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (offer.durationLabel != null)
            Text(
              offer.durationLabel!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
