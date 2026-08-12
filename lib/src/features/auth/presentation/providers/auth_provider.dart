import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/services/access_grant_service.dart';

enum AuthIntent { login, signup }

/// Tracks whether the current session is fully authenticated.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Convenient shortcut to the current user.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session?.user,
    loading: () => null,
    error: (e, st) => null,
  );
});

/// Tracks whether the access code gate has been passed this session.
final accessGrantedProvider = FutureProvider<bool>((ref) async {
  return AccessGrantService.isGranted();
});

class AuthIntentNotifier extends Notifier<AuthIntent> {
  @override
  AuthIntent build() => AuthIntent.login;

  void set(AuthIntent intent) => state = intent;
}

final authIntentProvider =
    NotifierProvider<AuthIntentNotifier, AuthIntent>(AuthIntentNotifier.new);
