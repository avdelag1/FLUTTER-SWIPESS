import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/insights/data/repositories/insights_repository.dart';
import 'package:flutter_swipes/src/features/insights/domain/local_intel_post.dart';
import 'package:flutter_swipes/src/features/insights/domain/price_point.dart';

final localIntelProvider = FutureProvider<List<LocalIntelPost>>((ref) {
  return ref.read(insightsRepositoryProvider).fetchLocalIntel();
});

final priceHistoryProvider = FutureProvider<List<PricePoint>>((ref) {
  return ref.read(insightsRepositoryProvider).fetchPriceHistory();
});
