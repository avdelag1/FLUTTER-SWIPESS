import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/holographic_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/settings_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/owner_properties_screen.dart';
import 'package:flutter_swipes/src/features/roommates/presentation/screens/roommate_matching_screen.dart';
import 'package:flutter_swipes/src/features/video_tours/presentation/screens/video_tours_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/price_tracker_screen.dart';
import 'package:flutter_swipes/src/features/escrow/presentation/screens/escrow_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/subscription_packages_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/faq_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/maintenance_requests_screen.dart';
import 'package:flutter_swipes/src/features/insights/presentation/screens/local_intel_screen.dart';
import 'package:flutter_swipes/src/features/profile/data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Ambient Background
          Positioned.fill(
            child: Container(color: const Color(0xFF0A0A0D)),
          ),
          
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                // Top Nav
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'YOUR ID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.5,
                      ),
                    ),
                    _GlassPillButton(
                      icon: Icons.settings_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Holographic ID
                Consumer(
                  builder: (context, ref, child) {
                    final profileAsync = ref.watch(currentProfileProvider);
                    return profileAsync.when(
                      data: (profile) {
                        if (profile == null) {
                          // Fallback or unauthenticated
                          return const HolographicIDCard(
                            name: 'Guest User',
                            idNumber: 'SWS-0000',
                            occupation: 'Welcome',
                            location: 'World',
                            years: '0 yr',
                            bio: 'Please log in to view your profile.',
                          );
                        }
                        
                        // Extract fields with fallbacks
                        final name = profile['name'] ?? profile['full_name'] ?? 'Unknown User';
                        final idNumber = profile['id']?.toString().substring(0, 8) ?? 'SWS-XXXX';
                        final occupation = profile['occupation'] ?? 'Visionary';
                        final location = profile['city'] ?? profile['location'] ?? 'Global';
                        final years = '${profile['years_in_city'] ?? 1} yr';
                        final bio = profile['bio'] ?? profile['vap_bio'] ?? 'Building the exclusive ecosystem for visionaries.';
                        
                        // Handle avatar which could be string or JSON
                        String? avatarUrl;
                        if (profile['avatar_url'] != null) {
                          avatarUrl = profile['avatar_url'];
                        } else if (profile['profile_images'] != null) {
                          final images = profile['profile_images'];
                          if (images is List && images.isNotEmpty) {
                            avatarUrl = images.first.toString();
                          } else if (images is String) {
                            avatarUrl = images;
                          }
                        }

                        return HolographicIDCard(
                          name: name,
                          idNumber: idNumber.toUpperCase(),
                          occupation: occupation,
                          location: location,
                          years: years,
                          bio: bio,
                          avatarUrl: avatarUrl,
                        );
                      },
                      loading: () => const SizedBox(
                        height: 200, 
                        child: Center(child: CircularProgressIndicator(color: Color(0xFFFF4D00))),
                      ),
                      error: (e, st) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                    );
                  },
                ),
                const SizedBox(height: 48),

                // Settings List
                _buildSettingsButton(Icons.edit_rounded, 'Edit Profile'),
                const SizedBox(height: 12),
                _buildSettingsButton(Icons.shield_rounded, 'Privacy & Security'),
                const SizedBox(height: 12),
                _buildSettingsButton(Icons.payment_rounded, 'Payment Methods'),
                const SizedBox(height: 12),
                _buildSettingsButton(Icons.notifications_rounded, 'Notifications'),
                const SizedBox(height: 32),
                
                // Log Out
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withAlpha(25),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.brandPrimary.withAlpha(50)),
                    ),
                    child: const Center(
                      child: Text(
                        'LOG OUT',
                        style: TextStyle(
                          color: AppTheme.brandPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Navigation Actions
                _buildProfileAction(context, 'Owner Dashboard', Icons.dashboard_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OwnerPropertiesScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'Roommate Matching', Icons.people_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoommateMatchingScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'Video Tours', Icons.play_circle_filled_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideoToursScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'Market Trends', Icons.bar_chart_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PriceTrackerScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'Escrow Vault', Icons.shield_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EscrowDashboardScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'Document Vault', Icons.folder_shared_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DocumentVaultScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'Subscriptions & Upgrades', Icons.star_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionPackagesScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'Maintenance Requests', Icons.build_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MaintenanceRequestsScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'Local Intel', Icons.travel_explore_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalIntelScreen()));
                }),
                const SizedBox(height: 16),
                _buildProfileAction(context, 'FAQ & Help', Icons.help_outline_rounded, () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FAQScreen()));
                }),
                
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAction(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.brandPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton(IconData icon, String title) {
    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(25), width: 1),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white.withAlpha(200), size: 24),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassPillButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 24)),
          ),
        ),
      ),
    );
  }
}
