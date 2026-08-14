import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/notifications/domain/app_notification.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/utils/notification_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `ActivityFeed` — top likes / matches / messages on Profile.
class ProfileActivityFeed extends ConsumerWidget {
  const ProfileActivityFeed({super.key, required this.ink, required this.muted});

  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final items = (async.value ?? const <AppNotification>[])
        .where((n) =>
            n.visualType == 'like' ||
            n.visualType == 'match' ||
            n.visualType == 'message')
        .take(5)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEB4898),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x80EB4898), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Global Activity',
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (async.isLoading)
            Text(
              'Syncing your network…',
              style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
            )
          else if (items.isEmpty)
            Text(
              'Likes, matches, and messages from your network show up here.',
              style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
            )
          else
            for (final n in items)
              _ActivityRow(
                notification: n,
                ink: ink,
                muted: muted,
                onTap: () async {
                  AppHaptics.selection();
                  await ref.read(notificationsProvider.notifier).markRead(n.id);
                  if (!context.mounted) return;
                  await openNotificationTarget(context, n);
                },
              ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.notification,
    required this.ink,
    required this.muted,
    required this.onTap,
  });

  final AppNotification notification;
  final Color ink;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = notification.visualType;
    final icon = type == 'match'
        ? Icons.auto_awesome_rounded
        : type == 'message'
            ? Icons.chat_bubble_rounded
            : Icons.thumb_up_alt_rounded;
    final color = type == 'match'
        ? const Color(0xFFA78BFA)
        : type == 'message'
            ? AppTheme.brandPrimary
            : const Color(0xFFEB4898);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withAlpha(40),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (notification.message.isNotEmpty)
                    Text(
                      notification.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted, size: 18),
          ],
        ),
      ),
    );
  }
}
