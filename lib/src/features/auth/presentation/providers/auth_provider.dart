import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/services/access_grant_service.dart';

enum AuthIntent { login, signup }

/// Tracks whether the current session is fully authenticated.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Live session user. A [Notifier] so email login can stamp the user
/// immediately — a plain Provider stays cached as `null` until the
/// auth stream emits, and the router then bounces LOG IN back to Welcome.
class CurrentUserNotifier extends Notifier<User?> {
  @override
  User? build() {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      state = next.value?.session?.user ??
          Supabase.instance.client.auth.currentUser;
    });
    return Supabase.instance.client.auth.currentUser;
  }

  /// Call after `signInWithPassword` / sign-up so GoRouter sees the
  /// session on the same frame as `context.go(dashboard)`.
  void apply(User? user) {
    state = user ?? Supabase.instance.client.auth.currentUser;
  }

  void clear() => state = null;
}

final currentUserProvider =
    NotifierProvider<CurrentUserNotifier, User?>(CurrentUserNotifier.new);

/// Access-code gate state. AsyncNotifier so grant flips true immediately
/// (FutureProvider invalidate left `.value` null → router treated as denied).
class AccessGrantedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => AccessGrantService.isGranted();

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

final authIntentProvider =
    NotifierProvider<AuthIntentNotifier, AuthIntent>(AuthIntentNotifier.new);
