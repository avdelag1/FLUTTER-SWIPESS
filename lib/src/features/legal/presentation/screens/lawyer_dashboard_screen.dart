import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/legal/data/legal_repository.dart';
import 'package:flutter_swipes/src/features/portals/data/role_portal_repository.dart';
import 'package:flutter_swipes/src/features/portals/presentation/providers/role_portal_providers.dart';
import 'package:flutter_swipes/src/features/portals/presentation/widgets/role_portal_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class LawyerDashboardScreen extends ConsumerWidget {
  const LawyerDashboardScreen({super.key});

  static const _accent = Color(0xFF6366F1);

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentLawyerProvider);
    ref.invalidate(lawyerLegalQueueProvider);
    ref.invalidate(lawyerCallsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentLawyerProvider);
    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const PortalLoading(),
          error: (_, _) => _AccessState(
            title: 'Could not verify lawyer access',
            message: 'Retry your profile verification before opening the portal.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(currentLawyerProvider),
          ),
          data: (profile) {
            if (profile == null) {
              return _AccessState(
                title: 'Lawyer profile required',
                message:
                    'This portal is reserved for verified lawyer accounts. Your client legal services remain available in the app.',
                actionLabel: 'Back to legal',
                onAction: () => context.go(AppPaths.clientLegalServices),
              );
            }
            if (!profile.isActive) {
              return _AccessState(
                title: 'Approval pending',
                message:
                    'Your lawyer profile exists but is not active yet. An administrator must approve it before you can receive cases or calls.',
                actionLabel: 'Back to legal',
                onAction: () => context.go(AppPaths.clientLegalServices),
              );
            }
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                children: [
                  PortalHero(
                    eyebrow: 'Lawyer portal',
                    title: profile.fullName.toUpperCase(),
                    subtitle: profile.specialization.isEmpty
                        ? 'Manage your legal queue, availability and live consultations.'
                        : '${profile.specialization} · Manage your queue, availability and live consultations.',
                    icon: Icons.gavel_rounded,
                    accent: _accent,
                    trailing: PortalStatusPill(
                      label: profile.isAvailable ? 'available' : 'offline',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PortalPillButton(
                        label: profile.isAvailable ? 'Go offline' : 'Go available',
                        icon: profile.isAvailable
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        accent: profile.isAvailable
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF22C55E),
                        filled: !profile.isAvailable,
                        onTap: () async {
                          await ref
                              .read(rolePortalRepositoryProvider)
                              .setLawyerAvailability(!profile.isAvailable);
                          ref.invalidate(currentLawyerProvider);
                        },
                      ),
                      PortalPillButton(
                        label: 'Back to app',
                        icon: Icons.home_rounded,
                        accent: _accent,
                        onTap: () => context.go(AppPaths.clientDashboard),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const PortalSectionTitle(
                    title: 'Live consultations',
                    subtitle: 'Incoming calls appear first. Accept only when you are ready to join.',
                  ),
                  const SizedBox(height: 10),
                  _calls(context, ref, profile),
                  const SizedBox(height: 24),
                  const PortalSectionTitle(
                    title: 'Case queue',
                    subtitle: 'Requests visible to active lawyers through database access rules.',
                  ),
                  const SizedBox(height: 10),
                  _requests(context, ref),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _calls(
    BuildContext context,
    WidgetRef ref,
    PortalLawyerProfile profile,
  ) {
    final async = ref.watch(lawyerCallsProvider);
    return async.when(
      loading: () => const PortalLoading(),
      error: (_, _) => PortalEmptyState(
        icon: Icons.sync_problem_rounded,
        title: 'Could not load calls',
        message: 'Pull to refresh or retry.',
        action: PortalPillButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          accent: _accent,
          onTap: () => ref.invalidate(lawyerCallsProvider),
        ),
      ),
      data: (rows) {
        final visible = rows.where((call) {
          return call.status == 'ringing' ||
              call.lawyerUserId == profile.userId ||
              call.status == 'accepted';
        }).toList()
          ..sort((a, b) {
            if (a.status == 'ringing' && b.status != 'ringing') return -1;
            if (a.status != 'ringing' && b.status == 'ringing') return 1;
            return (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            );
          });
        if (visible.isEmpty) {
          return const PortalEmptyState(
            icon: Icons.videocam_outlined,
            title: 'No calls waiting',
            message: 'When a client requests a live consultation it will appear here.',
          );
        }
        return Column(
          children: [
            for (final call in visible.take(20)) ...[
              PortalCard(
                accent: call.status == 'ringing'
                    ? const Color(0xFF22C55E)
                    : _accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            call.clientName,
                            style: _titleStyle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PortalStatusPill(label: call.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(call.topic, style: _bodyStyle(context)),
                    if (call.clientEmail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(call.clientEmail, style: _mutedStyle(context)),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (call.status == 'ringing')
                          PortalPillButton(
                            label: 'Accept call',
                            icon: Icons.videocam_rounded,
                            accent: const Color(0xFF22C55E),
                            filled: true,
                            onTap: profile.isAvailable
                                ? () async {
                                    final accepted = await ref
                                        .read(rolePortalRepositoryProvider)
                                        .acceptLegalVideoCall(call.id);
                                    ref.invalidate(lawyerCallsProvider);
                                    if (!accepted || !context.mounted) return;
                                    await _openRoom(
                                      call.roomId,
                                      profile.fullName,
                                    );
                                  }
                                : null,
                          ),
                        if (call.status == 'accepted' &&
                            call.lawyerUserId == profile.userId)
                          PortalPillButton(
                            label: 'Join room',
                            icon: Icons.open_in_new_rounded,
                            accent: _accent,
                            onTap: () => _openRoom(
                              call.roomId,
                              profile.fullName,
                            ),
                          ),
                        if (call.status == 'accepted' &&
                            call.lawyerUserId == profile.userId)
                          PortalPillButton(
                            label: 'End',
                            icon: Icons.call_end_rounded,
                            accent: const Color(0xFFEF4444),
                            onTap: () async {
                              await ref
                                  .read(rolePortalRepositoryProvider)
                                  .endLegalVideoCall(call.id);
                              ref.invalidate(lawyerCallsProvider);
                            },
                          ),
                      ],
                    ),
                    if (call.status == 'ringing' && !profile.isAvailable) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Turn on Available before accepting calls.',
                        style: _mutedStyle(context),
                      ),
                    ],
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

  Widget _requests(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lawyerLegalQueueProvider);
    return async.when(
      loading: () => const PortalLoading(),
      error: (_, _) => PortalEmptyState(
        icon: Icons.sync_problem_rounded,
        title: 'Could not load cases',
        message: 'Pull to refresh or retry.',
        action: PortalPillButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          accent: _accent,
          onTap: () => ref.invalidate(lawyerLegalQueueProvider),
        ),
      ),
      data: (rows) {
        final open = rows
            .where(
              (r) => !const {'completed', 'closed', 'cancelled'}.contains(r.status),
            )
            .toList();
        if (open.isEmpty) {
          return const PortalEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Queue clear',
            message: 'There are no open legal package requests right now.',
          );
        }
        return Column(
          children: [
            for (final item in open.take(40)) ...[
              PortalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.packageName,
                            style: _titleStyle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PortalStatusPill(label: item.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.fullName} · ${item.category}',
                      style: _mutedStyle(context),
                    ),
                    if (item.situation.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.situation,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle(context),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (item.status == 'pending')
                          PortalPillButton(
                            label: 'Start review',
                            icon: Icons.play_arrow_rounded,
                            accent: const Color(0xFFF59E0B),
                            onTap: () => _setRequestStatus(
                              ref,
                              item.id,
                              'reviewing',
                            ),
                          ),
                        PortalPillButton(
                          label: 'Complete',
                          icon: Icons.check_rounded,
                          accent: const Color(0xFF22C55E),
                          onTap: () => _setRequestStatus(
                            ref,
                            item.id,
                            'completed',
                          ),
                        ),
                      ],
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

  Future<void> _setRequestStatus(
    WidgetRef ref,
    String id,
    String status,
  ) async {
    await ref
        .read(rolePortalRepositoryProvider)
        .updateLegalRequest(id: id, status: status);
    ref.invalidate(lawyerLegalQueueProvider);
  }

  Future<void> _openRoom(String roomId, String displayName) async {
    final uri = Uri.parse(LegalRepository.jitsiUrl(roomId, displayName));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AccessState extends StatelessWidget {
  const _AccessState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      children: [
        PortalEmptyState(
          icon: Icons.gavel_rounded,
          title: title,
          message: message,
          action: PortalPillButton(
            label: actionLabel,
            icon: Icons.arrow_back_rounded,
            accent: LawyerDashboardScreen._accent,
            onTap: onAction,
          ),
        ),
      ],
    );
  }
}

TextStyle _titleStyle(BuildContext context) => TextStyle(
      color: MatteSurface.ink(context),
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );

TextStyle _bodyStyle(BuildContext context) => TextStyle(
      color: MatteSurface.ink(context).withAlpha(165),
      fontSize: 12.5,
      height: 1.35,
    );

TextStyle _mutedStyle(BuildContext context) => TextStyle(
      color: MatteSurface.ink(context).withAlpha(110),
      fontSize: 10.5,
    );
