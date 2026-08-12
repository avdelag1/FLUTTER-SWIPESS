import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:flutter_swipes/src/features/preview/presentation/screens/public_listing_preview_screen.dart';
import 'package:flutter_swipes/src/features/preview/presentation/screens/public_profile_preview_screen.dart';

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

      final publicPaths = {
        '/preview/listing',
        '/preview/profile',
        '/reset-password',
      };
      final isPublic = publicPaths.any((p) => loc.startsWith(p)) ||
          loc.startsWith('/preview/listing/') ||
          loc.startsWith('/preview/profile/');

      if (isPublic) return null;

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
      GoRoute(
        path: '/auth',
        builder: (ctx, _) {
          final intent = ref.read(authIntentProvider);
          return AuthScreen(
              mode: intent == AuthIntent.signup ? 'signup' : 'login');
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (ctx, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/preview/listing/:id',
        builder: (ctx, state) => PublicListingPreviewScreen(
          listingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/preview/profile/:id',
        builder: (ctx, state) => PublicProfilePreviewScreen(
          userId: state.pathParameters['id']!,
        ),
      ),
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
