import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Temporary stand-in for a Capacitor route that is not fully ported yet.
class CapPlaceholderScreen extends StatelessWidget {
  const CapPlaceholderScreen({
    super.key,
    required this.title,
    required this.path,
    this.note,
  });

  final String title;
  final String path;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: AmbientPageBackground(
        fill: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CapBackButton(),
                const SizedBox(height: 24),
                Text(
                  title.toUpperCase(),
                  style: AppTheme.displayItalic.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 8),
                Text(
                  path,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                NeoNaiveCard(
                  child: Text(
                    note ??
                        'This Capacitor route is registered for parity. UI is still being ported.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withAlpha(200),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
                const Spacer(),
                BrandPrimaryButton(
                  label: 'Back to dashboard',
                  onPressed: () => context.go('/client/dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
