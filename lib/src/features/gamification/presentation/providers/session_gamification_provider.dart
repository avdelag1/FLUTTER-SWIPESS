import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';

final sessionGamificationProvider = Provider<SessionGamificationService>((ref) {
  return SessionGamificationService(ref);
});

class SessionGamificationService {
  SessionGamificationService(this.ref);

  final Ref ref;
  Timer? _timer;
  int _secondsActive = 0;

  void startTracking(BuildContext context) {
    if (_timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _secondsActive++;
      
      // Every 10 minutes (600 seconds)
      if (_secondsActive > 0 && _secondsActive % 600 == 0) {
        _awardToken(context);
      }
    });
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _awardToken(BuildContext context) async {
    final subData = ref.read(subscriptionProvider).value;
    if (subData == null) return;

    final repo = ref.read(subscriptionRepositoryProvider);
    final newBalance = subData.tokensBalance + 1;
    await repo.updateTokens(newBalance);
    
    // Refresh the provider
    ref.read(subscriptionProvider.notifier).refresh();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('👑', style: TextStyle(fontSize: 20)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You earned a free token for exploring Swipess!',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF9D4EDD),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
