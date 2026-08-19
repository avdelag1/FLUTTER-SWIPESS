import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:flutter_swipes/src/features/portals/data/legal_admin_repository.dart';
import 'package:flutter_swipes/src/features/portals/data/role_portal_repository.dart';
import 'package:flutter_swipes/src/features/portals/presentation/providers/legal_admin_providers.dart';
import 'package:flutter_swipes/src/features/portals/presentation/providers/role_portal_providers.dart';
import 'package:flutter_swipes/src/features/portals/presentation/widgets/role_portal_ui.dart';

class AdminLegalScreen extends ConsumerStatefulWidget {
  const AdminLegalScreen({super.key});

  @override
  ConsumerState<AdminLegalScreen> createState() => _AdminLegalScreenState();
}

class _AdminLegalScreenState extends ConsumerState<AdminLegalScreen> {
  int _tab = 0;
  static const _accent = Color(0xFF6366F1);

  Future<void> _refresh() async {
    ref.invalidate(adminLegalQueueProvider);
    ref.invalidate(adminLegalCallsProvider);
    ref.invalidate(legalAdminLawyersProvider);
    ref.invalidate(adminPortalOverviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Legal Admin',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
          children: [
            const PortalHero(
              eyebrow: 'Legal operations',
              title: 'LEGAL ADMIN',
              subtitle:
                  'Review client requests, monitor live calls, and manage approved lawyer access from one secure queue.',
              icon: Icons.balance_rounded,
              accent: _accent,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tabButton(0, 'Requests', Icons.inbox_rounded),
                  const SizedBox(width: 8),
                  _tabButton(1, 'Calls', Icons.videocam_rounded),
                  const SizedBox(width: 8),
                  _tabButton(2, 'Lawyers', Icons.badge_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_tab == 0) _requests(),
            if (_tab == 1) _calls(),
            if (_tab == 2) _lawyers(),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    return PortalPillButton(
      label: label,
      icon: icon,
      accent: _accent,
      filled: _tab == index,
      onTap: () => setState(() => _tab = index),
    );
  }

  Widget _requests() {
    final async = ref.watch(adminLegalQueueProvider);
    return async.when(
      loading: () => const PortalLoading(),
      error: (_, _) => PortalEmptyState(
        icon: Icons.sync_problem_rounded,
        title: 'Could not load legal requests',
        message: 'Pull to refresh or retry the legal queue.',
        action: PortalPillButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          accent: _accent,
          onTap: () => ref.invalidate(adminLegalQueueProvider),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const PortalEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No legal requests yet',
            message: 'New package requests will appear here automatically.',
          );
        }
        return Column(
          children: [
            for (final item in rows) ...[
              _RequestCard(
                item: item,
                onStatus: (status) async {
                  await ref
                      .read(rolePortalRepositoryProvider)
                      .updateLegalRequest(id: item.id, status: status);
                  ref.invalidate(adminLegalQueueProvider);
                  ref.invalidate(adminPortalOverviewProvider);
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _calls() {
    final async = ref.watch(adminLegalCallsProvider);
    return async.when(
      loading: () => const PortalLoading(),
      error: (_, _) => PortalEmptyState(
        icon: Icons.sync_problem_rounded,
        title: 'Could not load calls',
        message: 'Pull to refresh or retry the live-call queue.',
        action: PortalPillButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          accent: _accent,
          onTap: () => ref.invalidate(adminLegalCallsProvider),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const PortalEmptyState(
            icon: Icons.videocam_off_outlined,
            title: 'No legal calls yet',
            message: 'Incoming and completed legal video calls will appear here.',
          );
        }
        return Column(
          children: [
            for (final call in rows) ...[
              PortalCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBox(Icons.videocam_rounded, _accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  call.clientName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _titleStyle(context),
                                ),
                              ),
                              PortalStatusPill(label: call.status),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(call.topic, style: _bodyStyle(context)),
                          if (call.clientEmail.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(call.clientEmail, style: _mutedStyle(context)),
                          ],
                          if (const {'ringing', 'accepted'}.contains(call.status)) ...[
                            const SizedBox(height: 12),
                            PortalPillButton(
                              label: 'End call',
                              icon: Icons.call_end_rounded,
                              accent: const Color(0xFFEF4444),
                              onTap: () async {
                                await ref
                                    .read(rolePortalRepositoryProvider)
                                    .endLegalVideoCall(call.id);
                                ref.invalidate(adminLegalCallsProvider);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _lawyers() {
    final async = ref.watch(legalAdminLawyersProvider);
    return async.when(
      loading: () => const PortalLoading(),
      error: (_, _) => PortalEmptyState(
        icon: Icons.sync_problem_rounded,
        title: 'Could not load lawyers',
        message: 'Pull to refresh or retry the lawyer directory.',
        action: PortalPillButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          accent: _accent,
          onTap: () => ref.invalidate(legalAdminLawyersProvider),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const PortalEmptyState(
            icon: Icons.badge_outlined,
            title: 'No lawyer profiles',
            message: 'Lawyer applications will appear here for approval.',
          );
        }
        return Column(
          children: [
            for (final lawyer in rows) ...[
              PortalCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBox(Icons.gavel_rounded, const Color(0xFF22C55E)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lawyer.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _titleStyle(context),
                                ),
                              ),
                              PortalStatusPill(
                                label: lawyer.isActive ? 'active' : 'pending',
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            lawyer.specialization.isEmpty
                                ? 'General legal services'
                                : lawyer.specialization,
                            style: _bodyStyle(context),
                          ),
                          if (lawyer.barNumber.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Bar / credential: ${lawyer.barNumber}',
                              style: _mutedStyle(context),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              PortalStatusPill(
                                label: lawyer.isAvailable ? 'available' : 'offline',
                              ),
                              PortalPillButton(
                                label: lawyer.isActive ? 'Suspend' : 'Approve',
                                icon: lawyer.isActive
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.verified_user_rounded,
                                accent: lawyer.isActive
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF22C55E),
                                onTap: () async {
                                  await ref
                                      .read(legalAdminRepositoryProvider)
                                      .setLawyerActive(
                                        lawyer.userId,
                                        !lawyer.isActive,
                                      );
                                  ref.invalidate(legalAdminLawyersProvider);
                                  ref.invalidate(adminPortalOverviewProvider);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, required this.onStatus});

  final PortalLegalRequest item;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return PortalCard(
      accent: const Color(0xFF6366F1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.packageName,
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
          const SizedBox(height: 6),
          Text(
            '${item.fullName} · ${item.category}',
            style: TextStyle(color: ink.withAlpha(145), fontSize: 11.5),
          ),
          if (item.situation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.situation,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ink.withAlpha(175), fontSize: 12.5, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.status == 'pending')
                PortalPillButton(
                  label: 'Review',
                  icon: Icons.visibility_rounded,
                  accent: const Color(0xFFF59E0B),
                  onTap: () => onStatus('reviewing'),
                ),
              if (!const {'completed', 'closed', 'cancelled'}.contains(item.status))
                PortalPillButton(
                  label: 'Complete',
                  icon: Icons.check_rounded,
                  accent: const Color(0xFF22C55E),
                  onTap: () => onStatus('completed'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _iconBox(IconData icon, Color color) {
  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

TextStyle _titleStyle(BuildContext context) => TextStyle(
      color: MatteSurface.ink(context),
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );

TextStyle _bodyStyle(BuildContext context) => TextStyle(
      color: MatteSurface.ink(context).withAlpha(155),
      fontSize: 12,
      height: 1.35,
    );

TextStyle _mutedStyle(BuildContext context) => TextStyle(
      color: MatteSurface.ink(context).withAlpha(105),
      fontSize: 10.5,
    );
