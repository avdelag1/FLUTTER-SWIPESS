import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';

/// Cap `useAppBadge` (`@capawesome/capacitor-badge`) — mirrors total unread
/// (Pulse feed + conversations) onto the home-screen icon, and clears at zero.
/// A launcher that does not support badges simply reports unsupported.
final unreadBadgeCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(unreadNotificationsProvider).value ?? 0;
  final messages = ref.watch(conversationsProvider).value?.fold<int>(
            0,
            (sum, conversation) => sum + conversation.unreadCount,
          ) ??
      0;
  return notifications + messages;
});

class AppBadge {
  static bool? _supported;
  static int? _applied;

  static Future<void> apply(int count) async {
    if (kIsWeb) return;
    final value = count < 0 ? 0 : count;
    if (value == _applied) return;
    _applied = value;
    try {
      _supported ??= await AppBadgePlus.isSupported();
      if (_supported != true) return;
      await AppBadgePlus.updateBadge(value);
    } catch (e) {
      debugPrint('[AppBadge] update failed: $e');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _supported = null;
    _applied = null;
  }
}

/// Keeps the icon badge in step with the unread count for the whole session,
/// the way Cap mounted `useAppBadge` in `RootProviders`.
class AppBadgeSync extends ConsumerWidget {
  const AppBadgeSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadBadgeCountProvider);
    // Platform call after the frame, never during build. `apply` ignores a
    // repeat of the count it already pushed.
    WidgetsBinding.instance.addPostFrameCallback((_) => AppBadge.apply(count));
    return child;
  }
}
