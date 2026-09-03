import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/native/app_lifecycle_service.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/bulk_selection_bar.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/notifications/domain/app_notification.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/utils/notification_navigation.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/widgets/pulse_feed_states.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _selected = <String>{};
  bool _selecting = false;
  bool _deleting = false;
  bool _enablingSystemBanners = false;

  @override
  void initState() {
    super.initState();
    ref.read(localNotificationsProvider).initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _beginSelection([String? id]) {
    AppHaptics.selection();
    setState(() {
      _selecting = true;
      if (id != null) _selected.add(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggle(String id) {
    AppHaptics.selection();
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  Future<void> _enableSystemBanners() async {
    if (_enablingSystemBanners) return;
    AppHaptics.medium();
    setState(() => _enablingSystemBanners = true);
    final service = ref.read(localNotificationsProvider);
    final granted = await service.ensurePermission();
    if (!mounted) return;
    setState(() => _enablingSystemBanners = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'System notification banners are enabled.'
              : 'Notifications are still blocked. You can allow them in your device or browser settings.',
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _deleting) return;
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'Delete notification?' : 'Delete $count notifications?'),
        content: Text('Deleted notifications cannot be restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(notificationsProvider.notifier)
          .dismissMany(_selected.toList());
      if (!mounted) return;
      _cancelSelection();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete notifications')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final top = MediaQuery.paddingOf(context).top;
    final notificationService = ref.read(localNotificationsProvider);

    return NeoNaiveScaffold(
      body: async.when(
        loading: () => Column(
          children: [
            _Header(top: top, onBack: () => NavBack.popOrGo(context)),
            Expanded(child: NotificationListSkeleton()),
          ],
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
            child: Text('Could not load notifications — retry'),
          ),
        ),
        data: (items) {
          _selected.removeWhere((id) => !items.any((item) => item.id == id));
          return Column(
            children: [
              _Header(
                top: top,
                onBack: _selecting
                    ? _cancelSelection
                    : () => NavBack.popOrGo(context),
                selecting: _selecting,
                onSelect: items.isEmpty ? null : () => _beginSelection(),
                onMarkRead: !_selecting && items.any((n) => !n.isRead)
                    ? () {
                        AppHaptics.medium();
                        ref.read(notificationsProvider.notifier).markAllRead();
                      }
                    : null,
              ),
              if (_selecting)
                BulkSelectionBar(
                  selectedCount: _selected.length,
                  totalCount: items.length,
                  busy: _deleting,
                  onCancel: _cancelSelection,
                  onSelectAll: () {
                    setState(() {
                      if (_selected.length == items.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(items.map((item) => item.id));
                      }
                    });
                  },
                  onDelete: _deleteSelected,
                )
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _ExternalNotificationsCard(
                    supported: notificationService.isSupported,
                    enabled: notificationService.permissionGranted,
                    busy: _enablingSystemBanners,
                    onEnable: _enableSystemBanners,
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? const PulseFeedEmpty()
                    : RefreshIndicator(
                        color: AppTheme.brandPrimary,
                        onRefresh: () =>
                            ref.read(notificationsProvider.notifier).refresh(),
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final notification = items[index];
                            return _NotificationTile(
                              notification: notification,
                              selecting: _selecting,
                              selected: _selected.contains(notification.id),
                              onLongPress: () => _beginSelection(notification.id),
                              onTap: () async {
                                if (_selecting) {
                                  _toggle(notification.id);
                                  return;
                                }
                                await ref
                                    .read(notificationsProvider.notifier)
                                    .markRead(notification.id);
                                if (!context.mounted) return;
                                await openNotificationTarget(
                                  context,
                                  notification,
                                );
                              },
                              onDismiss: _selecting
                                  ? null
                                  : () => ref
                                      .read(notificationsProvider.notifier)
                                      .dismiss(notification.id),
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

class _ExternalNotificationsCard extends StatelessWidget {
  const _ExternalNotificationsCard({
    required this.supported,
    required this.enabled,
    required this.busy,
    required this.onEnable,
  });

  final bool supported;
  final bool enabled;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final accent = enabled ? const Color(0xFF22C55E) : AppTheme.brandPrimary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: accent.withAlpha(enabled ? 13 : 16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(enabled ? 55 : 65)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withAlpha(28),
            ),
            alignment: Alignment.center,
            child: Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: accent,
              size: 19,
            ),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'SYSTEM BANNERS ON' : 'GET BANNERS OUTSIDE SWIPESS',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  supported
                      ? 'Consistency and return reminders on iOS, Android and supported browser/PWA sessions.'
                      : 'System notification banners are not available on this device.',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 9.8,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (supported) ...[
            SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: TextButton(
                onPressed: enabled || busy ? null : onEnable,
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  backgroundColor: accent.withAlpha(20),
                  padding: EdgeInsets.symmetric(horizontal: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: busy
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Text(
                        enabled ? 'ENABLED' : 'ENABLE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.4,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .45,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.top,
    required this.onBack,
    this.selecting = false,
    this.onSelect,
    this.onMarkRead,
  });

  final double top;
  final VoidCallback onBack;
  final bool selecting;
  final VoidCallback? onSelect;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 10, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              selecting ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
              color: MatteSurface.ink(context),
            ),
          ),
          Expanded(
            child: Text(
              selecting ? 'SELECT NOTIFICATIONS' : 'PULSE FEED',
              style: AppTheme.displayItalic.copyWith(fontSize: 21),
            ),
          ),
          if (!selecting && onMarkRead != null)
            TextButton(
              onPressed: onMarkRead,
              child: Text(
                'READ ALL',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF4C8DFF),
                  fontWeight: FontWeight.w900,
                  fontSize: 9.5,
                ),
              ),
            ),
          if (!selecting && onSelect != null)
            IconButton(
              tooltip: 'Select notifications',
              onPressed: onSelect,
              icon: Icon(
                Icons.checklist_rounded,
                color: MatteSurface.ink(context),
                size: 21,
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onLongPress,
    required this.selecting,
    required this.selected,
    this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDismiss;
  final bool selecting;
  final bool selected;

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
        return const Color(0xFF4C8DFF);
      case 'contract':
        return const Color(0xFF4DABF7);
      case 'payment':
        return const Color(0xFFFFD43B);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.MMMd().add_jm().format(
      notification.createdAt.toLocal(),
    );
    final tile = GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4C8DFF).withAlpha(28)
              : notification.isRead
              ? Colors.white.withAlpha(12)
              : AppTheme.brandPrimary.withAlpha(18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? const Color(0xFF4C8DFF).withAlpha(150)
                : notification.isRead
                ? Colors.white.withAlpha(25)
                : AppTheme.brandPrimary.withAlpha(70),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selecting) ...[
              Padding(
                padding: EdgeInsets.only(top: 7),
                child: SelectionBadge(selected: selected),
              ),
              SizedBox(width: 11),
            ],
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _color.withAlpha(50)),
              ),
              alignment: Alignment.center,
              child: Icon(_icon, color: _color, size: 18),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      decoration: TextDecoration.none,
                      color: MatteSurface.ink(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (notification.message.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: MatteSurface.muted(context),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(
                      decoration: TextDecoration.none,
                      color: MatteSurface.faint(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!selecting && !notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF4C8DFF),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );

    if (selecting || onDismiss == null) return tile;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      child: tile,
    );
  }
}
