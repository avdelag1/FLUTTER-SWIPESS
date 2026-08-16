import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, this.featureName});

  final String? featureName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen = MediaQuery.sizeOf(context);
    final maxHeight = screen.height * 0.96;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppTheme.dashBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 32)
                      .clamp(280.0, 520.0)
                      .toDouble();

                  // The paywall is intentionally non-scrollable. FittedBox only
                  // scales down on very short devices so every package, the
                  // centered 3-month banner and the CTA remain on-screen.
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFFFC107),
                              size: 38,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              featureName != null
                                  ? 'Unlock $featureName'
                                  : 'Unlock Swipess',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 23,
                                letterSpacing: -0.5,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Choose the access level that fits you. Your primary navigation stays available when you return.',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(165),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 360),
                                child: _PromoBanner(
                                  key: const ValueKey('three-month-promo'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _PackageTile(
                              title: 'Package 1',
                              benefits: const [
                                '5 listings/topic',
                                'Virtual Card',
                                'Events',
                                '15 Message Tokens',
                              ],
                              color: const Color(0xFF60A5FA),
                            ),
                            const SizedBox(height: 8),
                            _PackageTile(
                              title: 'Package 2',
                              benefits: const [
                                '10 listings/topic',
                                'Swipess AI',
                                'Events + Virtual Card',
                                '25 Message Tokens',
                              ],
                              color: const Color(0xFFB46CFF),
                              isRecommended: true,
                            ),
                            const SizedBox(height: 8),
                            _PackageTile(
                              title: 'Premium',
                              benefits: const [
                                'Unlimited listings',
                                'Unlimited AI',
                                'Promote listings',
                                'Unlimited Tokens',
                              ],
                              color: const Color(0xFFFFC107),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                key: const ValueKey('paywall-view-packages'),
                                onPressed: () {
                                  AppHaptics.medium();
                                  final router = GoRouter.of(context);
                                  Navigator.of(context).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    router.push(AppPaths.subscriptionPackages);
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.brandPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  elevation: 8,
                                  shadowColor: AppTheme.brandPrimary.withAlpha(120),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'VIEW PACKAGES & BENEFITS',
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.brandPrimary.withAlpha(48),
            const Color(0xFF9D4EDD).withAlpha(48),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.brandPrimary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandPrimary.withAlpha(42),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.celebration_rounded,
            color: AppTheme.brandPrimary,
            size: 25,
          ),
          const SizedBox(height: 5),
          Text(
            '3 MONTHS FREE ACCESS',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.brandPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Promo: Package 2 access for eligible free users.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.title,
    required this.benefits,
    required this.color,
    this.isRecommended = false,
  });

  final String title;
  final List<String> benefits;
  final Color color;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: isRecommended ? color.withAlpha(25) : Colors.white.withAlpha(9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended ? color.withAlpha(220) : Colors.white.withAlpha(30),
          width: isRecommended ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              if (isRecommended) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'RECOMMENDED',
                    style: GoogleFonts.plusJakartaSans(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 8.5,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final benefit in benefits)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      benefit,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(225),
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void showPaywall(BuildContext context, {String? featureName}) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PaywallScreen(featureName: featureName),
  );
}
