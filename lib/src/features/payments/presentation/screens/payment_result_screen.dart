import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor PaymentSuccess / PaymentCancel shells.
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({
    super.key,
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ),
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (success ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                      .withAlpha(40),
                  border: Border.all(
                    color: success
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (success
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withAlpha(90),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.close_rounded,
                  color: success
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                success ? 'PAYMENT SUCCESS' : 'PAYMENT CANCELLED',
                style: AppTheme.displayItalic.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message ??
                    (success
                        ? 'Your package is unlocking. Tokens & premium features refresh on the next sync.'
                        : 'No charge was completed. You can retry anytime from Premium.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              BrandPrimaryButton(
                label: success ? 'Back to Swipess' : 'Try again later',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
