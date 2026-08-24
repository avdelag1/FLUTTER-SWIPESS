import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EngagementRewardProgress {
  const EngagementRewardProgress({
    this.steps = 0,
    this.stepsNeeded = 5,
    this.stepMinutes = 35,
    this.activeSecondsRemainder = 0,
    this.secondsToNextStep = 2100,
    this.totalSteps = 0,
    this.tokensAwarded = 0,
  });

  final int steps;
  final int stepsNeeded;
  final int stepMinutes;
  final int activeSecondsRemainder;
  final int secondsToNextStep;
  final int totalSteps;
  final int tokensAwarded;

  int get minutesToNextStep => math.max(1, (secondsToNextStep / 60).ceil());

  double get stepFraction {
    final secondsPerStep = math.max(1, stepMinutes * 60);
    return (activeSecondsRemainder / secondsPerStep)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  factory EngagementRewardProgress.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;

    final stepMinutes = readInt('step_minutes', 35);
    return EngagementRewardProgress(
      steps: readInt('steps', 0).clamp(0, 5).toInt(),
      stepsNeeded: readInt('steps_needed', 5),
      stepMinutes: stepMinutes,
      activeSecondsRemainder: readInt('active_seconds_remainder', 0),
      secondsToNextStep: readInt('seconds_to_next_step', stepMinutes * 60),
      totalSteps: readInt('total_steps', 0),
      tokensAwarded: readInt('tokens_awarded', 0),
    );
  }
}

final engagementRewardProgressProvider =
    FutureProvider<EngagementRewardProgress>((ref) async {
  ref.watch(authStateProvider);
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    return const EngagementRewardProgress();
  }

  try {
    final raw = await client.rpc('rpc_get_engagement_reward_progress');
    if (raw is Map) {
      return EngagementRewardProgress.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }
  } catch (_) {
    // Keep profile/token surfaces usable if a progress refresh is temporarily
    // unavailable. The authoritative server heartbeat keeps the reward balance.
  }
  return const EngagementRewardProgress();
});
