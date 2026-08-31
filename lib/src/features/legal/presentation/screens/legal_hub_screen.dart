import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contracts_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/lawyer_services_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, top + 24, 24, 60),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: CapBackButton(),
            ),
            const SizedBox(height: 24),
            Text(
              'LEGAL HUB',
              style: AppTheme.displayItalic.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              'Your secure center for binding digital contracts and professional legal counsel.',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),

            _PremiumActionCard(
              title: 'DocuSign Contracts',
              subtitle:
                  'Draft, send, and sign legally binding leases and agreements directly on your device.',
              icon: Icons.draw_rounded,
              color: const Color(0xFF00C6FF),
              onTap: () {
                AppHaptics.medium();
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const ContractsScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            _PremiumActionCard(
              title: 'Hire a Lawyer',
              subtitle:
                  'Video call or WhatsApp our network of verified attorneys. Purchase flat-fee legal packages.',
              icon: Icons.gavel_rounded,
              color: const Color(0xFF6366F1),
              onTap: () {
                AppHaptics.medium();
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => const LawyerServicesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: MatteSurface.cardFill(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: MatteSurface.hairline(context)),
              ),
              child: Column(
                children: [
                  Icon(Icons.security_rounded, size: 32, color: ink),
                  const SizedBox(height: 16),
                  Text(
                    'BANK-GRADE SECURITY',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All digital signatures and contracts generated on Swipess are cryptographically secured and legally binding in 180+ jurisdictions under the ESIGN Act.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumActionCard extends StatelessWidget {
  const _PremiumActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF0A0A0C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: MatteSurface.hairline(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isLight ? 10 : 40),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withAlpha(isLight ? 25 : 40),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: muted),
          ],
        ),
      ),
    );
  }
}
