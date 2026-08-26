import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
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
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
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

const _profileAccentPink = Color(0xFFEB4898);

/// Profile continuation after the social/listings gallery.
/// The order is intentional: share + earn first, virtual ID next, then compact
/// colorful shortcuts, followed by the complete deeper account toolset.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        const _SectionHeading(
          title: 'SHARE & EARN',
          subtitle: 'Grow your profile and earn more Swipess tokens.',
        ),
        const SizedBox(height: 12),
        _AccentPanel(
          accent: const Color(0xFFFFC043),
          child: const EngagementRewardCard(),
        ),
        const SizedBox(height: 10),
        _AccentPanel(
          accent: const Color(0xFF57D9FF),
          child: InviteFriendsSection(
            profileId: profileId,
            profileName: profileName,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeading(
          title: 'YOUR BAPIT / PEARL',
          subtitle: 'Your virtual local ID stays visual and one tap away.',
        ),
        const SizedBox(height: 12),
        _VirtualIdPreview(
          profileId: profileId,
          profileName: profileName,
          onTap: () => context.push(AppPaths.clientVapId),
        ),
        const SizedBox(height: 24),
        const _SectionHeading(
          title: 'QUICK ACCESS',
          subtitle: 'Small shortcuts for the things you use most.',
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.12,
          children: [
            _QuickTool(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Profile',
              accent: const Color(0xFFA66CFF),
              onTap: () => showMagicAiProfileSheet(context),
            ),
            _QuickTool(
              icon: Icons.workspace_premium_rounded,
              title: 'Premium',
              accent: const Color(0xFFFFC043),
              onTap: () => context.push(AppPaths.subscriptionPackages),
            ),
            _QuickTool(
              icon: Icons.toll_rounded,
              title: 'Tokens',
              accent: const Color(0xFF35D07F),
              onTap: () => showGlassModal(
                context: context,
                builder: (_) => const TokensModal(),
              ),
            ),
            _QuickTool(
              icon: Icons.campaign_rounded,
              title: 'Promote',
              accent: const Color(0xFFFF6B6B),
              onTap: () => context.push(AppPaths.clientAdvertise),
            ),
            _QuickTool(
              icon: Icons.people_alt_outlined,
              title: 'Requests',
              accent: const Color(0xFF57D9FF),
              onTap: () => context.push(AppPaths.exploreSeekers),
            ),
            _QuickTool(
              icon: Icons.settings_rounded,
              title: 'Settings',
              accent: _profileAccentPink,
              onTap: () => context.push(
                role == 'owner'
                    ? AppPaths.ownerSettings
                    : AppPaths.clientSettings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const _SectionHeading(
          title: 'ACCOUNT & TOOLS',
          subtitle: 'Everything else is still here, organized and easier to scan.',
        ),
        const SizedBox(height: 12),
        _ToolGroup(
          title: 'ACTIVITY',
          children: [
            _ToolRow(
              icon: Icons.how_to_reg_outlined,
              accent: const Color(0xFFFF6B6B),
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
              accent: _profileAccentPink,
              title: 'Saved events',
              subtitle: 'Your hearted events',
              onTap: () => _push(context, const EventFavoritesScreen()),
            ),
            _ToolRow(
              icon: Icons.psychology_rounded,
              accent: const Color(0xFFA66CFF),
              title: 'AI Memory / Brain',
              subtitle: 'Manage AI memory and context',
              onTap: () => showMemoryDrawer(context),
            ),
            _ToolRow(
              icon: Icons.bookmark_border_rounded,
              accent: const Color(0xFF57D9FF),
              title: 'Saved searches',
              subtitle: 'Return to searches you saved',
              onTap: () => _push(context, const SavedSearchesScreen()),
            ),
            _ToolRow(
              icon: Icons.notifications_none_rounded,
              accent: const Color(0xFFFFC043),
              title: unread > 0 ? 'Notifications ($unread)' : 'Notifications',
              subtitle: 'Alerts, likes, messages and updates',
              onTap: () => _push(context, const NotificationsScreen()),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ToolGroup(
          title: 'DOCUMENTS & SUPPORT',
          children: [
            _ToolRow(
              icon: Icons.folder_outlined,
              accent: const Color(0xFF57D9FF),
              title: 'Document vault',
              subtitle: 'IDs, contracts and verification files',
              onTap: () => _push(context, const DocumentVaultScreen()),
            ),
            _ToolRow(
              icon: Icons.account_balance_wallet_outlined,
              accent: const Color(0xFF35D07F),
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
              accent: const Color(0xFFA66CFF),
              title: 'Legal hub',
              subtitle: 'Legal help and resources',
              onTap: () => _push(context, const LegalHubScreen()),
            ),
            _ToolRow(
              icon: Icons.balance_rounded,
              accent: const Color(0xFFFFC043),
              title: 'Lawyer services',
              subtitle: 'Find and manage legal support',
              onTap: () => _push(context, const LawyerServicesScreen()),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ToolGroup(
          title: 'DISCOVER & MANAGE',
          children: [
            _ToolRow(
              icon: Icons.work_outline_rounded,
              accent: const Color(0xFF57D9FF),
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
              accent: _profileAccentPink,
              title: 'Resident perks',
              subtitle: 'Local benefits and privileges',
              onTap: () => _push(context, const PerksScreen()),
            ),
            _ToolRow(
              icon: Icons.qr_code_scanner_rounded,
              accent: const Color(0xFF35D07F),
              title: 'Validate PEARL',
              subtitle: 'Validate a resident/local identity',
              onTap: () => _push(context, const VapValidateScreen()),
            ),
            _ToolRow(
              icon: Icons.videocam_outlined,
              accent: const Color(0xFFFF6B6B),
              title: 'Video tours',
              subtitle: 'Manage and browse video experiences',
              onTap: () => _push(context, const VideoToursScreen()),
            ),
            _ToolRow(
              icon: Icons.people_outline_rounded,
              accent: const Color(0xFFA66CFF),
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
              accent: const Color(0xFF57D9FF),
              title: 'Local intel',
              subtitle: 'Useful local information',
              onTap: () => _push(context, const LocalIntelScreen()),
            ),
            _ToolRow(
              icon: Icons.trending_up_rounded,
              accent: const Color(0xFF35D07F),
              title: 'Market prices',
              subtitle: 'Track prices and market movement',
              onTap: () => _push(context, const PriceTrackerScreen()),
            ),
            _ToolRow(
              icon: Icons.handyman_outlined,
              accent: const Color(0xFFFFC043),
              title: 'Maintenance',
              subtitle: 'Maintenance requests and follow-up',
              onTap: () => _push(
                context,
                const MaintenanceRequestsScreen(),
                root: true,
              ),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ToolGroup(
          title: 'HELP & APP',
          children: [
            _ToolRow(
              icon: Icons.chat_bubble_outline_rounded,
              accent: _profileAccentPink,
              title: 'Send feedback',
              subtitle: 'Tell us what should be better',
              onTap: () => _showFeedback(context),
            ),
            _ToolRow(
              icon: Icons.help_outline_rounded,
              accent: const Color(0xFF57D9FF),
              title: 'Help & FAQ',
              subtitle: 'Answers and support',
              onTap: () => _push(context, const FAQScreen()),
            ),
            _ToolRow(
              icon: Icons.info_outline_rounded,
              accent: const Color(0xFFA66CFF),
              title: 'About Swipess',
              subtitle: 'App information and details',
              onTap: () => _push(context, const AboutScreen()),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'LANGUAGE',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.35,
              ),
            ),
            const Spacer(),
            _LanguageChip(
              label: 'EN',
              active: !ref.watch(appLocaleProvider).isEs,
              onTap: () => ref.read(appLocaleProvider.notifier).setCode('en'),
            ),
            const SizedBox(width: 7),
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
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () async {
              AppHaptics.medium();
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppPaths.welcome);
            },
            icon: const Icon(Icons.logout_rounded, size: 17),
            label: Text(
              'Sign out',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AccentPanel extends StatelessWidget {
  const _AccentPanel({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withAlpha(50), const Color(0xFF171B22)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(85)),
      ),
      child: child,
    );
  }
}

class _VirtualIdPreview extends ConsumerWidget {
  const _VirtualIdPreview({
    required this.profileId,
    required this.profileName,
    required this.onTap,
  });

  final String profileId;
  final String profileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vapIdProvider);
    final card = async.value;
    final displayName = card?.displayName ??
        (profileName.trim().isEmpty ? 'Resident' : profileName.trim());
    final occupation = card?.occupation?.trim();
    final location = card?.locationLabel ?? 'Swipess local member';
    final photo = card?.displayPhotoUrl;
    final rawId = profileId.trim();
    final idLength = rawId.length < 8 ? rawId.length : 8;
    final shortId = rawId.isEmpty
        ? 'SWIPESS'
        : rawId.substring(0, idLength).toUpperCase();

    return Semantics(
      button: true,
      label: 'Open BAPIT PEARL virtual local ID',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF8F7F3), Color(0xFFE7E5DF)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(70),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 15,
                      color: _profileAccentPink,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SWIPESS LOCAL ID',
                      style: GoogleFonts.plusJakartaSans(
                        color: _profileAccentPink,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'BAPIT · PEARL',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 94,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7D5CF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: photo == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.black38,
                              size: 40,
                            )
                          : Image.network(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person_rounded,
                                color: Colors.black38,
                                size: 40,
                              ),
                            ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF111111),
                              fontSize: 19,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.55,
                            ),
                          ),
                          if (occupation != null && occupation.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              occupation.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: _profileAccentPink,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.black54,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ID NX-$shortId',
                            style: GoogleFonts.robotoMono(
                              color: Colors.black45,
                              fontSize: 8.5,
                              letterSpacing: .55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.black,
                        size: 39,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      async.isLoading ? 'LOADING ID…' : 'TAP TO OPEN FULL CARD',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black54,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.black54,
                      size: 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTool extends StatelessWidget {
  const _QuickTool({
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withAlpha(92), accent.withAlpha(34)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withAlpha(105)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withAlpha(55),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 9.5,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolGroup extends StatelessWidget {
  const _ToolGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF15181F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 4),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: Colors.white10, width: .7),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withAlpha(42),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white30,
              size: 19,
            ),
          ],
        ),
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _profileAccentPink : Colors.white10,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
