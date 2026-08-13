import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/bento_media_pools.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/ai_search_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/qf_well_glow.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/map/presentation/screens/live_map_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `BentoCategoryDashboard` — dash-well search block + two-column bento.
class BentoDashboardScreen extends ConsumerStatefulWidget {
  const BentoDashboardScreen({super.key});

  @override
  ConsumerState<BentoDashboardScreen> createState() =>
      _BentoDashboardScreenState();
}

class _BentoDashboardScreenState extends ConsumerState<BentoDashboardScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chromeVisibilityProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      ref.read(chromeVisibilityProvider.notifier).onScroll(
            pixels: notification.metrics.pixels,
            delta: notification.scrollDelta ?? 0,
          );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(discoveryLocationProvider);
    final isLight = ref.watch(isLightThemeProvider);
    final searchVisible = ref.watch(chromeVisibilityProvider);
    final canvas = AppTheme.canvasFor(isLight: isLight);
    final well = AppTheme.wellFor(isLight: isLight);

    final leftColumn =
        _bentoItems.where((item) => item.index.isEven).toList();
    final rightColumn =
        _bentoItems.where((item) => item.index.isOdd).toList();

    return Scaffold(
      backgroundColor: canvas,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            _SearchChromeWell(
              visible: searchVisible,
              isLight: isLight,
              well: well,
              location: location,
              onPickCity: () => _pickCity(context, ref),
              onPickDates: () => _pickDates(context, ref),
              onPickGuests: () => _pickGuests(context, ref),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 768),
              decoration: BoxDecoration(
                color: well,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QfWellGlow(
                isLight: isLight,
                padding: const EdgeInsets.all(6),
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _BentoColumn(
                        items: leftColumn,
                        isLight: isLight,
                        onOpen: (id, title) =>
                            _openBento(context, ref, id, title),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _BentoColumn(
                        items: rightColumn,
                        isLight: isLight,
                        onOpen: (id, title) =>
                            _openBento(context, ref, id, title),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBento(
    BuildContext context,
    WidgetRef ref,
    String id,
    String title,
  ) {
    HapticFeedback.mediumImpact();
    switch (id) {
      case 'legal':
        context.go(AppPaths.clientLegal);
        return;
      case 'seekers':
        context.go(AppPaths.exploreSeekers);
        return;
      case 'premium':
        context.push(AppPaths.subscriptionPackages);
        return;
      case 'recommended':
      case 'popular':
        openClientSwipeDeck(
          context,
          categoryId: 'property',
          categoryTitle: title,
        );
        return;
      default:
        openClientSwipeDeck(
          context,
          categoryId: id,
          categoryTitle: title,
        );
    }
  }

  Future<void> _pickCity(BuildContext context, WidgetRef ref) async {
    final city = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text('CHOOSE CITY',
                  style: AppTheme.displayItalic.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              ListTile(
                leading:
                    const Icon(Icons.map_rounded, color: AppTheme.brandPrimary),
                title: const Text('Open live map',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LiveMapScreen()),
                  );
                },
              ),
              const Divider(color: Colors.white24),
              for (final city in ListingTaxonomies.popularCities)
                ListTile(
                  title: Text(city, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, city),
                ),
            ],
          ),
        );
      },
    );
    if (city != null) {
      ref.read(discoveryLocationProvider.notifier).setCity(city);
    }
  }

  Future<void> _pickDates(BuildContext context, WidgetRef ref) async {
    const options = [
      'Any date',
      'This weekend',
      'Next week',
      'This month',
      'Flexible',
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            shrinkWrap: true,
            children: [
              Text('WHEN', style: AppTheme.displayItalic.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              for (final option in options)
                ListTile(
                  title:
                      Text(option, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      ref.read(discoveryLocationProvider.notifier).setDateLabel(picked);
    }
  }

  Future<void> _pickGuests(BuildContext context, WidgetRef ref) async {
    var guests = ref.read(discoveryLocationProvider).guests;
    final confirmed = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('GUESTS',
                        style: AppTheme.displayItalic.copyWith(fontSize: 18)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (guests > 1) setModalState(() => guests -= 1);
                          },
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.white, size: 32),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '$guests',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (guests < 16) setModalState(() => guests += 1);
                          },
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.white, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, guests),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed != null) {
      ref.read(discoveryLocationProvider.notifier).setGuests(confirmed);
    }
  }
}

class _SearchChromeWell extends StatelessWidget {
  const _SearchChromeWell({
    required this.visible,
    required this.isLight,
    required this.well,
    required this.location,
    required this.onPickCity,
    required this.onPickDates,
    required this.onPickGuests,
  });

