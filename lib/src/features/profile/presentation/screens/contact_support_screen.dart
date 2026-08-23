import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cap ContactPage — persisted support ticket + optional email handoff.
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const _email = 'support@swipess.com';
  final _message = TextEditingController();
  String _topic = 'account';
  bool _sending = false;

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
                const CapBackButton(fallbackPath: AppPaths.clientProfile),
                const SizedBox(width: 12),
                Text(
                  'CONTACT',
                  style: AppTheme.displayItalic.copyWith(fontSize: 22),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.forum_rounded,
                    color: AppTheme.brandPrimary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NEED ASSISTANCE?',
                    style: TextStyle(
                      color: MatteSurface.ink(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Questions, bugs, or account help — reach the Swipess team.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.muted(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                    label: _sending ? 'Saving request…' : 'Email Support',
                    icon: Icons.mail_rounded,
                    loading: _sending,
                    onPressed: _sending ? null : _emailSupport,
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
    if (_sending) return;
    final message = _message.text.trim();
    final body = [
      'Topic: $_topic',
      if (message.isNotEmpty) '',
      if (message.isNotEmpty) message,
    ].join('\n');
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {
        'subject': 'Swipess support — $_topic',
        if (body.trim().isNotEmpty) 'body': body,
      },
    );

    setState(() => _sending = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final role =
            user.appMetadata['role']?.toString() ??
            user.userMetadata?['role']?.toString() ??
            'client';
        await Supabase.instance.client.from('support_tickets').insert({
          'user_id': user.id,
          'subject': 'Support · $_topic',
          'message': message.isEmpty
              ? 'Support request opened from the Contact page.'
              : message,
          'category': _topic,
          'priority': 'medium',
          'user_email': user.email ?? '',
          'user_role': role,
          'source': 'contact_support',
        });
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save support request: $error')),
          );
        }
      }
    }
    if (mounted) setState(() => _sending = false);
    await launchUrl(uri);
  }
}
