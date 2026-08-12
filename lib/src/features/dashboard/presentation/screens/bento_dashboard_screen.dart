import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';

class BentoDashboardScreen extends ConsumerWidget {
  const BentoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black, // Matches neo-naive background
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Bar Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(16, 16, 20, 1.0),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white.withAlpha(150), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ask AI to find anything...',
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white.withAlpha(150), size: 20),
                  ],
                ),
              ),
            ),
            
            // Filter Pills (Matching DashboardFilters.tsx exactly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(child: _buildNeoNaiveFilterPill(Icons.location_on_rounded, 'Tulum, Mexico', const Color(0xFFFF6B6B), context, () {
                    _showPlaceholderModal(context, 'Location / Map Search', Icons.map_rounded);
                  })),
                  const SizedBox(width: 8),
                  Expanded(child: _buildNeoNaiveFilterPill(Icons.calendar_today_rounded, 'Any date', const Color(0xFF4DABF7), context, () {
                    _showPlaceholderModal(context, 'Dates / Calendar', Icons.date_range_rounded);
                  })),
                  const SizedBox(width: 8),
                  Expanded(child: _buildNeoNaiveFilterPill(Icons.people_alt_rounded, '2 guests', const Color(0xFFFFD43B), context, () {
                    _showPlaceholderModal(context, 'Guests', Icons.people_alt_rounded);
                  })),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bento Grid (Matching all 11 items from BentoCategoryDashboard.tsx)
            Expanded(
              child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 120),
                itemBuilder: (context, index) {
                  final item = _bentoItems[index];
                  if (item.id == 'events') {
                    return SizedBox(
                      height: item.height,
                      child: EventsTeaserCard(
                        onTap: () =>
                            ref.read(navTabProvider.notifier).set(NavTab.events),
                      ),
                    );
                  }
                  return _BentoCard(
                    title: item.title,
                    subtitle: item.subtitle,
                    imageUrl: item.imageUrl,
                    height: item.height,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (item.id == 'legal') {
                        ref.read(navTabProvider.notifier).set(NavTab.legal);
                        return;
                      }
                      if (item.id == 'seekers') {
                        ref.read(navTabProvider.notifier).set(NavTab.seekers);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ClientSwipeContainer(
                            categoryId: item.id == 'services' ? 'worker' : item.id,
                            categoryTitle: item.title,
                          ),
                        ),
                      );
                    },
                  );
                },
                itemCount: _bentoItems.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholderModal(BuildContext context, String title, IconData icon) {
    showGlassModal(
      context: context,
      builder: (context) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppTheme.brandPrimary),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNeoNaiveFilterPill(IconData icon, String text, Color washColor, BuildContext context, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(14, 14, 20, 0.96),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withAlpha(240), width: 2.5),
          boxShadow: [
            BoxShadow(color: Colors.white.withAlpha(115), offset: const Offset(1.5, 1.5), blurRadius: 0),
            BoxShadow(color: Colors.white.withAlpha(30), blurRadius: 16, offset: Offset.zero),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Wash Icon
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: washColor.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: washColor),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final double height;
  final VoidCallback onTap;

  const _BentoCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32), // Large corner radius like neo-frame
          color: const Color.fromRGBO(22, 22, 28, 1.0), // --dash-elevated
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withAlpha(80), BlendMode.darken),
          ),
          border: Border.all(color: Colors.white.withAlpha(15), width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoItemData {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final double height;
  const _BentoItemData(this.id, this.title, this.subtitle, this.imageUrl, this.height);
}

// Exactly matches all 11 items from BentoCategoryDashboard.tsx
const _bentoItems = [
  _BentoItemData('property', 'PROPERTIES', 'Find properties to buy or rent', 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=800&q=90', 260),
  _BentoItemData('events', 'EVENTS LIVE', 'Swipe event videos · tap to open', 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=800&q=90', 340),
  _BentoItemData('recommended', 'RECOMMENDED FOR YOU', 'Curated listings', 'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=800&q=90', 260),
  _BentoItemData('services', 'WORKERS', 'Find people offering services', 'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=800&q=90', 340),
  _BentoItemData('popular', 'POPULAR', 'Trending now', 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=800&q=90', 260),
  _BentoItemData('yacht', 'YACHTS', 'Yachts & boats to charter or buy', 'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=800&q=90', 340),
  _BentoItemData('motorcycle', 'MOTORCYCLES', 'Motorcycles for sale or rent', 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=800&q=90', 340),
  _BentoItemData('bicycle', 'BICYCLES', 'Bicycles for sale or rent', 'https://images.unsplash.com/photo-1520188740392-563d1dc6d480?auto=format&fit=crop&w=800&q=90', 260),
  _BentoItemData('seekers', 'SEEKERS', 'People looking for workers', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=90', 260),
  _BentoItemData('legal', 'LEGAL SERVICES', 'Hire a top tier lawyer', 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&w=800&q=90', 340),
  _BentoItemData('premium', 'PREMIUM', 'Buy a package & get benefits', 'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=800&q=90', 260),
];
