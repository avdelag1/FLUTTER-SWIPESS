import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"

# Create directories
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/profile/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/roommates/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/video_tours/presentation/screens"), exist_ok=True)

# File paths
owner_properties_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/profile/presentation/screens/owner_properties_screen.dart")
profile_detail_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/profile/presentation/screens/profile_detail_screen.dart")
roommate_matching_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/roommates/presentation/screens/roommate_matching_screen.dart")
video_tours_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/video_tours/presentation/screens/video_tours_screen.dart")

# 1. Owner Properties Screen
owner_properties_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';

class OwnerPropertiesScreen extends StatefulWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  State<OwnerPropertiesScreen> createState() => _OwnerPropertiesScreenState();
}

class _OwnerPropertiesScreenState extends State<OwnerPropertiesScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: Column(
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
                        'MY ASSETS',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withAlpha(25)),
                    ),
                    child: Row(
                      children: [
                        _buildTab('ACTIVE', 0),
                        _buildTab('PENDING', 1),
                        _buildTab('SOLD', 2),
                      ],
                    ),
                  ),
                ),
                
                // Content
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 40),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return _buildAssetCard();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isActive 
                ? const LinearGradient(colors: [Color(0xFFFF4D00), Color(0xFFEB4898)])
                : null,
            boxShadow: isActive ? [BoxShadow(color: const Color(0xFFFF4D00).withAlpha(89), blurRadius: 24, offset: const Offset(0, 8))] : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withAlpha(127),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network('https://images.unsplash.com/photo-1600596542815-ffad4c1539a9', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                  colors: [Colors.transparent, Colors.black.withAlpha(220)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('The Neo Penthouse', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('Miami, FL', style: TextStyle(color: Colors.white.withAlpha(200), fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: const Text('EDIT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
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

# 2. Profile Detail Screen
profile_detail_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          
          // Image Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network('https://images.unsplash.com/photo-1524504388940-b1c1722653e1', fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0],
                      colors: [Colors.transparent, const Color(0xFF0A0A0D)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(50)),
                      ),
                      child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Profile Details
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    border: Border(top: BorderSide(color: Colors.white.withAlpha(25))),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sarah, 24', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, color: const Color(0xFFFF4D00), size: 16),
                              const SizedBox(width: 8),
                              const Text('Miami, FL', style: TextStyle(color: Colors.white, fontSize: 14)),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(50),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('VERIFIED', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text('ABOUT', style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          const SizedBox(height: 12),
                          const Text(
                            'Just moved to Miami. Looking for a modern apartment with a great view. Love design, tech, and fitness.',
                            style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(25),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withAlpha(50)),
                                  ),
                                  child: const Center(
                                    child: Text('REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFFF4D00), Color(0xFFEB4898)]),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFFFF4D00).withAlpha(127), blurRadius: 24, offset: const Offset(0, 8)),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text('MESSAGE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
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

# 3. Roommate Matching Screen
roommate_matching_screen_content = """import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';

class RoommateMatchingScreen extends StatelessWidget {
  const RoommateMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: SwipeCard(
              title: 'Michael, 28',
              subtitle: 'Looking for a roommate in Brickell',
              imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
              price: 'Budget: \$2k/mo',
            ),
          ),
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
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(50)),
                      ),
                      child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(100),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('FILTERS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
"""

# 4. Video Tours Screen
video_tours_screen_content = """import 'package:flutter/material.dart';

class VideoToursScreen extends StatelessWidget {
  const VideoToursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fake Video Feed (just an image for now, representing a playing video)
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.7, 1.0],
                  colors: [Colors.black.withAlpha(100), Colors.transparent, Colors.black.withAlpha(200)],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Bar
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
                            color: Colors.black.withAlpha(100),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(50)),
                          ),
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'VIDEO TOURS',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom Info & Right Actions
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D00),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('\$12,500/mo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(height: 12),
                            const Text('The Neo Penthouse', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            const Text('Miami, FL • 3 Bed • 2 Bath', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                      // Actions
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(Icons.favorite_rounded, '1.2k'),
                          const SizedBox(height: 24),
                          _buildActionButton(Icons.chat_bubble_rounded, '34'),
                          const SizedBox(height: 24),
                          _buildActionButton(Icons.share_rounded, 'Share'),
                        ],
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

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(50)),
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 28)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
"""

with open(owner_properties_screen_path, "w") as f: f.write(owner_properties_screen_content)
with open(profile_detail_screen_path, "w") as f: f.write(profile_detail_screen_content)
with open(roommate_matching_screen_path, "w") as f: f.write(roommate_matching_screen_content)
with open(video_tours_screen_path, "w") as f: f.write(video_tours_screen_content)

print("Phase 8 screens generated successfully.")
