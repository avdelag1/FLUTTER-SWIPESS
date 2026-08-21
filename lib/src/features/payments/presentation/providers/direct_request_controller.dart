import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/interest_repository.dart';

/// Shared mutation controller for Direct Request business actions.
/// UI may own text-field/animation state, but request mutations live here.
class DirectRequestActionController extends AsyncNotifier<DirectRequestResult?> {
  @override
  FutureOr<DirectRequestResult?> build() => null;

  Future<DirectRequestResult> send({
    required String receiverId,
    String? listingId,
    String message = '',
  }) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(directRequestRepositoryProvider);
      final balance = await repository.fetchBalance();
      if (balance.available < 1) {
        throw StateError(
          'No Direct Requests available. Get tokens or Premium to skip the wait.',
        );
      }
      final result = await repository.send(
        receiverId: receiverId,
        listingId: listingId,
        message: message,
      );
      state = AsyncData(result);
      ref.invalidate(directRequestBalanceProvider);
      ref.invalidate(pendingDirectRequestsProvider);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<DirectRequestResult> cancel(String requestId) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(directRequestRepositoryProvider)
          .cancel(requestId);
      state = AsyncData(result);
      ref.invalidate(directRequestBalanceProvider);
      ref.invalidate(pendingDirectRequestsProvider);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<DirectRequestResult> respond({
    required String requestId,
    required bool accept,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(directRequestRepositoryProvider).respond(
            requestId: requestId,
            accept: accept,
          );
      state = AsyncData(result);
      ref.invalidate(directRequestBalanceProvider);
      ref.invalidate(pendingDirectRequestsProvider);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final directRequestActionControllerProvider =
    AsyncNotifierProvider<DirectRequestActionController, DirectRequestResult?>(
  DirectRequestActionController.new,
);

/// Owns repository-backed loading for the receiver decision surface.
class DirectRequestDetailController
    extends AsyncNotifier<Map<String, dynamic>?> {
  String? _loadedId;

  @override
  FutureOr<Map<String, dynamic>?> build() => null;

  Future<void> load(String requestId) async {
    if (_loadedId == requestId && state.hasValue && state.value != null) return;
    _loadedId = requestId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(directRequestRepositoryProvider).fetchById(requestId),
    );
  }

  void clear() {
    _loadedId = null;
    state = const AsyncData(null);
  }
}

final directRequestDetailControllerProvider = AsyncNotifierProvider<
    DirectRequestDetailController, Map<String, dynamic>?>(
  DirectRequestDetailController.new,
);

/// Free-match mutation controller. Accepting interest never consumes a token.
class InterestDecisionController extends AsyncNotifier<AcceptedInterest?> {
  @override
  FutureOr<AcceptedInterest?> build() => null;

  Future<AcceptedInterest> accept(String likeId) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(interestRepositoryProvider).accept(likeId);
      state = AsyncData(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final interestDecisionControllerProvider =
    AsyncNotifierProvider<InterestDecisionController, AcceptedInterest?>(
  InterestDecisionController.new,
);
