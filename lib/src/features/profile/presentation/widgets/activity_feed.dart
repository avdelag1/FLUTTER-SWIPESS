import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/notifications/domain/app_notification.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/utils/notification_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `ActivityFeed` — top 5 match/message/like cards on profile.
class ActivityFeed extends ConsumerWidget {
  const ActivityFeed({super.key});

  static const _relevant = {'match', 'message', 'like', 'super_like'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);

    return async.when(
      loading: () => const _ActivityFeedSkeleton(),
      error: (_, _) => _ActivityFeedError(
        muted: muted,
        hairline: hairline,
        onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
      ),
      data: (all) {
        final items = all
            .where((n) => _relevant.contains(n.type.toLowerCase()))
            .take(5)
            .toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            for (final n in items) ...[
              _ActivityCard(
                notification: n,
                ink: ink,
                muted: muted,
                hairline: hairline,
                onTap: () {
                  AppHaptics.selection();
                  ref.read(notificationsProvider.notifier).markRead(n.id);
                  openNotificationTarget(context, n);
                },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  AppHaptics.light();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: muted,
                  side: BorderSide(color: hairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'VIEW MANIFEST ACTIVITY',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Cap `ActivityFeed` loading — 3 shimmer rows shaped like real cards.
class _ActivityFeedSkeleton extends StatefulWidget {
  const _ActivityFeedSkeleton();

  @override
  State<_ActivityFeedSkeleton> createState() => _ActivityFeedSkeletonState();
}

class _ActivityFeedSkeletonState extends State<_ActivityFeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hairline = MatteSurface.hairline(context);
    final fill = MatteSurface.cardFill(context);
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final opacity = 0.5 + (_shimmer.value * 0.35);
        return Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Opacity(
                opacity: i == 2 ? opacity * 0.7 : opacity,
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: hairline),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: hairline.withAlpha(160),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 120,
                              height: 12,
                              decoration: BoxDecoration(
                                color: hairline.withAlpha(160),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 180,
                              height: 10,
                              decoration: BoxDecoration(
                                color: hairline.withAlpha(120),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i != 2) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

/// Cap `ActivityFeed` error — muted inline retry, no full-screen takeover.
class _ActivityFeedError extends StatelessWidget {
  const _ActivityFeedError({
    required this.muted,
    required this.hairline,
    required this.onRetry,
  });

  final Color muted;
  final Color hairline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onRetry();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, size: 16, color: muted),
            const SizedBox(width: 8),
            Text(
              'Couldn\u2019t load activity — tap to retry',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.notification,
    required this.ink,
    required this.muted,
    required this.hairline,
    required this.onTap,
  });

  final AppNotification notification;
  final Color ink;
  final Color muted;
  final Color hairline;
  final VoidCallback onTap;

  Color get _badgeColor {
    switch (notification.type.toLowerCase()) {
      case 'message':
        return AppTheme.brandPrimary;
      case 'match':
      case 'super_like':
        return const Color(0xFFEB4898);
      default:
        return const Color(0xFFEB4898);
    }
  }

  IconData get _badgeIcon {
    switch (notification.type.toLowerCase()) {
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'match':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.thumb_up_rounded;
    }
  }

  String get _relative {
    final diff = DateTime.now().difference(notification.createdAt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return '1 day ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? MatteSurface.cardFill(context)
                : const Color(0xFFEB4898).withAlpha(18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: hairline),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white12,
                    child: Text(
                      notification.type.toLowerCase() == 'match'
                          ? '🔥'
                          : notification.type.toLowerCase() == 'message'
                              ? '💬'
                              : '❤️',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MatteSurface.canvas(context),
                          width: 2,
                        ),
                      ),
                      child: Icon(_badgeIcon, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: muted.withAlpha(28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 10, color: muted),
                              const SizedBox(width: 3),
                              Text(
                                _relative,
                                style: GoogleFonts.plusJakartaSans(
                                  color: muted,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: muted.withAlpha(100)),
            ],
          ),
        ),
      ),
                );
  }
}
