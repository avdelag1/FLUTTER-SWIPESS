import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client.auth);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value?.session?.user ?? Supabase.instance.client.auth.currentUser;
});

class AuthRepository {
  final GoTrueClient _auth;
  AuthRepository(this._auth);

  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    return await _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmailPassword(String email, String password) async {
    return await _auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Cap `signInWithOAuth` — Google / Apple web redirect.
  Future<bool> signInWithOAuth(OAuthProvider provider) {
    return _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? Uri.base.origin : null,
      queryParams: provider == OAuthProvider.google
          ? const {'prompt': 'select_account'}
          : null,
    );
  }
}
