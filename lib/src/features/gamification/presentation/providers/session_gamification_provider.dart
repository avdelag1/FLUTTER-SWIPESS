import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sessionGamificationProvider = Provider<SessionGamificationService>((ref) {
  final service = SessionGamificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Foreground engagement heartbeat.
///
/// The server is authoritative: one 90-minute block = one step and five steps
/// grant one spendable message token. Background/inactive time never counts.
/// Multiple UI shells may attach to this service, so tracking uses a small
/// reference count and remains alive while the root app is active.
class SessionGamificationService {
  SessionGamificationService(this.ref);

  final Ref ref;
  Timer? _timer;
  bool _syncing = false;
  _GamificationLifecycleObserver? _lifecycleObserver;
  BuildContext? _context;
  int _trackingClients = 0;

  void startTracking(BuildContext context) {
    _trackingClients++;
    _context ??= context;
    if (_lifecycleObserver == null) {
      _lifecycleObserver = _GamificationLifecycleObserver(
        onStateChanged: (state) {
          if (state == AppLifecycleState.resumed) {
            final ctx = _context;
            if (ctx != null) _startForegroundTimer(ctx);
          } else if (state == AppLifecycleState.inactive ||
              state == AppLifecycleState.paused ||
              state == AppLifecycleState.detached ||
              state == AppLifecycleState.hidden) {
            _pauseForegroundTimer();
          }
        },
      );
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }
    _startForegroundTimer(_context ?? context);
  }

  void _startForegroundTimer(BuildContext context) {
    if (_timer != null) return;
    unawaited(_heartbeat(context, 0));
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_heartbeat(context, 60));
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
  }

  void dispose() => _stopCompletely();

  Future<void> _heartbeat(BuildContext context, int activeSeconds) async {
    if (_syncing || Supabase.instance.client.auth.currentUser == null) return;
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
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
      await ref.read(subscriptionProvider.notifier).refresh();

      if (!context.mounted) return;
      final steps = (data['steps'] as num?)?.toInt() ?? 0;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(tokenAwarded ? '🎉' : '⚡', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tokenAwarded
                      ? 'Free token unlocked! You completed 5/5 reward steps.'
                      : '90 active minutes complete — reward step $steps/5 unlocked.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: tokenAwarded
              ? const Color(0xFF7C3AED)
              : const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      // A missed minute is intentionally not backfilled from background time.
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
