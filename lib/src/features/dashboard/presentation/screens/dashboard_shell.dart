import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/app_bottom_nav.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/swiper_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/messages_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';

/// The main dashboard shell — persists BottomNav across all tabs,
/// mirroring the web app's PersistentDashboardLayout.
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  NavTab _currentTab = NavTab.swipe;


  Widget _buildBody() {
    switch (_currentTab) {
      case NavTab.swipe:
        return const SwipeTabContent();
      case NavTab.events:
        return const EventsScreen();
      case NavTab.messages:
        return const MessagesScreen();
      case NavTab.profile:
        return const ProfileScreen();
      case NavTab.add:
        // Center "+" button — show add listing flow (placeholder)
        return const SwipeTabContent();
    }
  }

  String _tabTitle() {
    switch (_currentTab) {
      case NavTab.swipe:
        return 'Swipess';
      case NavTab.events:
        return 'Events';
      case NavTab.messages:
        return 'Messages';
      case NavTab.profile:
        return 'Profile';
      case NavTab.add:
        return 'Create';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppTopBar(
        title: _tabTitle(),
        showFilter: _currentTab == NavTab.swipe,
        onFilterTap: () => FilterBottomSheet.show(context),
        onProfileTap: () => setState(() => _currentTab = NavTab.profile),
        onNotificationTap: () {},
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_currentTab),
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: _currentTab,
        onTabSelected: (tab) {
          if (tab == NavTab.add) {
            // TODO: Open add listing flow
            return;
          }
          setState(() => _currentTab = tab);
        },
      ),
    );
  }
}
