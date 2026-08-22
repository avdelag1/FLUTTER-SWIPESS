import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Referral invite via send / copy link.
class InviteFriendsDialog extends ConsumerWidget {
  const InviteFriendsDialog({super.key, this.onClose});

  final VoidCallback? onClose;

  static String referralUrl(String? userId) {
    if (userId == null || userId.isEmpty) return 'https://swipess.com';
    return 'https://swipess.com/?ref=$userId';
  }

  Future<void> _copyLink(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    AppHaptics.selection();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral link copied · earn 5 Direct Requests when a friend joins.'),
      ),
    );
    onClose?.call();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _shareInvite(BuildContext context, String link) async {
    AppHaptics.medium();
    final message =
        'Join me on Swipess — properties, services, events and local deals in one place. Sign up with my link: $link';
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
    var shared = false;
    try {
      if (await canLaunchUrl(uri)) {
        shared = await launchUrl(uri);
      }
    } catch (_) {
      shared = false;
    }
    if (!context.mounted) return;
    if (!shared) {
      await _copyLink(context, link);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite ready · you earn 5 Direct Requests after signup.'),
      ),
    );
    onClose?.call();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final link = referralUrl(user?.id);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF09090B),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(180),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withAlpha(22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.group_add_rounded,
                          color: AppTheme.brandPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invite a friend',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'SHARE LINK · FRIEND SIGNS UP · YOU EARN',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          onClose?.call();
                          Navigator.of(context).maybePop();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withAlpha(24)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: AppTheme.brandPrimary,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EARN 5 DIRECT REQUESTS',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Your reward is added automatically when a new friend creates an account from your referral link.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => _shareInvite(context, link),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'SEND INVITE',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () => _copyLink(context, link),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withAlpha(90)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'COPY REFERRAL LINK',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No purchase required · reward is tied to a real new signup',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showInviteFriendsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withAlpha(160),
    builder: (_) => const InviteFriendsDialog(),
  );
}
