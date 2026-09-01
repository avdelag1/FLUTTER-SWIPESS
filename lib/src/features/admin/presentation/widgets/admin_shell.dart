import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/admin/presentation/providers/admin_provider.dart';
import 'package:flutter_swipes/src/features/admin/presentation/screens/admin_interaction_diagnostics_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Protected, mobile-safe admin chrome shared by all admin surfaces.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(isAdminProvider);
    return async.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      ),
      error: (_, _) => Scaffold(
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
            body: Center(
              child: Text(
                t(ref, 'flutter.notAdmin', 'Admin only'),
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
            ),
          );
        }

        final isLight = Theme.of(context).brightness == Brightness.light;
        final foreground = isLight ? const Color(0xFF111318) : Colors.white;
        return Scaffold(
          backgroundColor: AppTheme.canvasFor(isLight: isLight),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.white.withAlpha(222)
                              : AppTheme.dashGlassStrong.withAlpha(224),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: isLight
                                ? Colors.black.withAlpha(22)
                                : Colors.white.withAlpha(38),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isLight ? 16 : 60),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () =>
                                        context.go(AppPaths.adminDashboard),
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: AppTheme.dashboardFilterPill(
                                        isLight: isLight,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.admin_panel_settings_outlined,
                                        color: foreground,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SWIPESS ADMIN',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: foreground.withAlpha(150),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: foreground,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Touch diagnostics',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () => Navigator.of(context).push<void>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AdminInteractionDiagnosticsScreen(),
                                        ),
                                      ),
                                      child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: AppTheme.dashboardFilterPill(
                                          isLight: isLight,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.bug_report_outlined,
                                          color: foreground,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _NavChip(
                                    label: 'Home',
                                    path: AppPaths.adminDashboard,
                                  ),
                                  _NavChip(
                                    label: t(
                                      ref,
                                      'flutter.adminEvents',
                                      'Events',
                                    ),
                                    path: AppPaths.adminEventos,
                                  ),
                                  _NavChip(
                                    label: t(
                                      ref,
                                      'flutter.adminPhotos',
                                      'Photos',
                                    ),
                                    path: AppPaths.adminPhotos,
                                  ),
                                  _NavChip(
                                    label: t(
                                      ref,
                                      'flutter.adminCategory',
                                      'Categories',
                                    ),
                                    path: AppPaths.adminCategoryPhotos,
                                  ),
                                  _NavChip(
                                    label: 'App text',
                                    path: AppPaths.adminAppCopy,
                                  ),
                                  _NavChip(
                                    label: t(
                                      ref,
                                      'flutter.adminPerformance',
                                      'Performance',
                                    ),
                                    path: AppPaths.adminPerformance,
                                  ),
                                  _NavChip(
                                    label: 'Legal',
                                    path: AppPaths.legalAdminDashboard,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => context.go(path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: AppTheme.dashboardFilterPill(isLight: isLight).copyWith(
              color: here
                  ? foreground.withAlpha(isLight ? 22 : 34)
                  : (isLight
                        ? Colors.white.withAlpha(190)
                        : AppTheme.dashGlass),
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
