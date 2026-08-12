import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  static const _email = 'support@swipess.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('CONTACT', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                ],
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withAlpha(25)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.forum_rounded, color: AppTheme.brandPrimary, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'NEED ASSISTANCE?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Questions, bugs, or account help — email the Swipess team.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final uri = Uri(
                              scheme: 'mailto',
                              path: _email,
                              queryParameters: {'subject': 'Swipess support'},
                            );
                            await launchUrl(uri);
                          },
                          icon: const Icon(Icons.mail_rounded),
                          label: const Text('Email Support'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
