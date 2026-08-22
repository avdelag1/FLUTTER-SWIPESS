import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Referral URL used by the profile invite card and the invite sheet.
abstract final class InviteLinks {
  static String referralUrl(String? userId) {
    if (userId == null || userId.isEmpty) return 'https://www.swipess.com';
    return 'https://www.swipess.com/?ref=$userId';
  }

  static String message(String link, {String? fromName}) {
    final who = fromName?.trim();
    final intro = (who != null && who.isNotEmpty)
        ? '$who invited you to Swipess'
        : 'Join me on Swipess';
    return '$intro — properties, services, events and local deals in one place. Sign up with my link: $link';
  }
}

/// Profile "Invite Friends" action card: header, copyable link, share actions.
class InviteFriendsSection extends StatelessWidget {
  const InviteFriendsSection({
    super.key,
    required this.profileId,
    this.profileName,
    this.onClose,
    this.showClose = false,
  });

  final String profileId;
  final String? profileName;
  final VoidCallback? onClose;
  final bool showClose;

  static const _well = Color(0xFF10141B);
  static const _chip = Color(0xFF222833);
  static const _line = Color(0x3DFFFFFF);

  Future<void> _copied(BuildContext context, String link) async {
    AppHaptics.selection();
    unawaited(Clipboard.setData(ClipboardData(text: link)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Invite link copied · you earn 5 Direct Requests when a friend joins.',
        ),
      ),
    );
  }

  Future<void> _shareWhatsApp(BuildContext context, String link) async {
    AppHaptics.medium();
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_note(link))}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (context.mounted) await _copied(context, link);
  }

  Future<void> _shareInstagram(BuildContext context, String link) async {
    AppHaptics.medium();
    await Clipboard.setData(ClipboardData(text: _note(link)));
    final uri = Uri.parse('https://www.instagram.com/');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Link copied — paste it into Instagram to invite friends.',
        ),
      ),
    );
  }

  Future<void> _shareTikTok(BuildContext context, String link) async {
    AppHaptics.medium();
    await Clipboard.setData(ClipboardData(text: _note(link)));
    final uri = Uri.parse('https://www.tiktok.com/');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied — paste it into TikTok to invite friends.'),
      ),
    );
  }

  Future<void> _shareMore(BuildContext context, String link) async {
    AppHaptics.medium();
    try {
      await AppShare.text(_note(link), subject: 'Join me on Swipess');
    } catch (_) {
      if (context.mounted) await _copied(context, link);
    }
  }

  String _note(String link) => InviteLinks.message(link, fromName: profileName);

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final link = InviteLinks.referralUrl(profileId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppTheme.warmBrandGradient,
              ),
              child: const Icon(
                Icons.ios_share_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite Friends',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share your link and earn free messages',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (showClose)
              IconButton(
                onPressed: () {
                  onClose?.call();
                  Navigator.of(context).maybePop();
                },
                icon: Icon(Icons.close_rounded, color: muted),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Your invite link',
          style: GoogleFonts.plusJakartaSans(
            color: ink,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: _well,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 112, minHeight: 44),
                child: FilledButton(
                  onPressed: () => _copied(context, link),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Copy Link',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ShareActionButton(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                accent: const Color(0xFF25D366),
                onTap: () => _shareWhatsApp(context, link),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ShareActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Instagram',
                accent: const Color(0xFFE1306C),
                onTap: () => _shareInstagram(context, link),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ShareActionButton(
                icon: Icons.music_note_rounded,
                label: 'TikTok',
                accent: Colors.white,
                onTap: () => _shareTikTok(context, link),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ShareActionButton(
                icon: Icons.ios_share_rounded,
                label: 'More',
                accent: AppTheme.brandPrimary,
                onTap: () => _shareMore(context, link),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'When a friend joins with your link, you earn 5 Direct Requests — no purchase required.',
          style: GoogleFonts.plusJakartaSans(
            color: muted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  const _ShareActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: InviteFriendsSection._chip,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: InviteFriendsSection._line, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
