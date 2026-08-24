import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/role_control_center.dart';
import 'package:flutter_swipes/src/features/business/domain/business_workspace.dart';
import 'package:flutter_swipes/src/features/business/presentation/providers/business_workspace_provider.dart';
import 'package:intl/intl.dart';

class PartnerBusinessDashboardScreen extends ConsumerWidget {
  const PartnerBusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(businessWorkspaceProvider);
    return workspace.when(
      loading: () => const _WorkspaceState(
        icon: Icons.storefront_rounded,
        title: 'Opening business workspace…',
        loading: true,
      ),
      error: (error, _) => _WorkspaceState(
        icon: Icons.lock_outline_rounded,
        title: 'Business workspace unavailable',
        message: error.toString(),
        onRetry: () => ref.invalidate(businessWorkspaceProvider),
      ),
      data: (data) {
        if (data == null) {
          return const _WorkspaceState(
            icon: Icons.lock_outline_rounded,
            title: 'Business workspace not active',
            message:
                'This account is not attached to an approved active SWIPESS partner business.',
          );
        }
        return RoleControlCenter(
          eyebrow: 'Partner business',
          title: data.name,
          subtitle:
              'Live partner operations from the same SWIPESS backend used by the Business portal.',
          statusLabel: 'Business active',
          actions: const [
            RoleDashboardAction(
              title: 'Scan member',
              subtitle: 'Validate Local ID, log visits and apply discounts',
              icon: Icons.qr_code_scanner_rounded,
              path: AppPaths.businessScan,
            ),
            RoleDashboardAction(
              title: 'Messages',
              subtitle: 'Continue customer conversations',
              icon: Icons.forum_outlined,
              path: AppPaths.messages,
            ),
            RoleDashboardAction(
              title: 'Perks & local ID',
              subtitle: 'Preview the member benefit experience',
              icon: Icons.workspace_premium_outlined,
              path: AppPaths.clientPerks,
            ),
            RoleDashboardAction(
              title: 'Business settings',
              subtitle: 'Account, security and preferences',
              icon: Icons.tune_rounded,
              path: AppPaths.ownerSettings,
            ),
            RoleDashboardAction(
              title: 'Main app',
              subtitle: 'Return to the SWIPESS marketplace',
              icon: Icons.apps_rounded,
              path: AppPaths.clientDashboard,
            ),
          ],
          footer: _BusinessLivePanel(workspace: data),
        );
      },
    );
  }
}

class _BusinessLivePanel extends StatelessWidget {
  const _BusinessLivePanel({required this.workspace});

  final BusinessWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'LIVE OPERATIONS'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            _MetricCard(label: 'Scans today', value: '${workspace.scansToday}'),
            _MetricCard(label: 'Customers', value: '${workspace.customersTotal}'),
            _MetricCard(
              label: 'Sales · 30d',
              value: money.format(workspace.grossSales30d),
            ),
            _MetricCard(
              label: 'Transactions · 30d',
              value: '${workspace.transactions30d}',
            ),
            _MetricCard(
              label: 'Discounts · 30d',
              value: money.format(workspace.discounts30d),
            ),
            _MetricCard(
              label: 'Commission · 30d',
              value: money.format(workspace.commission30d),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoPanel(
          isLight: isLight,
          title: 'Partner configuration',
          lines: [
            if (workspace.type != null) 'Type · ${workspace.type}',
            if (workspace.address != null) workspace.address!,
            'Commission rate · ${workspace.commissionRate.toStringAsFixed(1)}%',
            'Active promos · ${workspace.activePromos}',
            'Total scans · ${workspace.scansTotal}',
          ],
        ),
        if (workspace.recentScans.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoPanel(
            isLight: isLight,
            title: 'Recent member scans',
            lines: [
              for (final scan in workspace.recentScans.take(5))
                '${scan['customer_name'] ?? 'SWIPESS member'} · ${_date(scan['scan_timestamp'])}',
            ],
          ),
        ],
        if (workspace.recentTransactions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoPanel(
            isLight: isLight,
            title: 'Recent transactions',
            lines: [
              for (final tx in workspace.recentTransactions.take(5))
                '${tx['customer_name'] ?? 'Customer'} · ${money.format((tx['total_amount'] as num?)?.toDouble() ?? 0)}',
            ],
          ),
        ],
      ],
    );
  }

  static String _date(Object? raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '');
    if (value == null) return 'recent';
    return DateFormat('MMM d, h:mm a').format(value.toLocal());
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.7,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withAlpha(225) : AppTheme.dashGlassStrong,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLight
              ? Colors.black.withAlpha(18)
              : Colors.white.withAlpha(30),
        ),
      ),
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
  const _InfoPanel({
    required this.isLight,
    required this.title,
    required this.lines,
  });

  final bool isLight;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withAlpha(225) : AppTheme.dashGlassStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLight
              ? Colors.black.withAlpha(18)
              : Colors.white.withAlpha(30),
        ),
      ),
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

class _WorkspaceState extends StatelessWidget {
  const _WorkspaceState({
    required this.icon,
    required this.title,
    this.message,
    this.loading = false,
    this.onRetry,
  });

  final IconData icon;
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
                Icon(icon, size: 38),
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
