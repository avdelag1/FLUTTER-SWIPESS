import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/role_control_center.dart';

class LawyerDashboardScreen extends StatelessWidget {
  const LawyerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleControlCenter(
      eyebrow: 'Professional workspace',
      title: 'Lawyer dashboard',
      subtitle:
          'A focused workspace for legal services, contracts and client communication, using the same modern Swipess interface as the main app.',
      statusLabel: 'Lawyer workspace',
      actions: [
        RoleDashboardAction(
          title: 'Legal services',
          subtitle: 'View and manage service offerings',
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
          subtitle: 'Return to the Swipess dashboard',
          icon: Icons.home_outlined,
          path: AppPaths.clientDashboard,
        ),
      ],
    );
  }
}
