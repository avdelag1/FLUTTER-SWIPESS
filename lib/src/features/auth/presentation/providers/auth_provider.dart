import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/routing/pending_deep_link.dart';
import 'package:flutter_swipes/src/core/services/access_grant_service.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';

enum AuthIntent { login, signup }

final authStateProvider = StreamProvider<AuthState>((ref) {
  try {
    return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
  } catch (_) {
    return const Stream<AuthState>.empty();
  }
});

class CurrentUserNotifier extends Notifier<User?> {
  RealtimeChannel? _accessChannel;
  bool _kicking = false;

  @override
  User? build() {
    ref.onDispose(() {
      final channel = _accessChannel;
      if (channel != null) {
        unawaited(ref.read(supabaseClientProvider).removeChannel(channel));
      }
    });

    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      final nextUser =
          next.value?.session?.user ??
          ref.read(supabaseClientProvider).auth.currentUser;
      state = nextUser;
      unawaited(_watchAccountAccess(nextUser));
    });

    final user = ref.read(supabaseClientProvider).auth.currentUser;
    unawaited(_watchAccountAccess(user));
    return user;
  }

  Future<void> _watchAccountAccess(User? user) async {
    final client = ref.read(supabaseClientProvider);
    final oldChannel = _accessChannel;
    _accessChannel = null;
    if (oldChannel != null) {
      try {
        await client.removeChannel(oldChannel);
      } catch (_) {}
    }

    if (user == null) return;

    await _checkAndKickIfBlocked(user.id);
    if (client.auth.currentUser?.id != user.id || _kicking) return;

    _accessChannel = client
        .channel('account-access-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final banned = row['is_banned'] == true;
            final inactive = row['is_active'] == false;
            if (banned || inactive) {
              unawaited(_kickBlockedAccount());
            }
          },
        )
        .subscribe();
  }

  Future<void> _checkAndKickIfBlocked(String userId) async {
    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .select('is_active,is_banned')
          .or('id.eq.$userId,user_id.eq.$userId')
          .maybeSingle();
      if (row == null) return;
      final banned = row['is_banned'] == true;
      final inactive = row['is_active'] == false;
      if (banned || inactive) {
        await _kickBlockedAccount();
      }
    } catch (_) {
      // Auth also enforces the ban. Do not eject legitimate users merely
      // because this extra profile check temporarily failed offline.
    }
  }

  Future<void> _kickBlockedAccount() async {
    if (_kicking) return;
    _kicking = true;
    try {
      await ref.read(supabaseClientProvider).auth.signOut();
    } catch (_) {
      // Clear local state even if remote sign-out is temporarily unavailable.
    } finally {
      ref.read(pendingDeepLinkProvider).clear();
      state = null;
      _kicking = false;
    }
  }

  void apply(User? user) {
    final nextUser = user ?? ref.read(supabaseClientProvider).auth.currentUser;
    state = nextUser;
    unawaited(_watchAccountAccess(nextUser));
  }

  void clear() {
    ref.read(pendingDeepLinkProvider).clear();
    state = null;
    unawaited(_watchAccountAccess(null));
  }
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, User?>(
  CurrentUserNotifier.new,
);

class AccessGrantedNotifier extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() {
    if (AccessGrantService.skipOnNative) return true;
    return AccessGrantService.isGranted();
  }

  Future<void> grant() async {
    await AccessGrantService.persist();
    state = const AsyncData(true);
  }

  Future<void> clear() async {
    await AccessGrantService.clear();
    state = const AsyncData(false);
  }
}

final accessGrantedProvider =
    AsyncNotifierProvider<AccessGrantedNotifier, bool>(
      AccessGrantedNotifier.new,
    );

class AuthIntentNotifier extends Notifier<AuthIntent> {
  @override
  AuthIntent build() => AuthIntent.login;

  void set(AuthIntent intent) => state = intent;
}

final authIntentProvider = NotifierProvider<AuthIntentNotifier, AuthIntent>(
  AuthIntentNotifier.new,
);
