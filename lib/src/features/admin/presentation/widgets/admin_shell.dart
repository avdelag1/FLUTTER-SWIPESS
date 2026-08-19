import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/features/admin/presentation/providers/admin_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Role-protected admin chrome shared by every admin surface.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static const _accent = Color(0xFFFF4D8D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(isAdminProvider);
    final ink = MatteSurface.ink(context);
    return async.when(
      loading: () => Scaffold(
        backgroundColor: MatteSurface.canvas(context),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: MatteSurface.canvas(context),
        body: Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(isAdminProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Could not verify admin — retry'),
          ),
        ),
      ),
      data: (ok) {
        if (!ok) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(AppPaths.clientDashboard);
          });
          return Scaffold(
            backgroundColor: MatteSurface.canvas(context),
            body: Center(
              child: Text(
                t(ref, 'flutter.notAdmin', 'Admin only'),
                style: GoogleFonts.plusJakartaSans(
                  color: ink.withAlpha(160),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: MatteSurface.canvas(context),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _accent.withAlpha(30),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _accent.withAlpha(85)),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: _accent,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SWIPESS CONTROL',
                              style: SwipessTokens.kickerUppercase(
                                color: _accent,
                                fontSize: 9.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwipessTokens.displayItalic(
                                color: ink,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Back to app',
                        onPressed: () => context.go(AppPaths.clientDashboard),
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _NavChip(
                        icon: Icons.space_dashboard_rounded,
                        label: 'Overview',
                        path: AppPaths.adminDashboard,
                      ),
                      _NavChip(
                        icon: Icons.event_rounded,
                        label: t(ref, 'flutter.adminEvents', 'Events'),
                        path: AppPaths.adminEventos,
                      ),
                      _NavChip(
                        icon: Icons.balance_rounded,
                        label: 'Legal',
                        path: AppPaths.adminLegal,
                      ),
                      _NavChip(
                        icon: Icons.photo_library_rounded,
                        label: t(ref, 'flutter.adminPhotos', 'Photos'),
                        path: AppPaths.adminPhotos,
                      ),
                      _NavChip(
                        icon: Icons.dashboard_customize_rounded,
                        label: t(ref, 'flutter.adminCategory', 'Categories'),
                        path: AppPaths.adminCategoryPhotos,
                      ),
                      _NavChip(
                        icon: Icons.speed_rounded,
                        label: t(ref, 'flutter.adminPerformance', 'Perf'),
                        path: AppPaths.adminPerformance,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
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
  const _NavChip({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final here = GoRouterState.of(context).uri.path == path;
    final ink = MatteSurface.ink(context);
    final light = MatteSurface.isLight(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(path),
          borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: here
                  ? ink
                  : (light ? Colors.black.withAlpha(8) : Colors.white.withAlpha(10)),
              borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
              border: Border.all(
                color: here
                    ? Colors.transparent
                    : (light ? Colors.black.withAlpha(18) : Colors.white.withAlpha(18)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: here ? MatteSurface.canvas(context) : ink.withAlpha(175),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: here ? MatteSurface.canvas(context) : ink.withAlpha(175),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
