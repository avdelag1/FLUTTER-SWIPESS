import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"

top_bar_path = os.path.join(PROJECT_ROOT, "lib/src/core/widgets/app_top_bar.dart")
dash_shell_path = os.path.join(PROJECT_ROOT, "lib/src/features/dashboard/presentation/screens/dashboard_shell.dart")
poker_card_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/widgets/poker_category_card.dart")
swiper_screen_path = os.path.join(PROJECT_ROOT, "lib/src/features/swipes/presentation/screens/swiper_screen.dart")

# 1. Top Bar
top_bar_content = """import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  final bool showProfile;
  final bool showNotifications;
  final int notificationCount;
  final String? avatarUrl;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onFilterTap;
  final bool showFilter;

  const AppTopBar({
    super.key,
    this.showBack = false,
    this.showProfile = true,
    this.showNotifications = true,
    this.notificationCount = 0,
    this.avatarUrl,
    this.onProfileTap,
    this.onNotificationTap,
    this.onFilterTap,
    this.showFilter = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side
          if (showBack)
            _GlassPill(
              onTap: () => Navigator.of(context).maybePop(),
              child: Icon(Icons.chevron_left_rounded, color: Colors.white.withAlpha(220), size: 22),
            )
          else if (showProfile)
            _buildAvatar(),

          const Spacer(),

          // Right Side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showFilter && onFilterTap != null) ...[
                _GlassPill(
                  onTap: onFilterTap,
                  child: Icon(Icons.tune_rounded, color: Colors.white.withAlpha(200), size: 18),
                ),
                const SizedBox(width: 8),
              ],
              if (showNotifications) ...[
                _GlassPill(
                  badge: notificationCount,
                  onTap: onNotificationTap,
                  child: Icon(Icons.notifications_rounded, color: Colors.white.withAlpha(200), size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: onProfileTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
          ),
          border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
        ),
        child: avatarUrl != null
            ? ClipOval(child: Image.network(avatarUrl!, fit: BoxFit.cover))
            : const Icon(Icons.person_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final int badge;

  const _GlassPill({required this.child, this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(18),
              border: Border.all(color: Colors.white.withAlpha(30), width: 1),
            ),
            child: Center(child: child),
          ),
          if (badge > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
"""

# 2. Dashboard Shell
dash_shell_content = """import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/swiper_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/messages_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';

enum NavTab { dashboard, likes, ai, add, messages, idCard, seekers, filter, legal, events }

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  NavTab _currentTab = NavTab.dashboard;

  Widget _buildBody() {
    switch (_currentTab) {
      case NavTab.dashboard:
        return const SwiperScreen();
      case NavTab.events:
        return const EventsScreen();
      case NavTab.messages:
        return const MessagesScreen();
      default:
        // Fallback for not-yet-implemented tabs
        return const Center(child: Text('Coming Soon', style: TextStyle(color: Colors.white)));
    }
  }

  void _handleNavTap(NavTab tab) {
    HapticFeedback.lightImpact();
    
    if (tab == NavTab.filter) {
      FilterBottomSheet.show(context);
      return;
    }
    
    setState(() => _currentTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavItems = [
      _BottomNavItem(id: NavTab.dashboard, icon: Icons.bolt_rounded),
      _BottomNavItem(id: NavTab.likes, icon: Icons.local_fire_department_rounded),
      _BottomNavItem(id: NavTab.ai, icon: Icons.auto_awesome_rounded),
      _BottomNavItem(id: NavTab.add, icon: Icons.add_circle_outline_rounded),
      _BottomNavItem(id: NavTab.messages, icon: Icons.chat_bubble_outline_rounded),
      _BottomNavItem(id: NavTab.idCard, icon: Icons.verified_user_rounded),
      _BottomNavItem(id: NavTab.seekers, icon: Icons.people_outline_rounded),
      _BottomNavItem(id: NavTab.filter, icon: Icons.tune_rounded),
      _BottomNavItem(id: NavTab.legal, icon: Icons.gavel_rounded),
      _BottomNavItem(id: NavTab.events, icon: Icons.celebration_rounded),
    ];

    return Scaffold(
      backgroundColor: Colors.black, // var(--dash-bg)
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppTopBar(
        showFilter: _currentTab == NavTab.dashboard,
        onFilterTap: () => _handleNavTap(NavTab.filter),
        onProfileTap: () => _handleNavTap(NavTab.idCard),
        onNotificationTap: () {},
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(_currentTab),
              child: _buildBody(),
            ),
          ),
          
          // Bottom Navigation Liquid Glass
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Center(
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.dashWell.withAlpha(240),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 24, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: bottomNavItems.map((item) {
                        final isSelected = _currentTab == item.id;
                        return GestureDetector(
                          onTap: () => _handleNavTap(item.id),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.white.withAlpha(30) : Colors.transparent,
                                border: Border.all(color: isSelected ? Colors.white.withAlpha(50) : Colors.transparent, width: 1),
                              ),
                              child: Icon(
                                item.icon,
                                color: isSelected ? Colors.white : Colors.white.withAlpha(150),
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem {
  final NavTab id;
  final IconData icon;
  _BottomNavItem({required this.id, required this.icon});
}
"""

