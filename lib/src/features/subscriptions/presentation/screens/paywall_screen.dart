import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
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
                                  ? 'Continue with $featureName'
                                  : 'Continue with Swipess',
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
                              'Your complimentary access has ended. Choose the membership that fits you to keep using premium Swipess tools.',
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(165),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 14),
                            for (var i = 0;
                                i < IapCatalog.subscriptions.length;
                                i++) ...[
                              _PaidPlanTile(
                                offer: IapCatalog.subscriptions[i],
                                color: _colorForPlan(i),
                              ),
                              if (i != IapCatalog.subscriptions.length - 1)
                                const SizedBox(height: 8),
                            ],
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
                                        'VIEW MEMBERSHIP OPTIONS',
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

Color _colorForPlan(int index) {
  switch (index) {
    case 0:
      return const Color(0xFF6D7CFF);
    case 1:
      return const Color(0xFFFF3B8D);
    default:
      return const Color(0xFFFFB300);
  }
}

String _durationText(String? raw) {
  return (raw ?? '')
      .trim()
      .replaceFirst(RegExp(r'^/\s*'), '')
      .trim()
      .toUpperCase();
}

class _PaidPlanTile extends StatelessWidget {
  const _PaidPlanTile({required this.offer, required this.color});

  final IapOffer offer;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final focusBenefits = offer.benefits
        .where(
          (benefit) =>
              benefit.contains('AI ') ||
              benefit.contains('Local Expert') ||
              benefit.contains('Priority AI'),
        )
        .take(3)
        .toList();
    final badge = (offer.label ?? offer.name).toUpperCase();
    final duration = _durationText(offer.durationLabel);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: offer.popular ? color.withAlpha(28) : Colors.white.withAlpha(9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: offer.popular ? color.withAlpha(210) : color.withAlpha(90),
          width: offer.popular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(offer.popular ? 32 : 16),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(30),
                  border: Border.all(color: color.withAlpha(120)),
                ),
                child: Icon(
                  offer.popular
                      ? Icons.bolt_rounded
                      : offer.name.toLowerCase().contains('year')
                          ? Icons.workspace_premium_rounded
                          : Icons.chat_bubble_outline_rounded,
                  color: color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: RichText(
                    maxLines: 1,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: offer.priceLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        TextSpan(
                          text: duration.isEmpty ? '' : ' / $duration',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(145),
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (focusBenefits.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < focusBenefits.length; i++) ...[
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 13),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      focusBenefits[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(225),
                        fontWeight:
                            focusBenefits[i].toLowerCase().contains('unlimited')
                                ? FontWeight.w800
                                : FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (i != focusBenefits.length - 1) const SizedBox(height: 5),
            ],
          ],
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
