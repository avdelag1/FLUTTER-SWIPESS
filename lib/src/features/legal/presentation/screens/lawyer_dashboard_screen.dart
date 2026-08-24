import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/role_control_center.dart';
import 'package:flutter_swipes/src/features/legal/domain/lawyer_workspace.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/lawyer_workspace_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/lawyer_intake_screen.dart';
import 'package:intl/intl.dart';

class LawyerDashboardScreen extends ConsumerWidget {
  const LawyerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(lawyerWorkspaceProvider);
    return workspace.when(
      loading: () => const _LawyerState(
        title: 'Opening lawyer workspace…',
        loading: true,
      ),
      error: (error, _) => _LawyerState(
        title: 'Lawyer workspace unavailable',
        message: error.toString(),
        onRetry: () => ref.invalidate(lawyerWorkspaceProvider),
      ),
      data: (data) {
        if (data == null) {
          return const _LawyerState(
            title: 'Lawyer workspace not active',
            message:
                'This account is not an approved active lawyer account in SWIPESS.',
          );
        }
        return RoleControlCenter(
          eyebrow: 'Professional workspace',
          title: data.name,
          subtitle:
              'Your live legal operations, clients and earnings from the same SWIPESS backend used by the Lawyer portal.',
          statusLabel: data.isAvailable ? 'Available now' : 'Unavailable',
          actions: const [
            RoleDashboardAction(
              title: 'Legal services',
              subtitle: 'Review packages and client-facing services',
              icon: Icons.balance_rounded,
              path: AppPaths.legalServices,
            ),
            RoleDashboardAction(
              title: 'Contracts',
              subtitle: 'Open contracts and signature flows',
              icon: Icons.draw_rounded,
              path: AppPaths.clientContracts,
            ),
            RoleDashboardAction(
              title: 'Messages',
              subtitle: 'Continue conversations with clients',
              icon: Icons.forum_outlined,
              path: AppPaths.messages,
            ),
            RoleDashboardAction(
              title: 'Legal hub',
              subtitle: 'Preview the client legal experience',
              icon: Icons.shield_outlined,
              path: AppPaths.clientLegal,
            ),
            RoleDashboardAction(
              title: 'FAQ',
              subtitle: 'Review common client questions',
              icon: Icons.help_outline_rounded,
              path: AppPaths.faqClient,
            ),
            RoleDashboardAction(
              title: 'Main app',
              subtitle: 'Return to the SWIPESS dashboard',
              icon: Icons.home_outlined,
              path: AppPaths.clientDashboard,
            ),
          ],
          footer: _LawyerLivePanel(workspace: data),
        );
      },
    );
  }
}

class _LawyerLivePanel extends ConsumerWidget {
  const _LawyerLivePanel({required this.workspace});

  final LawyerWorkspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final saving = ref.watch(lawyerAvailabilitySavingProvider);
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LawyerIntakeScreen(),
                ),
              );
            },
            icon: const Icon(Icons.inbox_rounded),
            label: Text(
              workspace.availableRequests > 0
                  ? 'OPEN LEGAL INTAKE · ${workspace.availableRequests} NEW'
                  : 'OPEN LEGAL INTAKE',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(isLight),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Availability',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Controls whether clients can see you as available.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (saving)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: workspace.isAvailable,
                  onChanged: (value) async {
                    try {
                      await setLawyerAvailability(ref, value);
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not update availability: $error',
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            _Metric(
              label: 'Available intake',
              value: '${workspace.availableRequests}',
            ),
            _Metric(
              label: 'Pending requests',
              value: '${workspace.pendingRequests}',
            ),
            _Metric(label: 'Active clients', value: '${workspace.activeClients}'),
            _Metric(label: 'Open cases', value: '${workspace.openCases}'),
            _Metric(
              label: 'Appointments',
              value: '${workspace.upcomingAppointments}',
            ),
            _Metric(
              label: 'Earned · 30d',
              value: money.format(workspace.grossEarned30d),
            ),
            _Metric(
              label: 'Commission · 30d',
              value: money.format(workspace.commission30d),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoPanel(
          title: 'Professional profile',
          lines: [
            if (workspace.specialization != null)
              'Specialization · ${workspace.specialization}',
            if (workspace.barNumber != null)
              'Professional ID · ${workspace.barNumber}',
            'Commission rate · ${workspace.commissionRate.toStringAsFixed(1)}%',
            'Templates available · ${workspace.templatesAvailable}',
            'Service packages · ${workspace.servicePackagesAvailable}',
          ],
        ),
        if (workspace.requests.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Latest assigned requests',
            lines: [
              for (final request in workspace.requests.take(5))
                '${request['package_name'] ?? 'Legal request'} · ${request['status'] ?? 'pending'}',
            ],
          ),
        ],
        if (workspace.appointments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Upcoming appointments',
            lines: [
              for (final appointment in workspace.appointments.take(5))
                '${appointment['client_name'] ?? 'Client'} · ${_date(appointment['scheduled_at'])}',
            ],
          ),
        ],
      ],
    );
  }

  static String _date(Object? raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '');
    if (value == null) return 'scheduled';
    return DateFormat('MMM d, h:mm a').format(value.toLocal());
  }

  static BoxDecoration _panelDecoration(bool isLight) => BoxDecoration(
        color: isLight ? Colors.white.withAlpha(225) : AppTheme.dashGlassStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLight
              ? Colors.black.withAlpha(18)
              : Colors.white.withAlpha(30),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _LawyerLivePanel._panelDecoration(isLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _LawyerLivePanel._panelDecoration(isLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          for (final line in lines) ...[
            Text(
              line,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _LawyerState extends StatelessWidget {
  const _LawyerState({
    required this.title,
    this.message,
    this.loading = false,
    this.onRetry,
  });

  final String title;
  final String? message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: AppTheme.canvasFor(isLight: isLight),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                const Icon(Icons.gavel_rounded, size: 38),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
