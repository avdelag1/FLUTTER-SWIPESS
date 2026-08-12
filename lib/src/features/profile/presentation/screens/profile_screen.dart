import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/escrow/presentation/screens/escrow_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/local_intel_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/price_tracker_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/faq_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/legal_hub_screen.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/who_liked_you_screen.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/advertise_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/maintenance_requests_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/owner_properties_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/saved_searches_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/settings_screen.dart';
import 'package:flutter_swipes/src/features/roommates/presentation/screens/roommate_matching_screen.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/subscription_packages_screen.dart';
import 'package:flutter_swipes/src/features/video_tours/presentation/screens/video_tours_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Stack(
        children: [
          // Ambient background glow orbs for glassmorphism accenting
          Positioned(
            top: -100,
            right: -70,
            child: _buildOrb(AppTheme.brandPrimary.withAlpha(45), 300),
          ),
          Positioned(
            top: 220,
            left: -90,
            child: _buildOrb(AppTheme.brandAccent.withAlpha(35), 260),
          ),
          Positioned(
            bottom: -60,
            right: -50,
            child: _buildOrb(AppTheme.brandPrimary.withAlpha(30), 220),
          ),

          // Main scrollable content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top bar title header
                  const _ProfileTopHeader(),
                  const SizedBox(height: 24),

                  // Hero section (avatar, name, bio, location, join date)
                  const _ProfileHeroSection(),
                  const SizedBox(height: 28),

                  // Stats row (Listings, Swipes, Matches with animated feel)
                  const _ProfileStatsRow(),
                  const SizedBox(height: 28),

                  // VIP Membership glass banner
                  const _GlassVipBanner(),
                  const SizedBox(height: 28),

                  const _ProfileHubSection(),
                  const SizedBox(height: 24),

                  const _ProfilePreferencesSection(),
                  const SizedBox(height: 24),

                  // Account section (Sign Out)
                  const _ProfileAccountSection(),
                  const SizedBox(height: 32),

                  // App version footer
                  Text(
                    'Swipess v1.0.0 • Build 42',
                    style: TextStyle(
                      color: Colors.white.withAlpha(80),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ─── Header Widget ────────────────────────────────────────────────────────────

class _ProfileTopHeader extends StatelessWidget {
  const _ProfileTopHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (Navigator.of(context).canPop()) ...[
              _GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
            ],
            const Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
        _GlassIconButton(
          icon: Icons.edit_outlined,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
        ),
      ],
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

class _ProfileHeroSection extends ConsumerWidget {
  const _ProfileHeroSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final name = profile?.name ?? 'Swipess member';
    final avatar = profile?.avatarUrl;
    final city = profile?.city;
    return Column(
      children: [
        // Avatar with gradient border ring & camera edit badge
        Stack(
          children: [
            Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66FF4D00),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A0A0C),
                ),
                child: ClipOval(
                  child: avatar != null
                      ? Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.white.withAlpha(20),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white.withAlpha(20),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                  ),
                  border: Border.all(color: const Color(0xFF0A0A0C), width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // User Name + Verified Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 6),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
              ).createShader(bounds),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Bio Text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            profile?.bio?.isNotEmpty == true
                ? profile!.bio!
                : 'Member of the Swipess network',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Location & Join Date pills
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            _InfoPill(
              icon: Icons.location_on_rounded,
              iconColor: AppTheme.brandPrimary,
              label: city?.isNotEmpty == true ? city! : 'Swipess',
            ),
            _InfoPill(
              icon: Icons.calendar_month_rounded,
              iconColor: AppTheme.brandAccent,
              label: 'Member since Jan 2024',
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Info Pill ────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Stats Row ───────────────────────────────────────────────────────

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _StatItem(
                label: 'Listings',
                targetValue: 12,
                suffix: '',
              ),
              _StatDivider(),
              _StatItem(
                label: 'Swipes',
                targetValue: 1482,
                suffix: '',
              ),
              _StatDivider(),
              _StatItem(
                label: 'Matches',
                targetValue: 94,
                suffix: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int targetValue;
  final String suffix;

  const _StatItem({
    required this.label,
    required this.targetValue,
    required this.suffix,
  });

  String _formatNumber(int val) {
    if (val >= 1000) {
      final k = (val / 1000).toStringAsFixed(1);
      return '${k}k';
    }
    return '$val';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFFE2E8F0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: Text(
                '${_formatNumber(value.round())}$suffix',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(140),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withAlpha(25),
    );
  }
}

// ─── VIP Banner Card ─────────────────────────────────────────────────────────

class _GlassVipBanner extends StatelessWidget {
  const _GlassVipBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionPackagesScreen()),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.brandAccent.withAlpha(35),
                  AppTheme.brandPrimary.withAlpha(35),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.brandPrimary.withAlpha(75),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SWIPESS VIP MEMBER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to view packages & upgrade',
                        style: TextStyle(
                          color: Colors.white.withAlpha(175),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Settings Menu Section ────────────────────────────────────────────────────

class _MenuItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
}

class _ProfileHubSection extends ConsumerWidget {
  const _ProfileHubSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ProfileMenuSection(
      title: 'HUB',
      items: [
        _MenuItemData(
          icon: Icons.home_work_outlined,
          title: 'My listings',
          subtitle: 'Active, pending & sold assets',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OwnerPropertiesScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.favorite_border_rounded,
          title: 'Who liked you',
          subtitle: 'Profile likes from other members',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WhoLikedYouScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.bookmark_border_rounded,
          title: 'Saved searches',
          subtitle: 'Reuse discovery filters & alerts',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SavedSearchesScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.campaign_outlined,
          title: 'Advertise',
          subtitle: 'Submit a promo for review',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdvertiseScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Escrow',
          subtitle: 'Deposits held for contracts',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EscrowDashboardScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.folder_outlined,
          title: 'Document vault',
          subtitle: 'IDs, contracts & uploads',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DocumentVaultScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.gavel_rounded,
          title: 'Legal hub',
          subtitle: 'Templates & digital contracts',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LegalHubScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.videocam_outlined,
          title: 'Video tours',
          subtitle: 'Property walkthrough feed',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VideoToursScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.people_outline_rounded,
          title: 'Roommates',
          subtitle: 'Match people sharing space',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoommateMatchingScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.newspaper_outlined,
          title: 'Local intel',
          subtitle: 'Neighborhood updates',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LocalIntelScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.trending_up_rounded,
          title: 'Market prices',
          subtitle: 'Neighborhood averages',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PriceTrackerScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.handyman_outlined,
          title: 'Maintenance',
          subtitle: 'Report & track property issues',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MaintenanceRequestsScreen()),
          ),
        ),
      ],
    );
  }
}

class _ProfilePreferencesSection extends ConsumerWidget {
  const _ProfilePreferencesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    return _ProfileMenuSection(
      title: 'PREFERENCES',
      items: [
        _MenuItemData(
          icon: Icons.person_outline_rounded,
          title: 'Edit Profile',
          subtitle: 'Update personal info, avatar & bio',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: 'Match alerts, messages & news',
          badge: unread > 0 ? '$unread' : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          subtitle: 'FAQs & guidance',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FAQScreen()),
          ),
        ),
        _MenuItemData(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Security, sounds & legal',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItemData> items;

  const _ProfileMenuSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(25), width: 1),
              ),
              child: Column(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isLast = index == items.length - 1;
                  return Column(
                    children: [
                      _GlassMenuItemTile(
                        item: item,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          item.onTap();
                        },
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 60,
                          endIndent: 16,
                          color: Colors.white.withAlpha(18),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassMenuItemTile extends StatelessWidget {
  final _MenuItemData item;
  final VoidCallback onTap;

  const _GlassMenuItemTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withAlpha(20),
      highlightColor: Colors.white.withAlpha(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(18),
                border: Border.all(color: Colors.white.withAlpha(30), width: 1),
              ),
              child: Icon(
                item.icon,
                color: Colors.white.withAlpha(230),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(130),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (item.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.brandAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withAlpha(120),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Account Section (Sign Out) ───────────────────────────────────────────────

class _ProfileAccountSection extends StatelessWidget {
  const _ProfileAccountSection();

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Color(0xFF1E1E24),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'ACCOUNT',
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(25), width: 1),
              ),
              child: InkWell(
                onTap: () => _handleSignOut(context),
                borderRadius: BorderRadius.circular(24),
                splashColor: const Color(0xFFFF453A).withAlpha(30),
                highlightColor: const Color(0xFFFF453A).withAlpha(15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF453A).withAlpha(25),
                          border: Border.all(
                            color: const Color(0xFFFF453A).withAlpha(50),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFFF453A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Color(0xFFFF453A),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Log out of your Swipess session',
                              style: TextStyle(
                                color: Colors.white.withAlpha(130),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFFF453A),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Glass Icon Button Helper ─────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(18),
          border: Border.all(color: Colors.white.withAlpha(30), width: 1),
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white.withAlpha(230),
            size: 20,
          ),
        ),
      ),
    );
  }
}
