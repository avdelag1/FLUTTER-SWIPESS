import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';
import 'package:flutter_swipes/src/core/services/access_grant_service.dart';
import 'package:flutter_swipes/src/features/auth/data/oauth_popup.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

abstract class AuthRepository {
  Future<AuthResponse> signInWithEmailPassword(String email, String password);
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password, {
    String? name,
  });
  Future<void> signOut();
  Future<void> deleteAccount();
  String? get currentEmail;
  Future<void> resetPassword(String email);
  Future<bool> signInWithOAuth(OAuthProvider provider);
  Future<void> updatePassword(String password);
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  GoTrueClient get _auth => _client.auth;

  SupabaseAuthRepository(this._client);

  static const _resetRedirect = 'https://swipess.com/reset-password';

  String? get _webReferral {
    if (!kIsWeb) return null;
    final value = Uri.base.queryParameters['ref']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<AuthResponse> signInWithEmailPassword(String email, String password) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password, {
    String? name,
  }) async {
    final trimmed = name?.trim() ?? '';
    final referral = _webReferral;

    String role = 'client';
    try {
      final savedRole = await AccessGrantService.getSavedRole();
      if (savedRole != null && savedRole != 'client') {
        role = savedRole;
      }
    } catch (_) {}

    final res = await _auth.signUp(
      email: email,
      password: password,
      data: {
        'role': role,
        'name': trimmed,
        'full_name': trimmed,
        if (referral != null) 'referred_by': referral,
      },
    );
    if (res.session != null) return res;
    return _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> updatePassword(String password) {
    return _auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> deleteAccount() async {
    final session = _auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }
    final res = await _client.functions.invoke(
      'delete-user',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    final data = res.data;
    final ok = res.status == 200 && data is Map && data['success'] == true;
    if (!ok) {
      final msg = data is Map
          ? (data['error'] ?? data['details'] ?? 'Failed to delete account')
          : 'Failed to delete account';
      throw Exception(msg.toString());
    }
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Future<void> resetPassword(String email) {
    return _auth.resetPasswordForEmail(email, redirectTo: _resetRedirect);
  }

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    if (kIsWeb) {
      // Preserve the Swipess login/signup page. Supabase Flutter intentionally
      // targets `_self` for web OAuth, which replaces the whole app. Open a
      // named popup synchronously while the button gesture is still active,
      // then navigate that popup to the PKCE URL once Supabase creates it.
      final popup = openOAuthPopupPlaceholder();
      if (popup == null) {
        throw Exception(
          'Your browser blocked the sign-in window. Allow pop-ups for Swipess and try again.',
        );
      }
      try {
        final referral = _webReferral;
        final query = <String, String>{
          'oauth_popup': '1',
          if (referral != null) 'ref': referral,
        };
        final redirectTo = Uri.parse(Uri.base.origin)
            .replace(queryParameters: query)
            .toString();
        final queryParams = provider == OAuthProvider.google
            ? const {'prompt': 'select_account'}
            : null;
        final oauth = await _auth.getOAuthSignInUrl(
          provider: provider,
          redirectTo: redirectTo,
          queryParams: queryParams,
        );
        if (!navigateOAuthPopup(popup, oauth.url)) {
          throw Exception(
            'The sign-in window could not be opened. Allow pop-ups for Swipess and try again.',
          );
        }

        // Do not report success just because the provider window opened. The
        // AuthScreen must remain where it is until the popup has actually
        // completed and Supabase has synchronized the new session back to the
        // opener via its web auth broadcast channel.
        return await _waitForWebOAuthSession(popup);
      } catch (_) {
        closeOAuthPopup(popup);
        rethrow;
      }
    }

    if (provider == OAuthProvider.apple) {
      return _signInWithNativeApple();
    }
    if (provider == OAuthProvider.google) {
      return _signInWithNativeGoogle();
    }

    return _auth.signInWithOAuth(provider);
  }

  Future<bool> _waitForWebOAuthSession(OAuthPopupHandle popup) async {
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (_auth.currentSession != null) {
        closeOAuthPopup(popup);
        return true;
      }

      if (isOAuthPopupClosed(popup)) {
        // Give the BroadcastChannel a brief moment to deliver the signed-in
        // session; the popup can close a few milliseconds before the opener
        // applies that state.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (_auth.currentSession != null) return true;
        throw Exception('CANCELLED');
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    closeOAuthPopup(popup);
    throw Exception('Sign-in timed out. Please try again.');
  }

  Future<bool> _signInWithNativeApple() async {
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      return _auth.signInWithOAuth(OAuthProvider.apple);
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
            .updateUser(
              UserAttributes(data: {'full_name': fullName, 'name': fullName}),
            )
            .ignore();
      }
      final code = credential.authorizationCode;
      if (code.isNotEmpty) {
        _client.functions
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
        queryParams: const {'prompt': 'select_account'},
      );
    }
    final serverId = AppConfig.googleServerClientId.trim();
    final clientId = AppConfig.googleIosClientId.trim();
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        (serverId.isEmpty || clientId.isEmpty)) {
      throw Exception(
        'Google Sign-In is not configured for this iPhone build yet. Use Apple or email, or install the next configured TestFlight build.',
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
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
