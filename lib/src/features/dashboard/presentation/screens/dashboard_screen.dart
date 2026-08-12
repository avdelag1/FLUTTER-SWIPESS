import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/category_card.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/category_poker_card.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/dashboard_bottom_nav.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/dashboard_top_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';
import 'package:go_router/go_router.dart';

/// Capacitor dashboard: HUD chrome + events teaser + category poker deck.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final CardSwiperController _controller = CardSwiperController();
  String _activeNav = 'dashboard';
  int _topIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNav(String id) {
    setState(() => _activeNav = id);
    if (id == 'dashboard') return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${dashboardNavItems.firstWhere((e) => e.id == id).label} — design chrome only'),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppTheme.dashBg)),
          Column(
            children: [
              const DashboardTopBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 560;
                      final deck = CardSwiper(
                        controller: _controller,
                        cardsCount: dashboardCategories.length,
                        numberOfCardsDisplayed: 3,
                        backCardOffset: const Offset(0, 18),
                        padding: EdgeInsets.zero,
                        isLoop: true,
                        onSwipe: (previous, current, direction) {
                          setState(() => _topIndex = current ?? 0);
                          return true;
                        },
                        cardBuilder: (
                          context,
                          index,
                          horizontalThresholdPercentage,
                          verticalThresholdPercentage,
                        ) {
                          return CategoryPokerCard(
                            card: dashboardCategories[index],
                            isTop: index == _topIndex,
                            onEngage: () => context.go('/swipes'),
                          );
                        },
                      );

                      return Stack(
                        children: [
                          Align(
                            alignment: const Alignment(0, 0.1),
                            child: FractionallySizedBox(
                              widthFactor: 0.92,
                              heightFactor: 0.72,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppTheme.dashWell.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(40),
                                ),
                              ),
                            ),
                          ),
                          if (stacked)
                            Column(
                              children: [
                                const SizedBox(
                                  height: 160,
                                  width: double.infinity,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: EventsTeaserCard(),
                                  ),
                                ),
                                Expanded(child: deck),
                              ],
                            )
                          else
                            Row(
                              children: [
                                const Expanded(
                                  flex: 55,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 8, top: 8, bottom: 8),
                                    child: EventsTeaserCard(),
                                  ),
                                ),
                                Expanded(
                                  flex: 45,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: deck,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              DashboardBottomNav(activeId: _activeNav, onSelected: _onNav),
            ],
          ),
        ],
      ),
    );
  }
}
