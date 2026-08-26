import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/magic_ai_profile_sheet.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/memory_drawer.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/escrow/presentation/screens/escrow_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_favorites_screen.dart';
import 'package:flutter_swipes/src/features/gamification/presentation/widgets/engagement_reward_card.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/local_intel_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/price_tracker_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/faq_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/lawyer_services_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/legal_hub_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/owner_interested_clients_screen.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/about_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/maintenance_requests_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/perks_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/saved_searches_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/vap_validate_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/invite_friends_section.dart';
import 'package:flutter_swipes/src/features/roommates/presentation/screens/roommate_matching_screen.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/screens/worker_discovery_screen.dart';
import 'package:flutter_swipes/src/features/video_tours/presentation/screens/video_tours_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The deep account/tooling area that existed before the social profile refresh.
/// It intentionally lives after the listing gallery so the top of Profile stays
/// visual and Instagram-like while every previous management entry remains easy
/// to find.
class ProfileToolsHub extends ConsumerWidget {
  const ProfileToolsHub({
    super.key,
    required this.role,
    required this.profileId,
    required this.profileName,
  });

  final String? role;
  final String profileId;
  final String profileName;

  static const _pink = Color(0xFFEB4898);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text(
          'ACCOUNT & TOOLS',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Everything from the original profile is still here — just moved below your listings.',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white60,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.05,
          children: [
            _QuickTool(
              icon: Icons.auto_awesome_rounded,
              title: 'Magic AI Profile',
              onTap: () => showMagicAiProfileSheet(context),
            ),
            _QuickTool(
              icon: Icons.workspace_premium_rounded,
              title: 'Premium',
              onTap: () => context.push(AppPaths.subscriptionPackages),
            ),
            _QuickTool(
              icon: Icons.toll_rounded,
              title: 'Tokens',
              onTap: () => showGlassModal(
                context: context,
                builder: (_) => const TokensModal(),
              ),
            ),
            _QuickTool(
              icon: Icons.badge_outlined,
              title: 'Local ID / PEARL',
              onTap: () => context.push(AppPaths.clientVapId),
            ),
            _QuickTool(
              icon: Icons.campaign_rounded,
              title: 'Promote Event',
              onTap: () => context.push(AppPaths.clientAdvertise),
            ),
            _QuickTool(
              icon: Icons.people_alt_outlined,
              title: 'Seeker Requests',
              onTap: () => context.push(AppPaths.exploreSeekers),
            ),
            _QuickTool(
              icon: Icons.settings_rounded,
              title: 'Settings',
              onTap: () => context.push(
                role == 'owner'
                    ? AppPaths.ownerSettings
                    : AppPaths.clientSettings,
              ),
            ),
            _QuickTool(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Send Feedback',
              onTap: () => _showFeedback(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF171B22),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _ToolRow(
                icon: Icons.how_to_reg_outlined,
                title: 'Interested clients',
                subtitle: 'People engaging with your listings',
                onTap: () => _push(
                  context,
                  const OwnerInterestedClientsScreen(),
                  root: true,
                ),
              ),
              _ToolRow(
                icon: Icons.event_available_rounded,
                title: 'Saved events',
                subtitle: 'Your hearted events',
                onTap: () => _push(context, const EventFavoritesScreen()),
              ),
              _ToolRow(
                icon: Icons.psychology_rounded,
                title: 'AI Memory / Brain',
                subtitle: 'Manage AI memory and context',
                onTap: () => showMemoryDrawer(context),
              ),
              _ToolRow(
                icon: Icons.bookmark_border_rounded,
                title: 'Saved searches',
                subtitle: 'Return to searches you saved',
                onTap: () => _push(context, const SavedSearchesScreen()),
              ),
              _ToolRow(
                icon: Icons.notifications_none_rounded,
                title: unread > 0 ? 'Notifications ($unread)' : 'Notifications',
                subtitle: 'Alerts, likes, messages and updates',
                onTap: () => _push(context, const NotificationsScreen()),
              ),
              _ToolRow(
                icon: Icons.folder_outlined,
                title: 'Document vault',
                subtitle: 'IDs, contracts and verification files',
                onTap: () => _push(context, const DocumentVaultScreen()),
              ),
              _ToolRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Escrow',
                subtitle: 'Payment and transaction workspace',
                onTap: () => _push(
                  context,
                  const EscrowDashboardScreen(),
                  root: true,
                ),
              ),
              _ToolRow(
                icon: Icons.gavel_rounded,
                title: 'Legal hub',
                subtitle: 'Legal help and resources',
                onTap: () => _push(context, const LegalHubScreen()),
              ),
              _ToolRow(
                icon: Icons.balance_rounded,
                title: 'Lawyer services',
                subtitle: 'Find and manage legal support',
                onTap: () => _push(context, const LawyerServicesScreen()),
              ),
              _ToolRow(
                icon: Icons.work_outline_rounded,
                title: 'Worker discovery',
                subtitle: 'Find professionals and services',
                onTap: () => _push(
                  context,
                  const WorkerDiscoveryScreen(),
                  root: true,
                ),
              ),
              _ToolRow(
                icon: Icons.card_giftcard_rounded,
                title: 'Resident perks',
                subtitle: 'Local benefits and privileges',
                onTap: () => _push(context, const PerksScreen()),
              ),
              _ToolRow(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Validate PEARL',
                subtitle: 'Validate a resident/local identity',
                onTap: () => _push(context, const VapValidateScreen()),
              ),
              _ToolRow(
                icon: Icons.videocam_outlined,
                title: 'Video tours',
                subtitle: 'Manage and browse video experiences',
                onTap: () => _push(context, const VideoToursScreen()),
              ),
              _ToolRow(
                icon: Icons.people_outline_rounded,
                title: 'Roommates',
                subtitle: 'Roommate matching and discovery',
                onTap: () => _push(
                  context,
                  const RoommateMatchingScreen(),
                  root: true,
                ),
              ),
              _ToolRow(
                icon: Icons.newspaper_outlined,
                title: 'Local intel',
                subtitle: 'Useful local information',
                onTap: () => _push(context, const LocalIntelScreen()),
              ),
              _ToolRow(
                icon: Icons.trending_up_rounded,
                title: 'Market prices',
                subtitle: 'Track prices and market movement',
                onTap: () => _push(context, const PriceTrackerScreen()),
              ),
              _ToolRow(
                icon: Icons.handyman_outlined,
                title: 'Maintenance',
                subtitle: 'Maintenance requests and follow-up',
                onTap: () => _push(
                  context,
                  const MaintenanceRequestsScreen(),
                  root: true,
                ),
              ),
              _ToolRow(
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQ',
                subtitle: 'Answers and support',
                onTap: () => _push(context, const FAQScreen()),
              ),
              _ToolRow(
                icon: Icons.info_outline_rounded,
                title: 'About Swipess',
                subtitle: 'App information and details',
                onTap: () => _push(context, const AboutScreen()),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF171B22),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const EngagementRewardCard(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171B22),
            borderRadius: BorderRadius.circular(20),
          ),
          child: InviteFriendsSection(
            profileId: profileId,
            profileName: profileName,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'LANGUAGE',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            _LanguageChip(
              label: 'EN',
              active: !ref.watch(appLocaleProvider).isEs,
              onTap: () => ref.read(appLocaleProvider.notifier).setCode('en'),
            ),
            const SizedBox(width: 8),
            _LanguageChip(
              label: 'ES',
              active: ref.watch(appLocaleProvider).isEs,
              onTap: () => ref.read(appLocaleProvider.notifier).setCode('es'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              AppHaptics.medium();
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppPaths.welcome);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _push(
    BuildContext context,
    Widget screen, {
    bool root = false,
  }) async {
    AppHaptics.light();
    await Navigator.of(context, rootNavigator: root).push<void>(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> _showFeedback(BuildContext context) async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send feedback'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Tell us what should be better…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    final message = controller.text.trim();
    controller.dispose();
    if (submitted != true || message.isEmpty || !context.mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send feedback.')),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('support_tickets').insert({
        'user_id': user.id,
        'subject': 'Profile feedback',
        'message': message,
        'category': 'feedback_experience',
        'priority': 'low',
        'user_email': user.email ?? '',
        'user_role':
            user.appMetadata['role']?.toString() ??
            user.userMetadata?['role']?.toString() ??
            'client',
        'source': 'profile_tools',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback sent — thank you.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send feedback.')),
        );
      }
    }
  }
}

class _QuickTool extends StatelessWidget {
  const _QuickTool({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B1F27),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ProfileToolsHub._pink.withAlpha(36),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: ProfileToolsHub._pink, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white38,
          ),
        ),
        if (!last)
          const Divider(height: 1, indent: 66, endIndent: 14, color: Colors.white10),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.brandPrimary.withAlpha(48) : const Color(0xFF222833),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppTheme.brandPrimary : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