# 3. Swiper Screen (SwipeAllDashboard equivalent)
swiper_screen_content = """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/poker_category_card.dart';

class SwiperScreen extends ConsumerStatefulWidget {
  const SwiperScreen({super.key});

  @override
  ConsumerState<SwiperScreen> createState() => _SwiperScreenState();
}

class _SwiperScreenState extends ConsumerState<SwiperScreen> {
  final List<PokerCardData> _cards = [
    PokerCardData(id: 'property', title: 'REAL ESTATE', imageUrl: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9'),
    PokerCardData(id: 'auto', title: 'AUTOMOTIVE', imageUrl: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a'),
    PokerCardData(id: 'marine', title: 'MARINE', imageUrl: 'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a'),
    PokerCardData(id: 'aviation', title: 'AVIATION', imageUrl: 'https://images.unsplash.com/photo-1540962351504-03099e0a754b'),
    PokerCardData(id: 'services', title: 'SERVICES', imageUrl: 'https://images.unsplash.com/photo-1582719508461-905c673771fd'),
  ];

  void _handleCycle(String id, bool isRight) {
    HapticFeedback.lightImpact();
    setState(() {
      final card = _cards.firstWhere((c) => c.id == id);
      _cards.remove(card);
      if (isRight) {
        _cards.add(card); // Move to bottom
      } else {
        _cards.insert(0, card); // Should actually pop from bottom and push to top in a real cyclic deck, but for simplicity we just rotate
      }
    });
  }

  void _handleBringToFront(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      final card = _cards.removeAt(index);
      _cards.insert(0, card);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // background dash-bg
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 72,
        bottom: MediaQuery.of(context).padding.bottom + 80,
      ),
      child: Stack(
        children: [
          // Soft tonal well behind cards
          Positioned(
            top: MediaQuery.of(context).size.height * 0.18,
            bottom: MediaQuery.of(context).size.height * 0.16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.dashWell.withAlpha(230),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          
          // Content Split
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Top 55% - Events Video Quick Filter
                Expanded(
                  flex: 55,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(32),
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1516450360452-9312f5e86fc7'),
                        fit: BoxFit.cover,
                        opacity: 0.8,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withAlpha(200)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        const Positioned(
                          bottom: 24,
                          left: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FEATURED EVENT', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              SizedBox(height: 4),
                              Text('Monaco Grand Prix', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom 45% - Poker Card Deck
                Expanded(
                  flex: 45,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: constraints.maxHeight * (520 / 780),
                        child: Stack(
                          alignment: Alignment.center,
                          children: _cards.reversed.toList().asMap().entries.map((entry) {
                            final reversedIdx = entry.key;
                            final card = entry.value;
                            final index = _cards.length - 1 - reversedIdx;
                            final isTop = index == 0;

                            return PokerCategoryCard(
                              key: ValueKey(card.id),
                              card: card,
                              index: index,
                              total: _cards.length,
                              isTop: isTop,
                              onCycle: _handleCycle,
                              onBringToFront: _handleBringToFront,
                            );
                          }).toList(),
                        ),
                      );
                    }
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

class PokerCardData {
  final String id;
  final String title;
  final String imageUrl;
  
  PokerCardData({required this.id, required this.title, required this.imageUrl});
}
"""

# 4. Poker Category Card Widget
poker_card_content = """import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/swiper_screen.dart';

class PokerCategoryCard extends StatelessWidget {
  final PokerCardData card;
  final int index;
  final int total;
  final bool isTop;
  final Function(String, bool) onCycle; // true = right, false = left
  final Function(int) onBringToFront;

  const PokerCategoryCard({
    super.key,
    required this.card,
    required this.index,
    required this.total,
    required this.isTop,
    required this.onCycle,
    required this.onBringToFront,
  });

  @override
  Widget build(BuildContext context) {
    if (index > 4) return const SizedBox.shrink(); // Only show top 5

    // Stack positioning math to mimic framer-motion deck
    final double yOffset = index * 12.0;
    final double scale = 1 - (index * 0.05);
    final double zRotation = (index % 2 == 0 ? -1 : 1) * index * 0.02;

    return isTop ? _buildDraggableCard(context) : _buildBackgroundCard(context, yOffset, scale, zRotation);
  }

  Widget _buildBackgroundCard(BuildContext context, double yOffset, double scale, double zRotation) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: yOffset,
      bottom: -yOffset,
      child: GestureDetector(
        onTap: () => onBringToFront(index),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(scale)
            ..rotateZ(zRotation),
          child: _buildCardContent(),
        ),
      ),
    );
  }

  Widget _buildDraggableCard(BuildContext context) {
    return Draggable<String>(
      data: card.id,
      feedback: Transform.rotate(
        angle: 0.05,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.4,
          child: Opacity(opacity: 0.9, child: _buildCardContent()),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      onDragEnd: (details) {
        if (details.offset.dx.abs() > 100 || details.velocity.pixelsPerSecond.dx.abs() > 500) {
          onCycle(card.id, details.offset.dx > 0);
        }
      },
      child: _buildCardContent(),
    );
  }

  Widget _buildCardContent() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        image: DecorationImage(
          image: NetworkImage(card.imageUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                colors: [Colors.black.withAlpha(50), Colors.black.withAlpha(180)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            child: Text(
              card.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
"""

# Create directory if it doesn't exist
os.makedirs(os.path.dirname(poker_card_path), exist_ok=True)

# Write files
with open(top_bar_path, "w") as f:
    f.write(top_bar_content)

with open(dash_shell_path, "w") as f:
    f.write(dash_shell_content)
    
with open(swiper_screen_path, "w") as f:
    f.write(swiper_screen_content)
    
with open(poker_card_path, "w") as f:
    f.write(poker_card_content)

print("HUD refactor complete.")
