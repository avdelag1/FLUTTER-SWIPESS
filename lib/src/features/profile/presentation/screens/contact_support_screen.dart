import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cap ContactPage — email support + optional in-app message draft.
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const _email = 'support@swipess.com';
  final _message = TextEditingController();
  String _topic = 'account';

  static const _topics = [
    ('account', 'Account'),
    ('bug', 'Bug'),
    ('billing', 'Billing'),
    ('listing', 'Listing'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NeoNaiveScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                      border: Border.all(color: MatteSurface.ink(context), width: 1.5),
                    ),
                    child: Center(
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: MatteSurface.ink(context), size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('CONTACT',
                    style: AppTheme.displayItalic.copyWith(fontSize: 22)),
              ],
            ),
            SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: MatteSurface.ink(context), width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(Icons.forum_rounded,
                      color: AppTheme.brandPrimary, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'NEED ASSISTANCE?',
                    style: TextStyle(
                      color: MatteSurface.ink(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Questions, bugs, or account help — reach the Swipess team.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.muted(context), height: 1.4),
                  ),
                  SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'TOPIC',
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.muted(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _topics)
                        NeoNaiveChip(
                          label: t.$2,
                          selected: _topic == t.$1,
                          onSelected: () => setState(() => _topic = t.$1),
                          selectedColor: AppTheme.brandPrimary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GlassTextField(
                    controller: _message,
                    hint: 'Describe your issue (optional)',
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  BrandPrimaryButton(
                    label: 'Email Support',
                    icon: Icons.mail_rounded,
                    onPressed: _emailSupport,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _emailSupport() async {
    final body = [
      'Topic: $_topic',
      if (_message.text.trim().isNotEmpty) '',
      if (_message.text.trim().isNotEmpty) _message.text.trim(),
    ].join('\n');
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {
        'subject': 'Swipess support — $_topic',
        if (body.trim().isNotEmpty) 'body': body,
      },
    );
    await launchUrl(uri);
  }
}
