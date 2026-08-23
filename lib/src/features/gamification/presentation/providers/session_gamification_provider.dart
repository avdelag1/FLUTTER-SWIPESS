import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/global_notice.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sessionGamificationProvider = Provider<SessionGamificationService>((ref) {
  final service = SessionGamificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Active-engagement heartbeat.
///
/// Time counts only when the app is foregrounded AND the user has interacted
/// recently. Leaving Swipess open on a table, locking the phone, switching apps,
/// or leaving it running in the background does not earn time.
class SessionGamificationService {
  SessionGamificationService(this.ref);

  static const _heartbeatEvery = Duration(seconds: 15);
  static const _activeWindow = Duration(seconds: 45);

  final Ref ref;
  Timer? _timer;
  bool _syncing = false;
  bool _referralChecked = false;
  bool _isForeground = true;
  DateTime? _lastInteractionAt;
  _GamificationLifecycleObserver? _lifecycleObserver;
  BuildContext? _context;
  int _trackingClients = 0;

  void startTracking(BuildContext context) {
    _trackingClients++;
    if (_context == null || Overlay.maybeOf(context, rootOverlay: true) != null) {
      _context = context;
    }

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;

    if (_lifecycleObserver == null) {
      _lifecycleObserver = _GamificationLifecycleObserver(
        onStateChanged: (state) {
          if (state == AppLifecycleState.resumed) {
            _isForeground = true;
            // A fresh interaction is required after returning to Swipess.
            _lastInteractionAt = null;
            final ctx = _context;
            if (ctx != null) _startForegroundTimer(ctx);
          } else if (state == AppLifecycleState.inactive ||
              state == AppLifecycleState.paused ||
              state == AppLifecycleState.detached ||
              state == AppLifecycleState.hidden) {
            _isForeground = false;
            _lastInteractionAt = null;
            _pauseForegroundTimer();
          }
        },
      );
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }

    if (_isForeground) _startForegroundTimer(_context ?? context);
  }

  /// Called from the app-level pointer listener. This is intentionally cheap;
  /// no network request happens here.
  void markActivity() {
    if (!_isForeground) return;
    _lastInteractionAt = DateTime.now();
  }

  bool get _isActivelyUsingApp {
    if (!_isForeground) return false;
    final last = _lastInteractionAt;
    if (last == null) return false;
    return DateTime.now().difference(last) <= _activeWindow;
  }

  void _startForegroundTimer(BuildContext context) {
    if (_timer != null || !_isForeground) return;
    unawaited(_heartbeat(context, 0));
    _timer = Timer.periodic(_heartbeatEvery, (_) {
      if (!_isActivelyUsingApp) return;
      unawaited(_heartbeat(context, _heartbeatEvery.inSeconds));
    });
  }

  void _pauseForegroundTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void stopTracking() {
    if (_trackingClients > 0) _trackingClients--;
    if (_trackingClients > 0) return;
    _stopCompletely();
  }

  void _stopCompletely() {
    _trackingClients = 0;
    _pauseForegroundTimer();
    final observer = _lifecycleObserver;
    if (observer != null) WidgetsBinding.instance.removeObserver(observer);
    _lifecycleObserver = null;
    _context = null;
    _lastInteractionAt = null;
  }

  void dispose() => _stopCompletely();

  Future<void> _applyPendingReferral() async {
    if (_referralChecked || !kIsWeb) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final referrer = Uri.base.queryParameters['ref']?.trim();
    _referralChecked = true;
    if (referrer == null || referrer.isEmpty) return;
    try {
      await Supabase.instance.client.rpc(
        'rpc_apply_signup_referral',
        params: {'p_referrer_id': referrer},
      );
      ref.invalidate(directRequestBalanceProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
    } catch (_) {
      // Invalid/self/stale/already-used referral links are ignored.
    }
  }

  Future<void> _heartbeat(BuildContext context, int activeSeconds) async {
    await _applyPendingReferral();
    if (_syncing || Supabase.instance.client.auth.currentUser == null) return;
    if (activeSeconds > 0 && !_isActivelyUsingApp) return;

    _syncing = true;
    try {
      final raw = await Supabase.instance.client.rpc(
        'rpc_record_active_usage',
        params: {'p_seconds': activeSeconds},
      );
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      final stepAwarded = data['step_awarded'] == true;
      final tokenAwarded = data['token_awarded'] == true;
      if (!stepAwarded && !tokenAwarded) return;

      ref.invalidate(dailyQuestsProvider);
      ref.invalidate(directRequestBalanceProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
      await ref.read(subscriptionProvider.notifier).refresh();

      if (!context.mounted) return;
      final steps = (data['steps'] as num?)?.toInt() ?? 0;
      GlobalNotice.showEngagement(
        context,
        step: tokenAwarded ? 5 : steps,
        tokenAwarded: tokenAwarded,
      );
    } catch (_) {
      // Missed heartbeats are never backfilled, so idle/background time cannot
      // accidentally become rewardable later.
    } finally {
      _syncing = false;
    }
  }
}

class _GamificationLifecycleObserver with WidgetsBindingObserver {
  _GamificationLifecycleObserver({required this.onStateChanged});

  final ValueChanged<AppLifecycleState> onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}
