import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';

/// Realtime remains the primary discovery update path, but mobile/PWA clients
/// can occasionally miss or delay a websocket change while suspended, restored,
/// or switching networks. Keep dashboard discovery self-healing with a tiny
/// round-robin refresh instead of allowing an already-resolved 8-card provider
/// to behave like a permanent memory snapshot.
///
/// Only one category is invalidated per tick, so this is much lighter than
/// refreshing every Quick Filter at once. A watched dashboard tile refetches;
/// an off-screen/unwatched provider costs no network request.
final liveDiscoveryRefreshProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  const categories = <String>[
    'property',
    'services',
    'yacht',
    'motorcycle',
    'bicycle',
  ];

  // Never inherit a resolved preview from the previous authenticated session.
  scheduleMicrotask(() {
    for (final category in categories) {
      ref.invalidate(quickFilterPreviewListingsProvider(category));
    }
    ref.invalidate(swipeListingsProvider('property'));
  });

  var tick = 0;
  final timer = Timer.periodic(const Duration(seconds: 2), (_) {
    final category = categories[tick % categories.length];
    ref.invalidate(quickFilterPreviewListingsProvider(category));

    // Full swipe decks refresh more slowly than the tiny dashboard previews.
    // This still guarantees that a newly published/processed listing appears
    // without requiring a PWA restart when realtime delivery was missed.
    if (tick % categories.length == 0) {
      ref.invalidate(swipeListingsProvider(category));
    }
    tick += 1;
  });

  ref.onDispose(timer.cancel);
});
