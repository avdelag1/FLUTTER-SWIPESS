import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/role_control_center.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';

class LegalAdminDashboardScreen extends StatelessWidget {
  const LegalAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShell(
      title: 'Legal admin',
      child: RoleControlCenter(
        eyebrow: 'Legal operations',
        title: 'Legal admin',
        subtitle:
            'Centralize contracts, lawyer services, FAQs and client-facing legal resources without mixing them into the general admin area.',
        statusLabel: 'Legal workspace',
        actions: [
          RoleDashboardAction(
            title: 'Contracts',
            subtitle: 'Review contract flows and signatures',
            icon: Icons.description_rounded,
            path: AppPaths.clientContracts,
          ),
          RoleDashboardAction(
            title: 'Lawyer services',
            subtitle: 'Open the legal services marketplace',
            icon: Icons.balance_rounded,
            path: AppPaths.legalServices,
          ),
          RoleDashboardAction(
            title: 'Lawyer dashboard',
            subtitle: 'Open the lawyer-facing workspace',
            icon: Icons.work_outline_rounded,
            path: AppPaths.lawyerDashboard,
          ),
          RoleDashboardAction(
            title: 'Client legal hub',
            subtitle: 'Review the user-facing legal experience',
            icon: Icons.shield_outlined,
            path: AppPaths.legal,
          ),
          RoleDashboardAction(
            title: 'Client FAQ',
            subtitle: 'Check client legal help content',
            icon: Icons.help_outline_rounded,
            path: AppPaths.faqClient,
          ),
          RoleDashboardAction(
            title: 'Owner FAQ',
            subtitle: 'Check business and owner help content',
            icon: Icons.business_center_outlined,
            path: AppPaths.faqOwner,
          ),
        ],
      ),
    );
  }
}
