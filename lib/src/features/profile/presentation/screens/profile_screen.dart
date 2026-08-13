import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/profile_camera_screen.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/magic_ai_profile_sheet.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/memory_drawer.dart';
import 'package:flutter_swipes/src/features/escrow/presentation/screens/escrow_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_favorites_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/local_intel_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/price_tracker_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/faq_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/lawyer_services_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/legal_hub_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/who_liked_you_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/owner_interested_clients_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/who_liked_you_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_swipes/src/features/profile/domain/daily_quest.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/invite_friends_dialog.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/about_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/advertise_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/maintenance_requests_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/owner_properties_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/perks_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/saved_searches_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/settings_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/vap_validate_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/holographic_id_card.dart';
import 'package:flutter_swipes/src/features/roommates/presentation/screens/roommate_matching_screen.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/screens/worker_discovery_screen.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/subscription_packages_screen.dart';
import 'package:flutter_swipes/src/features/video_tours/presentation/screens/video_tours_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Capacitor ClientProfile — identity, quests, action grid, share, feedback, PEARL.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _questsOpen = false;
  bool _moreOpen = false;
  String? _feedbackCategory;
  final _feedbackCtrl = TextEditingController();
  bool _feedbackDone = false;
  bool _feedbackSending = false;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(currentProfileProvider);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _orb(AppTheme.brandPrimary.withAlpha(40), 260),
          ),
          Positioned(
            top: 280,
            left: -100,
            child: _orb(const Color(0xFF06B6D4).withAlpha(28), 220),
          ),
          async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(currentProfileProvider),
                child: const Text('Could not load profile — retry'),
              ),
            ),
            data: (profile) {
              final name = profile?.name ?? 'Identity';
              final email = profile?.email ??
                  Supabase.instance.client.auth.currentUser?.email ??
                  '';
              final avatar = profile?.avatarUrl;
              final completion = profile?.completionPercent ?? 0;
              final likes = ref.watch(whoLikedYouProvider).value?.length ?? 0;
              final chats = ref.watch(conversationsProvider).value?.length ?? 0;

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, top + 72, 20, 140),
                children: [
                  // Identity core
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 132,
                              height: 132,
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                                ),
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF080C14),
                                ),
                                child: ClipOval(
                                  child: avatar != null
                                      ? Image.network(
                                          avatar,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.person_rounded,
                                                  color: Colors.white24, size: 56),
                                        )
                                      : const Icon(Icons.person_rounded,
                                          color: Colors.white24, size: 56),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  final url = await Navigator.of(context)
                                      .push<String>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ProfileCameraScreen(
                                        mode: ProfileCameraMode.selfie,
                                      ),
                                    ),
                                  );
                                  if (url != null) {
                                    ref.invalidate(currentProfileProvider);
                                  }
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF4D00), Color(0xFFFF6B00)],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF0A0A0D),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          name.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -1.2,
                            height: 1,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            email.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // HUD stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.thumb_up_alt_outlined,
                          iconColor: const Color(0xFFFF4D00),
                          value: likes,
                          label: 'Likes',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WhoLikedYouScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.auto_awesome_rounded,
                          iconColor: const Color(0xFFEB4898),
                          value: likes,
                          label: 'Total Matches',
                          onTap: () {
                            context.go(AppPaths.clientLikedProperties);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: const Color(0xFFFF8C42),
                          value: chats,
                          label: 'Messages',
                          onTap: () {
                            context.go(AppPaths.messages);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Daily Quests
                  _Panel(
                    child: _DailyQuests(
                      expanded: _questsOpen,
                      onToggle: () => setState(() => _questsOpen = !_questsOpen),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Magic AI Profile
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      showMagicAiProfileSheet(context);
                    },
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withAlpha(70),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Magic AI Profile',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 2.2,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: [
                      _ActionTile(
                        label: 'Edit Profile',
                        icon: Icons.person_rounded,
                        colors: const [Color(0xFFFF4D00), Color(0xFFEB4898)],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ),
                      ),
                      _ActionTile(
                        label: 'Promote Event',
                        icon: Icons.campaign_rounded,
                        colors: const [Color(0xFFFF4D00), Color(0xFFFF8C00)],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdvertiseScreen(),
                          ),
                        ),
                      ),
                      _ActionTile(
                        label: 'Seekers',
                        icon: Icons.people_rounded,
                        colors: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        onTap: () {
                          context.go(AppPaths.exploreSeekers);
                        },
                      ),
                      _ActionTile(
                        label: 'Tokens',
                        icon: Icons.toll_rounded,
                        colors: const [Color(0xFF10B981), Color(0xFF06B6D4)],
                        onTap: () => showGlassModal(
                          context: context,
                          builder: (_) => const TokensModal(),
                        ),
                      ),
                      _ActionTile(
                        label: 'Settings',
                        icon: Icons.settings_rounded,
                        colors: const [Color(0xFF64748B), Color(0xFF334155)],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                      _ActionTile(
                        label: 'Sign Out',
                        icon: Icons.logout_rounded,
                        colors: const [Color(0xFFEF4444), Color(0xFF991B1B)],
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          await Supabase.instance.client.auth.signOut();
                          if (context.mounted) context.go(AppPaths.auth);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionPackagesScreen(),
                        ),
                      );
                    },
                    child: Container(
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            'Premium',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 2.4,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Share & Earn
                  _Panel(
                    child: _ShareEarn(
                      profileId: profile?.userId ??
                          Supabase.instance.client.auth.currentUser?.id ??
                          '',
                      profileName: name,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Feedback
                  _Panel(
                    padding: const EdgeInsets.all(18),
                    child: _feedbackDone
                        ? Column(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF10B981), size: 44),
                              const SizedBox(height: 10),
                              Text(
                                'Thank you!',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your feedback helps us build a better Swipess.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _feedbackDone = false;
                                  _feedbackCtrl.clear();
                                  _feedbackCategory = null;
                                }),
                                child: const Text('Send another'),
                              ),
                            ],
                          )
                        : _FeedbackForm(
                            category: _feedbackCategory,
                            controller: _feedbackCtrl,
                            sending: _feedbackSending,
                            onCategory: (c) =>
                                setState(() => _feedbackCategory = c),
                            onSubmit: _submitFeedback,
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Holographic Identity Vault
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.go(AppPaths.clientVapId);
                    },
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              'Sync Protocol',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        HolographicIDCard(
                          name: name,
                          idNumber:
                              'SWS-${(profile?.userId ?? '00000000').padRight(8).substring(0, 8).toUpperCase()}',
                          avatarUrl: avatar,
                          occupation: profile?.role ?? 'Client',
                          location: profile?.city ?? '',
                          years: profile?.age?.toString() ?? '',
                          bio: profile?.bio ?? '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Seeker requests teaser
                  GestureDetector(
                    onTap: () {
                      context.go(AppPaths.exploreSeekers);
                    },
                    child: _Panel(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.campaign_outlined,
                                color: Color(0xFF60A5FA)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Seeker Requests',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  'Post what professional you need',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white38),
                        ],
                      ),
                    ),
                  ),

                  if (completion < 100) ...[
                    const SizedBox(height: 14),
                    _Panel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  color: Color(0xFFEB4898), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Profile Completeness',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$completion%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: completion / 100,
                              minHeight: 10,
                              backgroundColor: Colors.white.withAlpha(18),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFFF4D00),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  _Panel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEB4898),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x80EB4898),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Global Activity',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Likes, matches, and messages from your network show up here.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Language row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LangChip(
                        label: 'EN',
                        active: !ref.watch(appLocaleProvider).isEs,
                        onTap: () => ref
                            .read(appLocaleProvider.notifier)
                            .setCode('en'),
                      ),
                      const SizedBox(width: 8),
                      _LangChip(
                        label: 'ES',
                        active: ref.watch(appLocaleProvider).isEs,
                        onTap: () => ref
                            .read(appLocaleProvider.notifier)
                            .setCode('es'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // More tools (Flutter extras)
                  GestureDetector(
                    onTap: () => setState(() => _moreOpen = !_moreOpen),
                    child: Row(
                      children: [
                        Text(
                          'MORE TOOLS',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _moreOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ),
                  if (_moreOpen) ...[
                    const SizedBox(height: 12),
                    _MoreToolsGrid(unread: ref.watch(unreadNotificationsProvider).value ?? 0),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Swipess v1.0.0',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white24,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    final msg = _feedbackCtrl.text.trim();
    final cat = _feedbackCategory;
    if (msg.isEmpty || cat == null) return;
    setState(() => _feedbackSending = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('user_feedback').insert({
        'user_id': user?.id,
        'email': user?.email,
        'category': cat,
        'message': msg,
      });
    } catch (_) {
      // Best-effort like Capacitor — still show thank you.
    }
    if (!mounted) return;
    setState(() {
      _feedbackSending = false;
      _feedbackDone = true;
    });
  }

  Widget _orb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: const SizedBox(),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(28)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withAlpha(28)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: colors),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyQuests extends ConsumerWidget {
  const _DailyQuests({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyQuestsProvider);
    final board = async.maybeWhen(
      data: (value) => value,
      orElse: () => const DailyQuestBoard(),
    );
    final points = board.points;
    final quests = List<DailyQuest>.from(board.quests)
      ..sort((a, b) {
        if (a.claimed != b.claimed) return a.claimed ? 1 : -1;
        if (a.completed != b.completed) return a.completed ? -1 : 1;
        return 0;
      });

    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.brandPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                capCopy(ref, 'Daily Quests', 'Misiones diarias'),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withAlpha(35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.brandPrimary.withAlpha(80)),
                ),
                child: Text(
                  async.isLoading
                      ? '…'
                      : '$points / ${DailyQuestBoard.pointsNeeded}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white54,
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: board.progressPercent,
              minHeight: 8,
              backgroundColor: const Color(0x22FFFFFF),
              valueColor: const AlwaysStoppedAnimation(AppTheme.brandPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            capCopy(
              ref,
              'Earn ${DailyQuestBoard.pointsNeeded} points to unlock a free token!',
              '¡Gana ${DailyQuestBoard.pointsNeeded} puntos para un token gratis!',
            ),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (async.hasError)
            TextButton(
              onPressed: () => ref.invalidate(dailyQuestsProvider),
              child: const Text('Could not load quests — retry'),
            )
          else if (quests.isEmpty)
            Text(
              capCopy(
                ref,
                'Sign in to unlock daily quests.',
                'Inicia sesión para desbloquear misiones.',
              ),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 12,
              ),
            )
          else
            for (final q in quests)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        q.claimed
                            ? Icons.check_circle_rounded
                            : q.id == 'login'
                                ? Icons.bolt_rounded
                                : q.id == 'swipe'
                                    ? Icons.gps_fixed_rounded
                                    : Icons.auto_awesome_rounded,
                        color: q.claimed
                            ? const Color(0xFF10B981)
                            : q.completed
                                ? AppTheme.brandPrimary
                                : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.title,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                decoration: q.claimed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (!q.claimed)
                              Text(
                                '${q.progress}/${q.goal}  ·  +${q.points} pts',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (q.completed && !q.claimed)
                        TextButton(
                          onPressed: () async {
                            final before = points;
                            final ok = await ref
                                .read(dailyQuestsProvider.notifier)
                                .claim(q.id);
                            if (!context.mounted || !ok) return;
                            final unlocked = before + q.points >=
                                DailyQuestBoard.pointsNeeded;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  unlocked
                                      ? 'Token Unlocked! You earned a FREE Token.'
                                      : 'Reward Claimed! +${q.points} points.',
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'CLAIM',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.brandPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _ShareEarn extends StatelessWidget {
  const _ShareEarn({required this.profileId, required this.profileName});
  final String profileId;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    final url = profileId.isEmpty
        ? 'https://www.swipess.com'
        : 'https://www.swipess.com/u/$profileId';

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                  ),
                ),
                child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHARE & EARN',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Get free messages for referrals',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                showInviteFriendsDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'INVITE FRIENDS',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    HapticFeedback.selectionClick();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite link copied')),
                      );
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'COPY',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SocialBtn(
                icon: Icons.chat_rounded,
                label: 'WA',
                onTap: () => showInviteFriendsDialog(context),
              ),
              const SizedBox(width: 8),
              _SocialBtn(
                icon: Icons.camera_alt_outlined,
                label: 'IG',
                onTap: () => showInviteFriendsDialog(context),
              ),
              const SizedBox(width: 8),
              _SocialBtn(
                icon: Icons.music_note_rounded,
                label: 'TT',
                onTap: () => showInviteFriendsDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  const _SocialBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackForm extends StatelessWidget {
  const _FeedbackForm({
    required this.category,
    required this.controller,
    required this.sending,
    required this.onCategory,
    required this.onSubmit,
  });

  final String? category;
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onCategory;
  final VoidCallback onSubmit;

  static const cats = [
    ('bug', 'Bug / Issue', Color(0xFFEF4444)),
    ('feature', 'Feature Request', Color(0xFF6366F1)),
    ('experience', 'App Experience', Color(0xFFF97316)),
    ('compliment', 'Compliment', Color(0xFF10B981)),
    ('other', 'Other', Color(0xFF94A3B8)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                ),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Feedback',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Help us improve Swipess',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cats)
              GestureDetector(
                onTap: () => onCategory(c.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: category == c.$1
                        ? c.$3.withAlpha(50)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: category == c.$1 ? c.$3 : Colors.white24,
                    ),
                  ),
                  child: Text(
                    c.$2,
                    style: GoogleFonts.plusJakartaSans(
                      color: category == c.$1 ? c.$3 : Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tell us what\'s on your mind…',
            hintStyle: TextStyle(color: Colors.white.withAlpha(90)),
            filled: true,
            fillColor: Colors.black.withAlpha(70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withAlpha(30)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withAlpha(30)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: sending ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              sending ? 'Sending…' : 'Send Feedback',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
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
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.brandPrimary.withAlpha(40)
              : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppTheme.brandPrimary : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MoreToolsGrid extends StatelessWidget {
  const _MoreToolsGrid({required this.unread});
  final int unread;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (
        Icons.home_work_outlined,
        'My listings',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OwnerPropertiesScreen()),
            )
      ),
      (
        Icons.how_to_reg_outlined,
        'Interested clients',
        () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const OwnerInterestedClientsScreen(),
              ),
            )
      ),
      (
        Icons.event_available_rounded,
        'Saved events',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EventFavoritesScreen()),
            )
      ),
      (
        Icons.psychology_rounded,
        'AI Memory / Brain',
        () => showMemoryDrawer(context),
      ),
      (
        Icons.bookmark_border_rounded,
        'Saved searches',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SavedSearchesScreen()),
            )
      ),
      (
        Icons.notifications_none_rounded,
        unread > 0 ? 'Alerts ($unread)' : 'Notifications',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            )
      ),
      (
        Icons.folder_outlined,
        'Document vault',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DocumentVaultScreen()),
            )
      ),
      (
        Icons.account_balance_wallet_outlined,
        'Escrow',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EscrowDashboardScreen()),
            )
      ),
      (
        Icons.gavel_rounded,
        'Legal hub',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LegalHubScreen()),
            )
      ),
      (
        Icons.balance_rounded,
        'Lawyer services',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LawyerServicesScreen()),
            )
      ),
      (
        Icons.work_outline_rounded,
        'Worker discovery',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WorkerDiscoveryScreen()),
            )
      ),
      (
        Icons.card_giftcard_rounded,
        'Resident perks',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PerksScreen()),
            )
      ),
      (
        Icons.info_outline_rounded,
        'About Swipess',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            )
      ),
      (
        Icons.qr_code_scanner_rounded,
        'Validate PEARL',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VapValidateScreen()),
            )
      ),
      (
        Icons.videocam_outlined,
        'Video tours',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VideoToursScreen()),
            )
      ),
      (
        Icons.people_outline_rounded,
        'Roommates',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoommateMatchingScreen()),
            )
      ),
      (
        Icons.newspaper_outlined,
        'Local intel',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocalIntelScreen()),
            )
      ),
      (
        Icons.trending_up_rounded,
        'Market prices',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PriceTrackerScreen()),
            )
      ),
      (
        Icons.handyman_outlined,
        'Maintenance',
        () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MaintenanceRequestsScreen(),
              ),
            )
      ),
      (
        Icons.help_outline_rounded,
        'Help & FAQ',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FAQScreen()),
            )
      ),
    ];

    return Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(item.$1, color: AppTheme.brandPrimary),
            title: Text(
              item.$2,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white38),
            onTap: item.$3,
          ),
      ],
    );
  }
}
