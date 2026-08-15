import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap `state/notificationStore.ts` + `utils/appNotification.ts`.
///
/// Cap routes every piece of app feedback through one premium top banner
/// instead of scattered toasts. This is the queue behind it.
enum AppToastType {
  like,
  superLike,
  message,
  match,
  newUser,
  info,
  success,
  error,
  warning,
}

class AppToast {
  AppToast({
    required this.id,
    required this.type,
    required this.title,
    this.message = '',
    required this.at,
  });

  final String id;
  final AppToastType type;
  final String title;
  final String message;
  final DateTime at;
}

class AppNotificationsNotifier extends Notifier<List<AppToast>> {
  static const _maxQueued = 20;
  static const _dedupeWindow = Duration(seconds: 10);

  int _seq = 0;

  @override
  List<AppToast> build() => const [];

  /// Adds a banner. Cap drops a repeat of the same type + message inside ten
  /// seconds, which is what keeps a flapping connection from spamming the user.
  void show({
    required String title,
    String message = '',
    AppToastType type = AppToastType.info,
  }) {
    final now = DateTime.now();
    final duplicate = state.any(
      (n) =>
          n.type == type &&
          n.message == message &&
          n.title == title &&
          now.difference(n.at) < _dedupeWindow,
    );
    if (duplicate) return;

    final toast = AppToast(
      id: '${now.microsecondsSinceEpoch}-${_seq++}',
      type: type,
      title: title,
      message: message,
      at: now,
    );
    state = [toast, ...state].take(_maxQueued).toList(growable: false);
  }

  void success(String title, [String message = '']) =>
      show(title: title, message: message, type: AppToastType.success);

  void error(String title, [String message = '']) =>
      show(title: title, message: message, type: AppToastType.error);

  void info(String title, [String message = '']) =>
      show(title: title, message: message, type: AppToastType.info);

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList(growable: false);
  }

  void clearAll() => state = const [];
}

final appNotificationsProvider =
    NotifierProvider<AppNotificationsNotifier, List<AppToast>>(
      AppNotificationsNotifier.new,
    );
