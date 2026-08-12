import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/session/session_controller.dart';
import 'package:flutter_swipes/src/features/access/presentation/screens/access_code_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/swiper_screen.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/access',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (!session.accessGranted && loc != '/access') {
        return '/access';
      }
      if (session.accessGranted && !session.isAuthenticated) {
        if (loc == '/access') return '/welcome';
        if (loc == '/dashboard' || loc == '/swipes') return '/welcome';
      }
      if (session.isAuthenticated &&
          (loc == '/access' || loc == '/welcome' || loc == '/auth')) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/access',
        builder: (context, state) => const AccessCodeScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/swipes',
        builder: (context, state) => const SwiperScreen(),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _sub = ref.listen<SessionState>(sessionProvider, (_, _) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<SessionState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
