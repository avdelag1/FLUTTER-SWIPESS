import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/portals/data/role_portal_repository.dart';
import 'package:flutter_swipes/src/features/portals/presentation/providers/role_portal_providers.dart';
import 'package:flutter_swipes/src/features/portals/presentation/widgets/role_portal_ui.dart';
import 'package:go_router/go_router.dart';

class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  static const _accent = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessSubmissionsProvider);
    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(businessSubmissionsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
            children: [
              const PortalHero(
                eyebrow: 'Business portal',
                title: 'GROW YOUR VISIBILITY',
                subtitle:
                    'Track your Swipess promotions, approval status and media from one clean business workspace.',
                icon: Icons.storefront_rounded,
                accent: _accent,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PortalPillButton(
                    label: 'Create promotion',
                    icon: Icons.add_rounded,
                    accent: _accent,
                    filled: true,
                    onTap: () => context.go(AppPaths.clientAdvertise),
                  ),
                  PortalPillButton(
                    label: 'Back to app',
                    icon: Icons.home_rounded,
                    accent: _accent,
                    onTap: () => context.go(AppPaths.clientDashboard),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              async.when(
                loading: () => const PortalLoading(),
                error: (_, _) => PortalEmptyState(
                  icon: Icons.sync_problem_rounded,
                  title: 'Could not load business activity',
                  message: 'Pull to refresh or retry your promotion history.',
                  action: PortalPillButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    accent: _accent,
                    onTap: () => ref.invalidate(businessSubmissionsProvider),
                  ),
                ),
                data: (rows) => _content(context, rows),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<PortalBusinessSubmission> rows,
  ) {
    final pending = rows.where((e) => e.status == 'pending').length;
    final approved = rows.where((e) => e.status == 'approved').length;
    final rejected = rows.where((e) => e.status == 'rejected').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = 10.0;
            final itemWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: PortalMetricCard(
                    label: 'Promotions',
                    value: '${rows.length}',
                    caption: 'All submissions',
                    icon: Icons.campaign_rounded,
                    accent: _accent,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: PortalMetricCard(
                    label: 'Approved',
                    value: '$approved',
                    caption: 'Live or cleared',
                    icon: Icons.verified_rounded,
                    accent: const Color(0xFF22C55E),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: PortalMetricCard(
                    label: 'Pending',
                    value: '$pending',
                    caption: 'Waiting for review',
                    icon: Icons.schedule_rounded,
                    accent: const Color(0xFFF59E0B),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: PortalMetricCard(
                    label: 'Needs changes',
                    value: '$rejected',
                    caption: 'Rejected / resubmit',
                    icon: Icons.edit_note_rounded,
                    accent: const Color(0xFFEF4444),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const PortalSectionTitle(
          title: 'Promotion history',
          subtitle: 'Status comes from the same review queue used by Swipess Admin.',
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          PortalEmptyState(
            icon: Icons.storefront_outlined,
            title: 'No promotions yet',
            message:
                'Create your first business or event promotion and follow its review status here.',
            action: PortalPillButton(
              label: 'Create promotion',
              icon: Icons.add_rounded,
              accent: _accent,
              filled: true,
              onTap: () => context.go(AppPaths.clientAdvertise),
            ),
          )
        else
          for (final item in rows) ...[
            _PromotionCard(item: item),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.item});

  final PortalBusinessSubmission item;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final statusColor = PortalStatusPill.statusColor(item.status);
    return PortalCard(
      accent: statusColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 58,
              height: 58,
              color: statusColor.withAlpha(20),
              child: item.imageUrl.isEmpty
                  ? Icon(Icons.campaign_rounded, color: statusColor, size: 25)
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: ink.withAlpha(80),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PortalStatusPill(label: item.status),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [item.type, item.location]
                      .where((value) => value.trim().isNotEmpty)
                      .join(' · '),
                  style: TextStyle(color: ink.withAlpha(135), fontSize: 11.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (item.imageUrl.isNotEmpty)
                      _miniChip(context, Icons.image_rounded, 'Photo'),
                    if (item.videoUrl.isNotEmpty)
                      _miniChip(context, Icons.play_circle_rounded, 'Video'),
                    if (item.website.isNotEmpty)
                      _miniChip(context, Icons.language_rounded, 'Website'),
                  ],
                ),
                if (item.status == 'rejected') ...[
                  const SizedBox(height: 10),
                  PortalPillButton(
                    label: 'Edit / resubmit',
                    icon: Icons.edit_rounded,
                    accent: const Color(0xFFEF4444),
                    onTap: () => context.go(AppPaths.clientAdvertise),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(BuildContext context, IconData icon, String label) {
    final ink = MatteSurface.ink(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ink.withAlpha(8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withAlpha(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ink.withAlpha(120)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: ink.withAlpha(130),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
