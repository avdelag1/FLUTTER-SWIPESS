import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/role_control_center.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleControlCenter(
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
          title: 'Performance',
          subtitle: 'Review platform health and activity',
          icon: Icons.monitor_heart_rounded,
          path: AppPaths.adminPerformance,
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
    );
  }
}
