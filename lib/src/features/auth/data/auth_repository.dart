import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client.auth);
});

class AuthRepository {
  final GoTrueClient _auth;
  AuthRepository(this._auth);

  static const _resetRedirect = 'https://www.swipess.com/reset-password';

  Future<AuthResponse> signInWithEmailPassword(String email, String password) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmailPassword(String email, String password) {
    return _auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  String? get currentEmail => _auth.currentUser?.email;

  Future<void> resetPassword(String email) {
    return _auth.resetPasswordForEmail(email, redirectTo: _resetRedirect);
  }

  /// Cap `signInWithOAuth` — native Apple/Google ID tokens on device, web redirect in browser.
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    if (provider == OAuthProvider.apple && !kIsWeb) {
      return _signInWithNativeApple();
    }
    if (provider == OAuthProvider.google && !kIsWeb) {
      return _signInWithNativeGoogle();
    }
    return _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? Uri.base.origin : null,
      queryParams: provider == OAuthProvider.google
          ? const {'prompt': 'select_account'}
          : null,
    );
  }

  Future<bool> _signInWithNativeApple() async {
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      return _auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
    }
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        throw Exception('Apple did not return an identity token');
      }
      final res = await _auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: token,
        nonce: rawNonce,
      );
      final given = credential.givenName?.trim() ?? '';
      final family = credential.familyName?.trim() ?? '';
      final fullName = ('$given $family').trim();
      if (fullName.isNotEmpty) {
        _auth
            .updateUser(UserAttributes(data: {'full_name': fullName, 'name': fullName}))
            .ignore();
      }
      final code = credential.authorizationCode;
      if (code.isNotEmpty) {
        Supabase.instance.client.functions
            .invoke('apple-link-token', body: {'authorizationCode': code})
            .ignore();
      }
      return res.session != null;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('CANCELLED');
      }
      rethrow;
    }
  }

  Future<bool> _signInWithNativeGoogle() async {
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      return _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
        queryParams: const {'prompt': 'select_account'},
      );
    }
    final serverId = AppConfig.googleServerClientId.trim();
    final clientId = AppConfig.googleIosClientId.trim();
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        serverId.isEmpty &&
        clientId.isEmpty) {
      throw Exception(
        'Please use Sign in with Apple or your email address on this device.',
      );
    }
    try {
      await google.initialize(
        clientId: clientId.isEmpty ? null : clientId,
        serverClientId: serverId.isEmpty ? null : serverId,
      );
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not return an ID token');
      }
      final res = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return res.session != null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('CANCELLED');
      }
      rethrow;
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
