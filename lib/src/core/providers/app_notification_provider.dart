import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// One premium notification queue for every in-app feedback event.
enum AppToastType {
  like,
  superLike,
  message,
  match,
  newUser,
  reward,
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
    this.tokens,
    required this.at,
  });

  final String id;
  final AppToastType type;
  final String title;
  final String message;
  final int? tokens;
  final DateTime at;

  bool get isReward => type == AppToastType.reward || (tokens ?? 0) > 0;
}

class AppNotificationsNotifier extends Notifier<List<AppToast>> {
  static const _maxQueued = 20;
  static const _dedupeWindow = Duration(seconds: 10);

  int _seq = 0;

  @override
  List<AppToast> build() => const [];

  void show({
    required String title,
    String message = '',
    AppToastType type = AppToastType.info,
    int? tokens,
  }) {
    final now = DateTime.now();
    final duplicate = state.any(
      (n) =>
          n.type == type &&
          n.message == message &&
          n.title == title &&
          n.tokens == tokens &&
          now.difference(n.at) < _dedupeWindow,
    );
    if (duplicate) return;

    final toast = AppToast(
      id: '${now.microsecondsSinceEpoch}-${_seq++}',
      type: type,
      title: title,
      message: message,
      tokens: tokens,
      at: now,
    );
    state = [toast, ...state].take(_maxQueued).toList(growable: false);

    final important =
        type == AppToastType.message ||
        type == AppToastType.match ||
        type == AppToastType.newUser ||
        type == AppToastType.error ||
        type == AppToastType.warning;
    unawaited(AppHaptics.notification(important: important));
  }

  /// Reward feedback is intentionally explicit: users should always understand
  /// that an action increased their Swipess token balance.
  void showTokenReward({required int tokens, required String reason}) {
    if (tokens <= 0) return;
    show(
      title: 'You earned +$tokens tokens',
      message: reason,
      tokens: tokens,
      type: AppToastType.reward,
    );
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
