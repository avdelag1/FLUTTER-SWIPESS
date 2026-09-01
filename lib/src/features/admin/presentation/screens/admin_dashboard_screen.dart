import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/role_control_center.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShell(
      title: 'Admin dashboard',
      child: RoleControlCenter(
        eyebrow: 'Swipess operations',
        title: 'Admin dashboard',
        subtitle:
            'Manage platform content, performance, legal operations and high-level controls from one place.',
        statusLabel: 'Admin workspace',
        actions: [
          RoleDashboardAction(
            title: 'Events',
            subtitle: 'Review and manage event content',
            icon: Icons.event_rounded,
            path: AppPaths.adminEventos,
          ),
          RoleDashboardAction(
            title: 'Listing photos',
            subtitle: 'Manage listing imagery and media',
            icon: Icons.photo_library_rounded,
            path: AppPaths.adminPhotos,
          ),
          RoleDashboardAction(
            title: 'Category media',
            subtitle: 'Control discovery category visuals',
            icon: Icons.grid_view_rounded,
            path: AppPaths.adminCategoryPhotos,
          ),
          RoleDashboardAction(
            title: 'App text',
            subtitle: 'Edit dashboard AI prompts and live app copy',
            icon: Icons.text_fields_rounded,
            path: AppPaths.adminAppCopy,
          ),
          RoleDashboardAction(
            title: 'Performance',
            subtitle: 'Review platform health and activity',
            icon: Icons.monitor_heart_rounded,
            path: AppPaths.adminPerformance,
          ),
          RoleDashboardAction(
            title: 'Ambassadors',
            subtitle: 'Promoter performance & commissions',
            icon: Icons.campaign_rounded,
            path: AppPaths.adminAmbassadors,
          ),
          RoleDashboardAction(
            title: 'Legal admin',
            subtitle: 'Contracts, legal services and oversight',
            icon: Icons.gavel_rounded,
            path: AppPaths.legalAdminDashboard,
          ),
          RoleDashboardAction(
            title: 'Main app',
            subtitle: 'Return to the user dashboard',
            icon: Icons.apps_rounded,
            path: AppPaths.clientDashboard,
          ),
        ],
      ),
    );
  }
}
