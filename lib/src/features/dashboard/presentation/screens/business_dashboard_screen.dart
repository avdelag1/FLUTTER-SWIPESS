import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/role_control_center.dart';

class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleControlCenter(
      eyebrow: 'Business workspace',
      title: 'Business dashboard',
      subtitle: 'Manage listings, interested clients, messages and business settings from one clean control center.',
      statusLabel: 'Business workspace',
      actions: [
        RoleDashboardAction(
          title: 'My listings',
          subtitle: 'Manage properties and active listings',
          icon: Icons.storefront_outlined,
          path: AppPaths.ownerListings,
        ),
        RoleDashboardAction(
          title: 'Add listing',
          subtitle: 'Create a new listing quickly',
          icon: Icons.add_business_rounded,
          path: AppPaths.ownerListingsNew,
        ),
        RoleDashboardAction(
          title: 'Interested clients',
          subtitle: 'See people engaging with your listings',
          icon: Icons.people_alt_outlined,
          path: AppPaths.ownerInterestedClients,
        ),
        RoleDashboardAction(
          title: 'Messages',
          subtitle: 'Talk directly with potential clients',
          icon: Icons.forum_outlined,
          path: AppPaths.messages,
        ),
        RoleDashboardAction(
          title: 'Legal services',
          subtitle: 'Contracts and professional legal support',
          icon: Icons.gavel_outlined,
          path: AppPaths.ownerLegalServices,
        ),
        RoleDashboardAction(
          title: 'Business settings',
          subtitle: 'Security, preferences and account controls',
          icon: Icons.tune_rounded,
          path: AppPaths.ownerSettings,
        ),
      ],
    );
  }
}
