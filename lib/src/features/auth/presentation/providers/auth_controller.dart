import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final res = await ref
          .read(authRepositoryProvider)
          .signInWithEmailPassword(email, password);
      ref.read(currentUserProvider.notifier).apply(res.user);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(_mapError(e), st);
      return false;
    }
  }

  Future<bool> signup(String email, String password, {String? name}) async {
    state = const AsyncLoading();
    try {
      final res = await ref
          .read(authRepositoryProvider)
          .signUpWithEmailPassword(email, password, name: name);
      ref.read(currentUserProvider.notifier).apply(res.user);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(_mapError(e), st);
      return false;
    }
  }

  Future<bool> loginWithOAuth(OAuthProvider provider) async {
    state = const AsyncLoading();
    try {
      final success = await ref
          .read(authRepositoryProvider)
          .signInWithOAuth(provider);
      state = const AsyncData(null);
      return success;
    } catch (e, st) {
      if (e.toString().contains('CANCELLED')) {
        state = const AsyncData(null);
        return false;
      }
      state = AsyncError(_mapError(e), st);
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(_mapError(e), st);
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(_mapError(e), st);
      return false;
    }
  }

  String _mapError(Object e) {
    final raw = e is AuthException ? e.message : e.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('banned') ||
        normalized.contains('user_banned') ||
        normalized.contains('account is disabled')) {
      return 'This account is unavailable. Contact support if you need assistance.';
    }
    if (e is AuthException) return e.message;
    return raw.replaceAll('Exception: ', '');
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
