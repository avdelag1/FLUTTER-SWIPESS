import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/notifications/data/repositories/notification_repository.dart';
import 'package:flutter_swipes/src/features/notifications/domain/app_notification.dart';

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    ref.watch(authStateProvider);
    return ref.read(notificationRepositoryProvider).fetchMine();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).fetchMine(),
    );
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final n in current)
        if (n.id == id)
          AppNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            createdAt: n.createdAt,
            isRead: true,
            linkUrl: n.linkUrl,
            relatedUserId: n.relatedUserId,
          )
        else
          n,
    ]);
    ref.invalidate(unreadNotificationsProvider);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    await refresh();
    ref.invalidate(unreadNotificationsProvider);
  }

  Future<void> dismiss(String id) async {
    await ref.read(notificationRepositoryProvider).dismiss(id);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((n) => n.id != id).toList());
    ref.invalidate(unreadNotificationsProvider);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(notificationRepositoryProvider).unreadCount();
});
