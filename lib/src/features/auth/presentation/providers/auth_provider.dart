import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/services/access_grant_service.dart';

enum AuthIntent { login, signup }

/// Tracks whether the current session is fully authenticated.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Convenient shortcut to the current user.
///
/// Falls back to [GoTrueClient.currentUser] so a just-completed
/// `signInWithPassword` is visible to the router before the auth
/// stream emits (otherwise we bounce back to Welcome).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user ??
      Supabase.instance.client.auth.currentUser;
});

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