  final bool visible;
  final bool isLight;
  final Color well;
  final DiscoveryLocation location;
  final VoidCallback onPickCity;
  final VoidCallback onPickDates;
  final VoidCallback onPickGuests;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: Duration(milliseconds: visible ? 360 : 340),
      curve: const Cubic(0.25, 0.1, 0.25, 1),
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -0.03),
        duration: Duration(milliseconds: visible ? 360 : 340),
        curve: const Cubic(0.25, 0.1, 0.25, 1),
        child: IgnorePointer(
          ignoring: !visible,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 768),
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: well,
              borderRadius: BorderRadius.circular(19.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AiSearchBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    '✨ AI-powered · Answers are generated by AI. AI can make mistakes. Consider verifying important information.',
                    style: GoogleFonts.plusJakartaSans(
                      color: isLight
                          ? Colors.black.withAlpha(110)
                          : Colors.white38,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardFilterPill(
                        isLight: isLight,
                        icon: Icons.location_on_rounded,
                        wash: const Color(0xFFFF6B6B),
                        text: location.label,
                        onTap: onPickCity,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardFilterPill(
                        isLight: isLight,
                        icon: Icons.calendar_today_rounded,
                        wash: const Color(0xFF4DABF7),
                        text: location.dateLabel,
                        onTap: onPickDates,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardFilterPill(
                        isLight: isLight,
                        icon: Icons.people_alt_rounded,
                        wash: const Color(0xFFFFD43B),
                        text:
                            '${location.guests} guest${location.guests == 1 ? '' : 's'}',
                        onTap: onPickGuests,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardFilterPill extends StatelessWidget {
  const _DashboardFilterPill({
    required this.isLight,
    required this.icon,
    required this.wash,
    required this.text,
    required this.onTap,
  });

  final bool isLight;
  final IconData icon;
  final Color wash;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = isLight ? const Color(0xFF111111) : Colors.white;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: AppTheme.dashboardFilterPill(isLight: isLight),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: wash.withAlpha(isLight ? 45 : 50),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: wash),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
          if (i > 0) const SizedBox(height: 6),
          _BentoTile(
            item: items[i],
            isLight: isLight,
            onOpen: onOpen,
          ),
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
              onTap: () => context.go(AppPaths.exploreEvents),
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
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              QuickFilterMedia(
                sources: widget.media,
                animationDelay: widget.stagger,
                enableVideo: widget.enableVideo,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x1A000000),
                      Color(0x66000000),
                      Color(0xE6000000),
                    ],
                    stops: [0, 0.45, 1],
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
                        fontWeight: FontWeight.w500,
                        fontSize: 9,
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

/// Cap `BENTO_ITEMS` order, sizes, and animation delays.
const _bentoItems = [
  _BentoItemData(
    index: 0,
    id: 'property',
    title: 'PROPERTIES',
    subtitle: 'Find properties to buy or rent',
    height: 260,
    delaySeconds: '0',
  ),
  _BentoItemData(
    index: 1,
    id: 'events',
    title: 'EVENTS LIVE',
    subtitle: 'Swipe event videos · tap to open',
    height: 340,
    delaySeconds: '4',
  ),
  _BentoItemData(
    index: 2,
    id: 'recommended',
    title: 'RECOMMENDED FOR YOU',
    subtitle: 'Curated listings',
    height: 260,
    delaySeconds: '8',
  ),
  _BentoItemData(
    index: 3,
    id: 'services',
    title: 'WORKERS',
    subtitle: 'Find people offering services',
    height: 340,
    delaySeconds: '12',
  ),
  _BentoItemData(
    index: 4,
    id: 'popular',
    title: 'POPULAR',
    subtitle: 'Trending now',
    height: 260,
    delaySeconds: '16',
  ),
  _BentoItemData(
    index: 5,
    id: 'yacht',
    title: 'YACHTS',
    subtitle: 'Yachts & boats to charter or buy',
    height: 340,
    delaySeconds: '20',
  ),
  _BentoItemData(
    index: 6,
    id: 'motorcycle',
    title: 'MOTORCYCLES',
    subtitle: 'Motorcycles for sale or rent',
    height: 340,
    delaySeconds: '24',
  ),
  _BentoItemData(
    index: 7,
    id: 'bicycle',
    title: 'BICYCLES',
    subtitle: 'Bicycles for sale or rent',
    height: 260,
    delaySeconds: '28',
  ),
  _BentoItemData(
    index: 8,
    id: 'seekers',
    title: 'SEEKERS',
    subtitle: 'People looking for workers',
    height: 260,
    delaySeconds: '32',
  ),
  _BentoItemData(
    index: 9,
    id: 'legal',
    title: 'LEGAL SERVICES',
    subtitle: 'Hire a top tier lawyer',
    height: 340,
    delaySeconds: '36',
  ),
  _BentoItemData(
    index: 10,
    id: 'premium',
    title: 'PREMIUM',
    subtitle: 'Buy a package & get benefits',
    height: 260,
    delaySeconds: '40',
  ),
];
