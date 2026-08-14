import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `FeaturePreview` soft paywall — blur locked content + Unlock CTA.
class SoftPaywallPreview extends StatelessWidget {
  const SoftPaywallPreview({
    super.key,
    required this.child,
    required this.isLocked,
    required this.featureName,
    required this.description,
    this.onUpgrade,
    this.blurSigma = 4,
  });

  final Widget child;
  final bool isLocked;
  final String featureName;
  final String description;
  final VoidCallback? onUpgrade;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
            child: IgnorePointer(child: child),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: AppTheme.dashBg.withAlpha(150),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.brandPrimary.withAlpha(36),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: AppTheme.brandPrimary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    featureName,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (onUpgrade != null) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onUpgrade,
                      icon: const Icon(Icons.auto_awesome_rounded,
                          size: 14, color: Colors.white),
                      label: Text(
                        'UNLOCK',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cap `TrialLimitBanner` — compact remaining-count banner with upgrade CTA.
/// Renders nothing while comfortably under the limit, matching Cap.
class TrialLimitBanner extends StatelessWidget {
  const TrialLimitBanner({
    super.key,
    required this.current,
    required this.limit,
    required this.featureName,
    this.onUpgrade,
  });

  final int current;
  final int limit;
  final String featureName;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    if (limit <= 0) return const SizedBox.shrink();
    final remaining = limit - current;
    final percentage = current / limit;
    final isAtLimit = current >= limit;
    final isNearLimit = percentage >= 0.8;

    if (!isAtLimit && !isNearLimit) return const SizedBox.shrink();

    if (isAtLimit) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.brandPrimary.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.brandPrimary.withAlpha(51)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You've used all your $featureName",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upgrade to continue with unlimited access',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onUpgrade != null) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onUpgrade,
                icon: const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: Colors.white),
                label: Text(
                  'Upgrade',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Near limit — softer amber nudge.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1AF59E0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33F59E0B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFFBBF24),
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '$remaining ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: '$featureName remaining today'),
                ],
              ),
            ),
          ),
          if (onUpgrade != null)
            TextButton(
              onPressed: onUpgrade,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFBBF24),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Get more',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cap locked-feature chip (read receipts / undo / etc).
class LockedFeatureChip extends StatelessWidget {
  const LockedFeatureChip({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.onUpgrade,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: NexusTheme.glassCard(radius: 18),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.brandPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (onUpgrade != null)
            TextButton(
              onPressed: onUpgrade,
              child: Text(
                'YES, IF…',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
