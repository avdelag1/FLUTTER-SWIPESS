import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/messages_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/vap_id_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';
import 'package:flutter_swipes/src/features/likes/presentation/screens/likes_screen.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/screens/seekers_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/legal_hub_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key});

  Widget _buildBody(NavTab tab) {
    switch (tab) {
      case NavTab.dashboard:
        return const BentoDashboardScreen();
      case NavTab.events:
        return const EventsScreen();
      case NavTab.messages:
        return const MessagesScreen();
      case NavTab.idCard:
        return const VapIdScreen();
      case NavTab.likes:
        return const LikesScreen();
      case NavTab.add:
        return const AddListingScreen();
      case NavTab.seekers:
        return const SeekersScreen();
      case NavTab.legal:
        return const LegalHubScreen();
      case NavTab.filter:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(navTabProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final bottomNavItems = [
      _BottomNavItem(id: NavTab.dashboard, icon: Icons.bolt_rounded),
      _BottomNavItem(id: NavTab.likes, icon: Icons.local_fire_department_rounded),
      _BottomNavItem(id: NavTab.add, icon: Icons.add_circle_outline_rounded),
      _BottomNavItem(id: NavTab.messages, icon: Icons.chat_bubble_outline_rounded),
      _BottomNavItem(id: NavTab.idCard, icon: Icons.verified_user_rounded),
      _BottomNavItem(id: NavTab.seekers, icon: Icons.people_outline_rounded),
      _BottomNavItem(id: NavTab.filter, icon: Icons.tune_rounded),
      _BottomNavItem(id: NavTab.legal, icon: Icons.gavel_rounded),
      _BottomNavItem(id: NavTab.events, icon: Icons.celebration_rounded),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppTopBar(
        firstName: profile?.name.split(' ').first,
        avatarUrl: profile?.avatarUrl,
        onProfileTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(currentTab),
              child: _buildBody(currentTab),
            ),
          ),
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
                        final isSelected = currentTab == item.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (item.id == NavTab.filter) {
                              FilterBottomSheet.show(context);
                              return;
                            }
                            ref.read(navTabProvider.notifier).set(item.id);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.white.withAlpha(30) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? Colors.white.withAlpha(50) : Colors.transparent,
                                  width: 1,
                                ),
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
