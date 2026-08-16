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
  @override
  User? build() {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      state =
          next.value?.session?.user ??
          ref.read(supabaseClientProvider).auth.currentUser;
    });
    return ref.read(supabaseClientProvider).auth.currentUser;
  }

  void apply(User? user) {
    state = user ?? ref.read(supabaseClientProvider).auth.currentUser;
  }

  void clear() {
    ref.read(pendingDeepLinkProvider).clear();
    state = null;
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
