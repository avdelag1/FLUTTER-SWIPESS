import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

enum LegalDoc { terms, privacy }

Future<void> showLegalSheet(
  BuildContext context, {
  required LegalDoc doc,
  VoidCallback? onAgree,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _LegalSheet(doc: doc, onAgree: onAgree),
  );
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.doc, this.onAgree});

  final LegalDoc doc;
  final VoidCallback? onAgree;

  @override
  Widget build(BuildContext context) {
    final isTerms = doc == LegalDoc.terms;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xF20A0A0C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isTerms ? 'TERMS OF SERVICE' : 'PRIVACY POLICY',
                        style: AppTheme.displayItalic.copyWith(fontSize: 22),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: MatteSurface.ink(context)),
                      style: IconButton.styleFrom(
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: [
                      Text(
                        isTerms
                            ? 'By creating an account or signing in, you agree to these Terms of Use (EULA) and the Privacy Policy. If you do not agree, do not use Swipess.'
                            : 'We value your privacy and use technical and organizational safeguards, including encryption in transit. No online service can guarantee absolute security.',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.ink(context),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Divider(color: Color(0x1AFFFFFF)),
                      ),
                      if (isTerms) ...const [
                        _LegalBlock(
                          index: '01',
                          title: 'Eligibility',
                          body:
                              'You must be at least 18 years old and have the legal capacity to enter binding agreements to use Swipess.',
                        ),
                        _LegalBlock(
                          index: '02',
                          title: 'Zero Tolerance for Objectionable Content',
                          body:
                              'Swipess prohibits objectionable content and abusive behavior. You agree not to post content that is illegal, hateful, sexually explicit, threatening, harassing, or otherwise prohibited.',
                        ),
                        _LegalBlock(
                          index: '03',
                          title: 'Reporting & Blocking',
                          body:
                              'You can report content or users and block unwanted interactions from profiles or chats. Reports are prioritized by severity and reviewed as resources allow.',
                        ),
                      ] else ...const [
                        _LegalBlock(
                          index: '01',
                          title: 'Data Collection',
                          body:
                              'We collect account, profile, listing, message, location, device, usage, and purchase-related data as needed to operate the features you choose.',
                        ),
                        _LegalBlock(
                          index: '02',
                          title: 'Data Sharing',
                          body:
                              'Profile and listing information is shared with other users as needed for discovery and messaging. We do not sell personal data to data brokers.',
                        ),
                        _LegalBlock(
                          index: '03',
                          title: 'Asset Privacy',
                          body:
                              'Location data may be used for maps and nearby discovery. You can control device location permission and review the full Privacy Policy for details.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      AppHaptics.medium();
                      Navigator.of(context).pop();
                      onAgree?.call();
                    },
                    child: Text(
                      'I Agree & Continue',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegalBlock extends StatelessWidget {
  const _LegalBlock({
    required this.index,
    required this.title,
    required this.body,
  });

  final String index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index — ${title.toUpperCase()}',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFE01E2A),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xCCFFFFFF),
              height: 1.55,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
