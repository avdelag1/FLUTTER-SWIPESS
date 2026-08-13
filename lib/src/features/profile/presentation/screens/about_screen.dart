import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor AboutPage — mission + owner/client benefits.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _owner = [
    (Icons.people_rounded, 'Quality Tenants',
        'Connect with pre-screened tenants who match your property requirements.'),
    (Icons.bolt_rounded, 'Instant Protocol',
        'No more endless calls. Match instantly and communicate directly.'),
    (Icons.verified_user_rounded, 'Verified Profiles',
        'Trusted profiles and secure digital agreements for peace of mind.'),
    (Icons.chat_bubble_rounded, 'Direct Terminal',
        'Chat directly, schedule viewings, and close deals in record time.'),
  ];

  static const _client = [
    (Icons.home_rounded, 'Curated Discovery',
        'Browse listings that match your unique lifestyle preferences.'),
    (Icons.thumb_up_rounded, 'Fluid Interface',
        'Swipe through properties with a fun, gamified experience.'),
    (Icons.shield_rounded, 'Secure Environment',
        'Engage with trusted owners in a secure, audited environment.'),
    (Icons.wifi_tethering_rounded, 'Direct Signal',
        'Open direct lines of communication with owners instantly.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.rocket_launch_rounded,
                    color: AppTheme.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ABOUT SWIPESS',
                        style: AppTheme.displayItalic.copyWith(fontSize: 22),
                      ),
                      Text(
                        'The Architecture of Modern Real Estate',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0x33FF4D00), Color(0x33EB4898)],
                ),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Swipess turns finding a home, ride, yacht, or pro into a swipe-native protocol — verified residents, instant messaging, and digital contracts in one network.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('FOR OWNERS', style: _sectionStyle),
            const SizedBox(height: 12),
            for (final item in _owner) ...[
              _Benefit(icon: item.$1, title: item.$2, body: item.$3),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 18),
            Text('FOR SEEKERS', style: _sectionStyle),
            const SizedBox(height: 12),
            for (final item in _client) ...[
              _Benefit(icon: item.$1, title: item.$2, body: item.$3),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
    );
  }

  TextStyle get _sectionStyle => GoogleFonts.plusJakartaSans(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.4,
      );
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.35,
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
