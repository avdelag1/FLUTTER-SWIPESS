import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';


class AppRouter {
  static final router = GoRouter(
    initialLocation: '/access',
    routes: [
      GoRoute(
        path: '/access',
        builder: (context, state) => const AccessCodeGateScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'login';
          return AuthScreen(mode: mode);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardShell(),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) {
          // Dummy for now, since we aren't passing objects via deep links properly yet.
          return const Scaffold(body: Center(child: Text('Event Detail')));
        },
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (context, state) {
          // Dummy for now
          return const Scaffold(body: Center(child: Text('Chat Room')));
        },
      ),
    ],
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.router;
});
