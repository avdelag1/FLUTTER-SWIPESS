import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/notifications/domain/app_notification.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
            child: const Text('Could not load notifications — retry'),
          ),
        ),
        data: (items) {
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, top + 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        'PULSE FEED',
                        style: AppTheme.displayItalic.copyWith(fontSize: 22),
                      ),
                    ),
                    if (items.any((n) => !n.isRead))
                      TextButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref.read(notificationsProvider.notifier).markAllRead();
                        },
                        child: Text(
                          'CLEAR UNREAD',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.brandPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 48, color: Colors.white.withAlpha(60)),
                            const SizedBox(height: 12),
                            Text(
                              'Silence is golden',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.brandPrimary,
                        onRefresh: () =>
                            ref.read(notificationsProvider.notifier).refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final n = items[index];
                            return _NotificationTile(
                              notification: n,
                              onTap: () => ref
                                  .read(notificationsProvider.notifier)
                                  .markRead(n.id),
                              onDismiss: () => ref
                                  .read(notificationsProvider.notifier)
                                  .dismiss(n.id),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  IconData get _icon {
    switch (notification.visualType) {
      case 'like':
        return Icons.favorite_rounded;
      case 'match':
        return Icons.auto_awesome;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'contract':
        return Icons.description_rounded;
      case 'payment':
        return Icons.payments_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get _color {
    switch (notification.visualType) {
      case 'like':
        return const Color(0xFFFC567E);
      case 'match':
        return const Color(0xFFA78BFA);
      case 'message':
        return AppTheme.brandPrimary;
      case 'contract':
        return const Color(0xFF4DABF7);
      case 'payment':
        return const Color(0xFFFFD43B);
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.MMMd().add_jm().format(notification.createdAt.toLocal());
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(50),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.white.withAlpha(8)
                : Colors.white.withAlpha(16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: notification.isRead
                  ? Colors.white.withAlpha(15)
                  : AppTheme.brandPrimary.withAlpha(80),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: _color.withAlpha(40),
                child: Icon(_icon, color: _color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (notification.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: Colors.white.withAlpha(170),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withAlpha(100),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppTheme.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
