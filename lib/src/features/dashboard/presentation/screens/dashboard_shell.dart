import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/app_bottom_nav.dart';
import 'package:flutter_swipes/src/core/widgets/app_top_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/discover_home_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/swiper_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/events_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/messages_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';

/// Persistent HUD shell — glass top pills + glowing dock, Capacitor chrome.
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  NavTab _currentTab = NavTab.swipe;
  bool _inDeck = false;

  Widget _buildBody() {
    switch (_currentTab) {
      case NavTab.swipe:
        if (_inDeck) return const SwipeTabContent();
        return DiscoverHomeScreen(
          onOpenSwipe: () => setState(() => _inDeck = true),
          onOpenEvents: () => setState(() => _currentTab = NavTab.events),
        );
      case NavTab.events:
        return const EventsScreen();
      case NavTab.messages:
        return const MessagesScreen();
      case NavTab.profile:
        return const ProfileScreen();
      case NavTab.add:
        return DiscoverHomeScreen(
          onOpenSwipe: () => setState(() {
            _currentTab = NavTab.swipe;
            _inDeck = true;
          }),
          onOpenEvents: () => setState(() => _currentTab = NavTab.events),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppTopBar(
        title: 'Swipess',
        showFilter: _inDeck && _currentTab == NavTab.swipe,
        onFilterTap: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const FilterBottomSheet(),
          );
        },
        onProfileTap: () => setState(() => _currentTab = NavTab.profile),
        onNotificationTap: () {},
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey('${_currentTab.name}-$_inDeck'),
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: _currentTab,
        onTabSelected: (tab) {
          if (tab == NavTab.add) {
            setState(() {
              _currentTab = NavTab.swipe;
              _inDeck = false;
            });
            return;
          }
          setState(() {
            _currentTab = tab;
            if (tab == NavTab.swipe) _inDeck = false;
          });
        },
      ),
    );
  }
}
