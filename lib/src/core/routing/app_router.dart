
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/services/access_grant_service.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/gate',
    redirect: (context, state) async {
      final user = authState.when(
        data: (s) => s.session?.user,
        loading: () => null,
        error: (e, st) => null,
      );

      final isGranted = await AccessGrantService.isGranted();

      // Not yet granted access code → show gate
      if (!isGranted) return '/gate';

      // Has access but not logged in → show login
      if (user == null) return '/login';

      // Logged in → go to dashboard
      if (state.uri.toString() == '/gate' || state.uri.toString() == '/login') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/gate', builder: (ctx, _) => const AccessCodeGateScreen()),
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (ctx, _) => const DashboardShell()),
    ],
  );
});
