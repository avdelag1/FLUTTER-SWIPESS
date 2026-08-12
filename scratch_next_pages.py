import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"

os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/profile/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/notifications/presentation/screens"), exist_ok=True)

listing_detail_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/screens/listing_detail_screen.dart")
settings_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/profile/presentation/screens/settings_screen.dart")
notifications_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/notifications/presentation/screens/notifications_screen.dart")

# 1. Listing Detail Screen
listing_detail_screen_content = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';

class ListingDetailScreen extends ConsumerWidget {
  final dynamic listingData; // In a real app this would be a proper model

  const ListingDetailScreen({
    super.key,
    required this.listingData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provide a mocked entity if none is passed
    final item = listingData ?? {
      'id': 'detail-preview',
      'title': 'The Neo Penthouse',
      'location': 'Miami, FL',
      'price': '\$12,500/mo',
      'imageUrl': 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9',
      'type': 'property',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Dimmer
          Positioned.fill(
            child: Container(color: Colors.black),
          ),
          
          // Full Screen Static Card
          Positioned.fill(
            child: SwipeCard(
              item: item,
            ),
          ),
          
          // Top Nav (Back Button)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(127),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(50)),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Action Bar Override
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D00).withAlpha(200),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFF4D00)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFF4D00).withAlpha(127), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Center(
                      child: Text('MESSAGE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: const Center(
                    child: Icon(Icons.share_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
"""

# 2. Settings Screen
settings_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(40)),
                          ),
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'SETTINGS',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    children: [
                      _buildSectionTitle('ACCOUNT'),
                      _buildSettingsTile(Icons.shield_rounded, 'Account Security', 'Password & 2FA'),
                      const SizedBox(height: 12),
                      _buildSettingsTile(Icons.credit_card_rounded, 'Payment Methods', 'Manage billing'),
                      const SizedBox(height: 12),
                      _buildSettingsTile(Icons.block_rounded, 'Blocked Users', 'Manage blocking'),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('PREFERENCES'),
                      _buildSettingsTile(Icons.volume_up_rounded, 'Swipe Sounds', 'Haptics & audio'),
                      const SizedBox(height: 12),
                      _buildSettingsTile(Icons.language_rounded, 'Language', 'English (US)'),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('LEGAL'),
                      _buildSettingsTile(Icons.description_rounded, 'Terms of Service', ''),
                      const SizedBox(height: 12),
                      _buildSettingsTile(Icons.privacy_tip_rounded, 'Privacy Policy', ''),
                      
                      const SizedBox(height: 48),
                      // Delete Account
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.red.withAlpha(50)),
                        ),
                        child: const Center(
                          child: Text(
                            'DELETE ACCOUNT',
                            style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Text(
        title,
        style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
    return ClipRRect(
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
              Icon(icon, color: AppTheme.brandPrimary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
"""

# 3. Notifications Screen
notifications_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(40)),
                          ),
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'NOTIFICATIONS',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    children: [
                      _buildNotificationCard(
                        Icons.local_fire_department_rounded, 
                        Colors.pinkAccent, 
                        'New Match!', 
                        'You and Sarah liked each other.', 
                        '2m ago',
                      ),
                      const SizedBox(height: 12),
                      _buildNotificationCard(
                        Icons.chat_bubble_rounded, 
                        Colors.blueAccent, 
                        'New Message', 
                        'John: "Is the penthouse still available?"', 
                        '1h ago',
                      ),
                      const SizedBox(height: 12),
                      _buildNotificationCard(
                        Icons.verified_user_rounded, 
                        const Color(0xFFFF4D00), 
                        'Identity Verified', 
                        'Your ID Card has been officially stamped.', 
                        '2d ago',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(IconData icon, Color color, String title, String subtitle, String time) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(50)),
                ),
                child: Center(child: Icon(icon, color: color, size: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(time, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
"""

with open(listing_detail_screen_path, "w") as f: f.write(listing_detail_screen_content)
with open(settings_screen_path, "w") as f: f.write(settings_screen_content)
with open(notifications_screen_path, "w") as f: f.write(notifications_screen_content)

print("Next 3 screens generated successfully.")
