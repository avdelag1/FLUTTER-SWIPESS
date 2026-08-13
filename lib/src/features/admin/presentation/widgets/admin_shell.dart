import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/admin/presentation/providers/admin_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `AdminProtectedRoute` + page chrome for the four admin surfaces.
class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(isAdminProvider);
    return async.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0A0A0D),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: const Color(0xFF0A0A0D),
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(isAdminProvider),
            child: const Text('Could not verify admin — retry'),
          ),
        ),
      ),
      data: (ok) {
        if (!ok) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(AppPaths.clientDashboard);
          });
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0D),
            body: Center(
              child: Text(
                t(ref, 'flutter.notAdmin', 'Admin only'),
                style: GoogleFonts.plusJakartaSans(color: Colors.white70),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0D),
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title, style: AppTheme.displayItalic.copyWith(fontSize: 20)),
            actions: [
              _NavChip(label: t(ref, 'flutter.adminEvents', 'Events'), path: AppPaths.adminEventos),
              _NavChip(label: t(ref, 'flutter.adminPhotos', 'Photos'), path: AppPaths.adminPhotos),
              _NavChip(label: t(ref, 'flutter.adminCategory', 'Categories'), path: AppPaths.adminCategoryPhotos),
              _NavChip(label: t(ref, 'flutter.adminPerformance', 'Perf'), path: AppPaths.adminPerformance),
              const SizedBox(width: 8),
            ],
          ),
          body: child,
        );
      },
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.label, required this.path});
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final here = GoRouterState.of(context).uri.path == path;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: here ? Colors.black : Colors.white,
          ),
        ),
        backgroundColor: here ? Colors.white : Colors.white.withAlpha(18),
        onPressed: () => context.go(path),
      ),
    );
  }
}
