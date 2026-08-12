import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"

os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/likes/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/ai/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/add/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/seekers/presentation/screens"), exist_ok=True)
os.makedirs(os.path.join(PROJECT_ROOT, "lib/src/features/legal/presentation/screens"), exist_ok=True)

likes_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/likes/presentation/screens/likes_screen.dart")
ai_radio_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/ai/presentation/screens/ai_radio_screen.dart")
add_listing_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/add/presentation/screens/add_listing_screen.dart")
seekers_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/seekers/presentation/screens/seekers_screen.dart")
legal_hub_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/legal/presentation/screens/legal_hub_screen.dart")

# 1. Likes Screen
likes_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  bool isListings = true;

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
                // Top Tab Selector
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
                        _buildTab('LIKED LISTINGS', true),
                        _buildTab('LIKED PEOPLE', false),
                      ],
                    ),
                  ),
                ),
                
                // Content
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return _buildLikedCard();
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

  Widget _buildTab(String title, bool isListingTab) {
    final isActive = isListings == isListingTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isListings = isListingTab),
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

  Widget _buildLikedCard() {
    return Container(
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
                  colors: [Colors.transparent, Colors.black.withAlpha(200)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\$1.5M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text('Miami, FL', style: TextStyle(color: Colors.white.withAlpha(200), fontWeight: FontWeight.w600, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
"""

# 2. AI Radio Screen
ai_radio_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';

class AiRadioScreen extends StatelessWidget {
  const AiRadioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0705),
      body: Stack(
        children: [
          // Subtle Cheetah Pattern Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.network('https://images.unsplash.com/photo-1549480017-d76466a4b7e8', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'DJ TURNTABLE RADIO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Dial
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(40), width: 2),
                    gradient: RadialGradient(
                      colors: [Colors.white.withAlpha(25), Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF4D00).withAlpha(50), blurRadius: 100),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.white.withAlpha(127), blurRadius: 40),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.play_arrow_rounded, color: Colors.black, size: 48),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 64),
                
                // Track Info
                const Text('NOW PLAYING', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4)),
                const SizedBox(height: 8),
                const Text('Miami House Mix', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
                
                const Spacer(),
                const SizedBox(height: 120), // Bottom padding for dock
              ],
            ),
          ),
        ],
      ),
    );
  }
}
"""

# 3. Add Listing Screen
add_listing_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';

class AddListingScreen extends StatelessWidget {
  const AddListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                const Text(
                  'WHAT ARE WE\nADDING TODAY?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 48),
                _buildAddCard(Icons.home_work_rounded, 'Real Estate', 'List a property for sale or rent'),
                const SizedBox(height: 16),
                _buildAddCard(Icons.directions_car_rounded, 'Vehicle', 'List a luxury car or yacht'),
                const SizedBox(height: 16),
                _buildAddCard(Icons.work_rounded, 'Service', 'Offer your professional services'),
                const SizedBox(height: 16),
                _buildAddCard(Icons.event_rounded, 'Event', 'Host an exclusive event'),
                
                const SizedBox(height: 120), // Bottom padding for dock
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard(IconData icon, String title, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4D00).withAlpha(50),
                ),
                child: Center(child: Icon(icon, color: const Color(0xFFFF4D00), size: 28)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100), size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
"""

# 4. Seekers Screen
seekers_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';

class SeekersScreen extends StatelessWidget {
  const SeekersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                const Text(
                  'SEEKER\nREQUESTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildSeekerCard('Looking for Penthouse', 'Miami, FL', 'Need a 3BR penthouse with ocean views. Move in next month.'),
                const SizedBox(height: 20),
                _buildSeekerCard('Fitness Coach', 'New York, NY', 'Looking for a private PT for early morning sessions.'),
                
                const SizedBox(height: 120), // Bottom padding for dock
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekerCard(String title, String location, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.blue.withAlpha(50)),
                ),
                child: const Text('REAL ESTATE', style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              const Spacer(),
              const Text('2 hrs ago', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.white.withAlpha(150), size: 14),
              const SizedBox(width: 4),
              Text(location, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Text(description, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
"""

# 5. Legal Hub Screen
legal_hub_screen_content = """import 'dart:ui';
import 'package:flutter/material.dart';

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                const Text(
                  'LEGAL HUB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildLegalCategory(Icons.home_work_rounded, 'Landlord Issues', 'Problems with your landlord or property owner'),
                const SizedBox(height: 16),
                _buildLegalCategory(Icons.attach_money_rounded, 'Rent & Payment', 'Disputes about rent payments or charges'),
                const SizedBox(height: 16),
                _buildLegalCategory(Icons.description_rounded, 'Contract Issues', 'Problems with rental agreements or contracts'),
                
                const SizedBox(height: 120), // Bottom padding for dock
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCategory(IconData icon, String title, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 16),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
"""

with open(likes_screen_path, "w") as f: f.write(likes_screen_content)
with open(ai_radio_screen_path, "w") as f: f.write(ai_radio_screen_content)
with open(add_listing_screen_path, "w") as f: f.write(add_listing_screen_content)
with open(seekers_screen_path, "w") as f: f.write(seekers_screen_content)
with open(legal_hub_screen_path, "w") as f: f.write(legal_hub_screen_content)

print("Final 5 screens generated successfully.")
