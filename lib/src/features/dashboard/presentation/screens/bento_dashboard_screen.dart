import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/bento_media_pools.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/paywall_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class BentoDashboardScreen extends ConsumerStatefulWidget {
  const BentoDashboardScreen({super.key});

  @override
  ConsumerState<BentoDashboardScreen> createState() =>
      _BentoDashboardScreenState();
}

class _BentoDashboardScreenState extends ConsumerState<BentoDashboardScreen> {
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
    final leftItems = _bentoItems.where((i) => i.index.isEven).toList();
    final rightItems = _bentoItems.where((i) => i.index.isOdd).toList();

    return Container(
      color: isLight ? AppTheme.lightDashBg : const Color(0xFF0D1015),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + 72,
                  16,
                  16,
                ),
                child: Consumer(
                  builder: (context, ref, child) {
                    final showChrome = ref.watch(chromeVisibilityProvider);
                    return IgnorePointer(
                      ignoring: !showChrome,
                      child: AnimatedOpacity(
                        opacity: showChrome ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: GlowSearchBar(
                          onTap: () => _openCategory('property', 'PROPERTIES'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFEDEDF2)
                        : const Color(0xFF141820),
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
      return Consumer(
        builder: (context, ref, _) {
          return SizedBox(
            height: item.height,
            child: DecoratedBox(
              decoration: AppTheme.qfNeoFrame(isLight: isLight),
              child: ClipRRect(
                borderRadius: AppTheme.qfNeoFrameRadius,
                child: EventsTeaserCard(
                  onTap: () {
                    final sub = ref.read(subscriptionProvider).value;
                    if (sub != null && sub.effectiveTier.canViewEvents != true) {
                      showPaywall(context, featureName: 'Events & Pros');
                      return;
                    }
                    onOpen(item.id, item.title);
                  },
                ),
              ),
            ),
          );
        },
      );
    }

    return _BentoCard(
      title: item.title,
      subtitle: item.subtitle,
      height: item.height,
      media: BentoMediaPools.forId(item.id),
      stagger: Duration(seconds: int.parse(item.delaySeconds)),
      isLight: isLight,
      enableVideo: item.index < 2,
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

  static const _brightnessMatrix = <double>[
    1.08, 0, 0, 0, 5,
    0, 1.08, 0, 0, 5,
    0, 0, 1.08, 0, 5,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: Container(
          height: widget.height,
          decoration: AppTheme.qfNeoFrame(isLight: widget.isLight),
          child: ClipRRect(
            borderRadius: AppTheme.qfNeoFrameRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_brightnessMatrix),
                  child: QuickFilterMedia(
                    sources: widget.media,
                    enableVideo: widget.enableVideo,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0x88000000),
                      ],
                      stops: [0, 0.72, 1],
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
                          color: Colors.white.withAlpha(225),
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
  _BentoItemData(index: 0, id: 'property', title: 'PROPERTIES', subtitle: 'Find properties to buy or rent', height: 300, delaySeconds: '0'),
  _BentoItemData(index: 1, id: 'events', title: 'EVENTS LIVE', subtitle: 'Swipe event videos · tap to open', height: 380, delaySeconds: '4'),
  _BentoItemData(index: 2, id: 'recommended', title: 'RECOMMENDED FOR YOU', subtitle: 'Curated listings', height: 300, delaySeconds: '8'),
  _BentoItemData(index: 3, id: 'services', title: 'WORKERS', subtitle: 'Find people offering services', height: 380, delaySeconds: '12'),
  _BentoItemData(index: 4, id: 'popular', title: 'POPULAR', subtitle: 'Trending now', height: 300, delaySeconds: '16'),
  _BentoItemData(index: 5, id: 'yacht', title: 'YACHTS', subtitle: 'Yachts & boats to charter or buy', height: 380, delaySeconds: '20'),
  _BentoItemData(index: 6, id: 'motorcycle', title: 'MOTORCYCLES', subtitle: 'Motorcycles for sale or rent', height: 380, delaySeconds: '24'),
  _BentoItemData(index: 7, id: 'bicycle', title: 'BICYCLES', subtitle: 'Bicycles for sale or rent', height: 300, delaySeconds: '28'),
  _BentoItemData(index: 8, id: 'seekers', title: 'SEEKERS', subtitle: 'People looking for workers', height: 300, delaySeconds: '32'),
  _BentoItemData(index: 9, id: 'legal', title: 'LEGAL SERVICES', subtitle: 'Hire a top tier lawyer', height: 380, delaySeconds: '36'),
  _BentoItemData(index: 10, id: 'premium', title: 'PREMIUM', subtitle: 'Buy a package & get benefits', height: 300, delaySeconds: '40'),
];
