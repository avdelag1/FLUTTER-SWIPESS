import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:flutter_swipes/src/features/portals/presentation/providers/role_portal_providers.dart';
import 'package:flutter_swipes/src/features/portals/presentation/widgets/role_portal_ui.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  static const _accent = Color(0xFFFF4D8D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPortalOverviewProvider);
    final ink = MatteSurface.ink(context);
    return AdminShell(
      title: 'Admin Dashboard',
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminPortalOverviewProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
          children: [
            const PortalHero(
              eyebrow: 'Command center',
              title: 'CONTROL THE WHOLE SYSTEM',
              subtitle:
                  'One place for events, business approvals, legal operations, media and performance.',
              icon: Icons.radar_rounded,
              accent: _accent,
            ),
            const SizedBox(height: 18),
            async.when(
              loading: () => const PortalLoading(),
              error: (error, _) => PortalEmptyState(
                icon: Icons.sync_problem_rounded,
                title: 'Dashboard data unavailable',
                message: 'The admin role is valid, but the overview could not load.',
                action: PortalPillButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onTap: () => ref.invalidate(adminPortalOverviewProvider),
                  accent: _accent,
                ),
              ),
              data: (data) => LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 900 ? 4 : 2;
                  final gap = 10.0;
                  final itemWidth = (width - gap * (columns - 1)) / columns;
                  final cards = [
                    PortalMetricCard(
                      label: 'Published events',
                      value: '${data.publishedEvents}',
                      caption: '${data.totalEvents} total',
                      icon: Icons.event_available_rounded,
                      accent: const Color(0xFF818CF8),
                      onTap: () => context.go(AppPaths.adminEventos),
                    ),
                    PortalMetricCard(
                      label: 'Business review',
                      value: '${data.pendingBusinessSubmissions}',
                      caption: '${data.businessSubmissions} submissions',
                      icon: Icons.storefront_rounded,
                      accent: const Color(0xFFF59E0B),
                      onTap: () => context.go(AppPaths.adminEventos),
                    ),
                    PortalMetricCard(
                      label: 'Open legal',
                      value: '${data.openLegalRequests}',
                      caption: '${data.legalRequests} requests',
                      icon: Icons.balance_rounded,
                      accent: const Color(0xFF6366F1),
                      onTap: () => context.go(AppPaths.adminLegal),
                    ),
                    PortalMetricCard(
                      label: 'Available lawyers',
                      value: '${data.availableLawyers}',
                      caption: '${data.activeLawyers} active',
                      icon: Icons.support_agent_rounded,
                      accent: const Color(0xFF22C55E),
                      onTap: () => context.go(AppPaths.adminLegal),
                    ),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final card in cards)
                        SizedBox(width: itemWidth, child: card),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const PortalSectionTitle(
              title: 'Operations',
              subtitle: 'The most important privileged surfaces stay one tap away.',
            ),
            const SizedBox(height: 10),
            PortalCard(
              onTap: () => context.go(AppPaths.adminLegal),
              accent: const Color(0xFF6366F1),
              child: _ActionRow(
                icon: Icons.balance_rounded,
                title: 'Legal Admin',
                subtitle: 'Review client requests, calls and lawyer availability.',
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 10),
            PortalCard(
              onTap: () => context.go(AppPaths.adminEventos),
              accent: const Color(0xFFF59E0B),
              child: _ActionRow(
                icon: Icons.campaign_rounded,
                title: 'Events + Business Promotions',
                subtitle: 'Approve submissions, publish events and control visibility.',
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 10),
            PortalCard(
              onTap: () => context.go(AppPaths.adminPhotos),
              child: _ActionRow(
                icon: Icons.photo_library_rounded,
                title: 'Media Library',
                subtitle: 'Review uploads and category artwork.',
                color: _accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Privileged actions are protected by database policies, not only by these screens.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ink.withAlpha(90), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: ink.withAlpha(120), fontSize: 11.5),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: ink.withAlpha(90)),
      ],
    );
  }
}
