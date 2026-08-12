import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthIntent { login, signup }

class SessionState {
  const SessionState({
    this.accessGranted = false,
    this.isAuthenticated = false,
    this.authIntent = AuthIntent.login,
    this.displayName = 'Alex',
  });

  final bool accessGranted;
  final bool isAuthenticated;
  final AuthIntent authIntent;
  final String displayName;

  SessionState copyWith({
    bool? accessGranted,
    bool? isAuthenticated,
    AuthIntent? authIntent,
    String? displayName,
  }) {
    return SessionState(
      accessGranted: accessGranted ?? this.accessGranted,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      authIntent: authIntent ?? this.authIntent,
      displayName: displayName ?? this.displayName,
    );
  }
}

/// In-memory session for the design preview.
/// Real persistence / Supabase auth will be wired by the bases agent.
class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void grantAccess() {
    state = state.copyWith(accessGranted: true);
  }

  void openAuth(AuthIntent intent) {
    state = state.copyWith(authIntent: intent);
  }

  void signInDemo({String? name}) {
    state = state.copyWith(
      isAuthenticated: true,
      displayName: name?.trim().isNotEmpty == true ? name!.trim() : state.displayName,
    );
  }

  void signOut() {
    state = state.copyWith(isAuthenticated: false);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
