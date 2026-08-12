import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/gate',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final granted = ref.read(accessGrantedProvider).value ?? false;
      final user = ref.read(currentUserProvider);

      if (!granted && loc != '/gate') return '/gate';

      if (granted && user == null) {
        if (loc == '/gate') return '/welcome';
        if (loc == '/dashboard') return '/welcome';
      }

      if (user != null &&
          (loc == '/gate' || loc == '/welcome' || loc == '/auth')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/gate', builder: (ctx, _) => const AccessCodeGateScreen()),
      GoRoute(path: '/welcome', builder: (ctx, _) => const WelcomeScreen()),
      GoRoute(path: '/auth', builder: (ctx, _) => const AuthScreen()),
      GoRoute(path: '/dashboard', builder: (ctx, _) => const DashboardShell()),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _authSub = ref.listen(authStateProvider, (_, _) => notifyListeners());
    _grantSub = ref.listen(accessGrantedProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<AsyncValue<dynamic>> _authSub;
  late final ProviderSubscription<AsyncValue<bool>> _grantSub;

  @override
  void dispose() {
    _authSub.close();
    _grantSub.close();
    super.dispose();
  }
}
