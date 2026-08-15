import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/bento_media_pools.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _ChipSpec {
  const _ChipSpec(this.id, this.label, this.color, this.icon);
  final String id;
  final String label;
  final Color color;
  final IconData icon;
}

const _chips = [
  _ChipSpec('property', 'Properties', Color(0xFFFF4D4D), Icons.apartment_rounded),
  _ChipSpec('events', 'Events', Color(0xFF3B82F6), Icons.celebration_rounded),
  _ChipSpec('worker', 'Pros', Color(0xFFEAB308), Icons.auto_awesome),
];

class BentoDashboardScreen extends ConsumerStatefulWidget {
  const BentoDashboardScreen({super.key});

  @override
  ConsumerState<BentoDashboardScreen> createState() => _BentoDashboardScreenState();
}

class _BentoDashboardScreenState extends ConsumerState<BentoDashboardScreen> {
  int _chipIndex = 0;

  void _openCategory(String id, String title) {
    if (id == 'events') {
      context.go(AppPaths.exploreEvents);
      return;
    }
    openClientSwipeDeck(context, categoryId: id, categoryTitle: title);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(isLightThemeProvider);
    
    // Split into left and right columns
    final leftItems = _bentoItems.where((i) => i.index.isEven).toList();
    final rightItems = _bentoItems.where((i) => i.index.isOdd).toList();

    return Container(
      color: AppTheme.dashBg,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  children: [
                    GlowSearchBar(onTap: () => _openCategory('property', 'PROPERTIES')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (var i = 0; i < _chips.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _CategoryChip(
                              spec: _chips[i],
                              selected: _chipIndex == i,
                              onTap: () {
                                AppHaptics.selection();
                                setState(() => _chipIndex = i);
                                _openCategory(_chips[i].id, _chips[i].label);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFE8E8EE) : const Color(0xFF101014),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BentoColumn(
                          items: leftItems,
                          isLight: isLight,
                          onOpen: _openCategory,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BentoColumn(
                          items: rightItems,
                          isLight: isLight,
                          onOpen: _openCategory,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _ChipSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white : const Color(0x33FFFFFF),
          ),
          boxShadow: selected
              ? const [BoxShadow(color: Colors.black54, blurRadius: 12)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.black.withAlpha(20) : Colors.white12,
              ),
              child: Icon(
                spec.icon,
                size: 10,
                color: selected ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spec.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoColumn extends StatelessWidget {
  const _BentoColumn({
    required this.items,
    required this.isLight,
    required this.onOpen,
  });

  final List<_BentoItemData> items;
  final bool isLight;
  final void Function(String id, String title) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _BentoTile(item: items[i], isLight: isLight, onOpen: onOpen),
        ],
      ],
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.item,
    required this.isLight,
    required this.onOpen,
  });

  final _BentoItemData item;
  final bool isLight;
  final void Function(String id, String title) onOpen;

  @override
  Widget build(BuildContext context) {
    if (item.id == 'events') {
      return SizedBox(
        height: item.height,
        child: DecoratedBox(
          decoration: AppTheme.qfNeoFrame(isLight: isLight),
          child: ClipRRect(
            borderRadius: AppTheme.qfNeoFrameRadius,
            child: EventsTeaserCard(
              onTap: () => onOpen(item.id, item.title),
            ),
          ),
        ),
      );
    }

    return _BentoCard(
      title: item.title,
      subtitle: item.subtitle,
      height: item.height,
      media: BentoMediaPools.forId(item.id),
      stagger: Duration(seconds: int.parse(item.delaySeconds)),
      isLight: isLight,
      enableVideo: item.index < 2, // only top few use videos for perf
      onTap: () => onOpen(item.id, item.title),
    );
  }
}

class _BentoCard extends StatefulWidget {
  const _BentoCard({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.media,
    required this.stagger,
    required this.isLight,
    required this.onTap,
    this.enableVideo = true,
  });

  final String title;
  final String subtitle;
  final double height;
  final List<String> media;
  final Duration stagger;
  final bool isLight;
  final VoidCallback onTap;
  final bool enableVideo;

  @override
  State<_BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<_BentoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 80),
        child: Container(
          height: widget.height,
          decoration: AppTheme.qfNeoFrame(isLight: widget.isLight),
          child: ClipRRect(
            borderRadius: AppTheme.qfNeoFrameRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                QuickFilterMedia(
                  sources: widget.media,
                  enableVideo: widget.enableVideo,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xAA000000),
                      ],
                      stops: [0, 0.65, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTheme.displayItalic.copyWith(
                          fontSize: 14,
                          letterSpacing: 1.6,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xCCFFFFFF),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.4,
                          height: 1.35,
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
        ),
      ),
    );
  }
}

class _BentoItemData {
  const _BentoItemData({
    required this.index,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.height,
    required this.delaySeconds,
  });

  final int index;
  final String id;
  final String title;
  final String subtitle;
  final double height;
  final String delaySeconds;
}

const _bentoItems = [
  _BentoItemData(
    index: 0,
    id: 'property',
    title: 'PROPERTIES',
    subtitle: 'Find properties to buy or rent',
    height: 300,
    delaySeconds: '0',
  ),
  _BentoItemData(
    index: 1,
    id: 'events',
    title: 'EVENTS LIVE',
    subtitle: 'Swipe event videos · tap to open',
    height: 380,
    delaySeconds: '4',
  ),
  _BentoItemData(
    index: 2,
    id: 'recommended',
    title: 'RECOMMENDED FOR YOU',
    subtitle: 'Curated listings',
    height: 300,
    delaySeconds: '8',
  ),
  _BentoItemData(
    index: 3,
    id: 'services',
    title: 'WORKERS',
    subtitle: 'Find people offering services',
    height: 380,
    delaySeconds: '12',
  ),
  _BentoItemData(
    index: 4,
    id: 'popular',
    title: 'POPULAR',
    subtitle: 'Trending now',
    height: 300,
    delaySeconds: '16',
  ),
  _BentoItemData(
    index: 5,
    id: 'yacht',
    title: 'YACHTS',
    subtitle: 'Yachts & boats to charter or buy',
    height: 380,
    delaySeconds: '20',
  ),
  _BentoItemData(
    index: 6,
    id: 'motorcycle',
    title: 'MOTORCYCLES',
    subtitle: 'Motorcycles for sale or rent',
    height: 380,
    delaySeconds: '24',
  ),
  _BentoItemData(
    index: 7,
    id: 'bicycle',
    title: 'BICYCLES',
    subtitle: 'Bicycles for sale or rent',
    height: 300,
    delaySeconds: '28',
  ),
  _BentoItemData(
    index: 8,
    id: 'seekers',
    title: 'SEEKERS',
    subtitle: 'People looking for workers',
    height: 300,
    delaySeconds: '32',
  ),
  _BentoItemData(
    index: 9,
    id: 'legal',
    title: 'LEGAL SERVICES',
    subtitle: 'Hire a top tier lawyer',
    height: 380,
    delaySeconds: '36',
  ),
  _BentoItemData(
    index: 10,
    id: 'premium',
    title: 'PREMIUM',
    subtitle: 'Buy a package & get benefits',
    height: 300,
    delaySeconds: '40',
  ),
];
