import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/bento_media_pools.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_place_search.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:flutter_swipes/src/features/session/domain/app_market_context.dart';
import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/paywall_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

final newItemsCountProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = Supabase.instance.client;
  final prefs = await SharedPreferences.getInstance();
  final counts = <String, int>{};

  const categoryMap = {
    'property': 'property',
    'services': 'services',
    'yacht': 'yacht',
    'dining': 'dining',
    'motos': 'motorcycles',
    'jets': 'jets',
    'people': 'people',
  };

  DateTime getLastAccessed(String id) {
    final str = prefs.getString('bento_last_accessed_$id');
    if (str != null) return DateTime.parse(str).toUtc();
    return DateTime.now().toUtc().subtract(const Duration(days: 7));
  }

  try {
    final rows = await client
        .from('listings')
        .select('category, created_at')
        .eq('is_active', true)
        .eq('status', 'active');

    final listings = rows as List;
    
    for (final entry in categoryMap.entries) {
      final lastAccessed = getLastAccessed(entry.key);
      int count = 0;
      for (final row in listings) {
        final cat = row['category']?.toString();
        if (cat == entry.value) {
          final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toUtc();
          if (createdAt != null && createdAt.isAfter(lastAccessed)) {
            count++;
          }
        }
      }
      counts[entry.key] = count;
    }

    final popLast = getLastAccessed('popular');
    counts['popular'] = listings.where((r) {
      final dt = DateTime.tryParse(r['created_at']?.toString() ?? '')?.toUtc();
      return dt != null && dt.isAfter(popLast);
    }).length;

    final recLast = getLastAccessed('recommended');
    counts['recommended'] = listings.where((r) {
      final dt = DateTime.tryParse(r['created_at']?.toString() ?? '')?.toUtc();
      return dt != null && dt.isAfter(recLast);
    }).length;

    try {
      final eventRows = await client
          .from('events')
          .select('created_at')
          .eq('is_published', true);
      final evLast = getLastAccessed('events');
      counts['events'] = (eventRows as List).where((r) {
        final dt = DateTime.tryParse(r['created_at']?.toString() ?? '')?.toUtc();
        return dt != null && dt.isAfter(evLast);
      }).length;
    } catch (_) {}

  } catch (_) {}

  return counts;
});

class AccessedCategoriesManager {
  AccessedCategoriesManager(this.ref);
  final Ref ref;

  Future<void> markAccessed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bento_last_accessed_$id', DateTime.now().toUtc().toIso8601String());
    ref.invalidate(newItemsCountProvider);
  }
}

final accessedCategoriesProvider = Provider((ref) => AccessedCategoriesManager(ref));

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class BentoDashboardScreen extends ConsumerStatefulWidget {
  const BentoDashboardScreen({super.key});

  @override
  ConsumerState<BentoDashboardScreen> createState() =>
      _BentoDashboardScreenState();
}

class _BentoDashboardScreenState extends ConsumerState<BentoDashboardScreen> {
  final _aiSearchController = TextEditingController();

  @override
  void dispose() {
    _aiSearchController.dispose();
    super.dispose();
  }

  bool _marketAllows(String feature) {
    final market = ref.read(appMarketProvider).value;
    return market == null ||
        (market.effectiveOpen && market.featureEnabled(feature));
  }

  void _showMarketUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This module is not active in your current SWIPESS market.',
        ),
      ),
    );
  }

  void _openCategory(String id, String title) {
    final feature = _featureForBentoId(id);
    if (feature != null && !_marketAllows(feature)) {
      _showMarketUnavailable();
      return;
    }

    switch (id) {
      case 'events':
        context.go(AppPaths.exploreEvents);
        return;
      case 'seekers':
        context.go(AppPaths.exploreSeekers);
        return;
      case 'legal':
        context.go(AppPaths.clientLegal);
        return;
      case 'premium':
        context.go(AppPaths.subscriptionPackages);
        return;
      default:
        openClientSwipeDeck(context, categoryId: id, categoryTitle: title);
    }
  }

  void _openAiSearch([String? query]) {
    if (!_marketAllows('ai')) {
      _showMarketUnavailable();
      return;
    }
    final subscription = ref.read(subscriptionProvider).value;
    if (subscription != null && subscription.effectiveTier.canUseAI != true) {
      showPaywall(context, featureName: 'Google Gemini');
      return;
    }
    ref
        .read(overlayModalsProvider.notifier)
        .openConcierge(query ?? _aiSearchController.text);
    _aiSearchController.clear();
  }

  Future<void> _pickCity() async {
    final discovery = ref.read(discoveryLocationProvider);
    final searchController = TextEditingController();
    var searchResults = <MapboxPlaceResult>[];
    var searching = false;
    var hasSearched = false;
    String? searchError;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final isLight = Theme.of(sheetContext).brightness == Brightness.light;
          final ink = isLight ? const Color(0xFF101014) : Colors.white;
          final surface = isLight
              ? Colors.white.withAlpha(245)
              : const Color(0xFF12161D).withAlpha(248);

          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> runSearch() async {
                final query = searchController.text.trim();
                if (query.length < 2) {
                  setSheetState(() {
                    hasSearched = true;
                    searchResults = const [];
                    searchError = 'Type at least 2 characters.';
                  });
                  return;
                }

                setSheetState(() {
                  searching = true;
                  hasSearched = true;
                  searchError = null;
                });

                try {
                  final results = await MapboxPlaceSearch.search(query);
                  if (!sheetContext.mounted) return;
                  setSheetState(() {
                    searching = false;
                    searchResults = results;
                    searchError = results.isEmpty
                        ? 'No place found. Try a city, state, region or country.'
                        : null;
                  });
                } catch (_) {
                  if (!sheetContext.mounted) return;
                  setSheetState(() {
                    searching = false;
                    searchResults = const [];
                    searchError = 'Could not search right now. Try again.';
                  });
                }
              }

              void selectLocation({
                required String city,
                required String country,
                required double latitude,
                required double longitude,
                required int radiusKm,
              }) {
                final notifier = ref.read(discoveryLocationProvider.notifier);
                notifier.setCoordinates(
                  city: city,
                  country: country,
                  latitude: latitude,
                  longitude: longitude,
                );
                notifier.setRadiusKm(radiusKm);
                Navigator.pop(sheetContext);
              }

              return SafeArea(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
                  ),
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isLight
                          ? Colors.black.withAlpha(18)
                          : Colors.white.withAlpha(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ink.withAlpha(55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Passport location',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Choose a Swipess city or search anywhere.',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: ink.withAlpha(130),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Icon(Icons.close_rounded, color: ink),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                        child: TextField(
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: true,
                          onSubmitted: (_) => runSearch(),
                          decoration: InputDecoration(
                            hintText: 'Search Texas, Nashville, Alaska…',
                            prefixIcon: const Icon(
                              Icons.travel_explore_rounded,
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Search world',
                              onPressed: searching ? null : runSearch,
                              icon: const Icon(Icons.search_rounded),
                            ),
                            filled: true,
                            fillColor: isLight
                                ? Colors.black.withAlpha(7)
                                : Colors.white.withAlpha(13),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: ink.withAlpha(28)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: ink.withAlpha(28)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: const Color(0xFF60A5FA).withAlpha(180),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (searching)
                        const LinearProgressIndicator(
                          minHeight: 2,
                          color: Color(0xFF60A5FA),
                          backgroundColor: Colors.transparent,
                        ),
                      if (searchError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              searchError!,
                              style: GoogleFonts.plusJakartaSans(
                                color: ink.withAlpha(150),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                          children: [
                            if (searchResults.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
                                child: Text(
                                  'SEARCH RESULTS',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: ink.withAlpha(125),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .8,
                                  ),
                                ),
                              ),
                              for (final result in searchResults)
                                ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  leading: const Icon(
                                    Icons.public_rounded,
                                    color: Color(0xFF60A5FA),
                                  ),
                                  title: Text(
                                    result.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: result.subtitle.isEmpty
                                      ? null
                                      : Text(
                                          result.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: ink.withAlpha(125),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 13,
                                    color: Color(0xFF60A5FA),
                                  ),
                                  onTap: () => selectLocation(
                                    city: result.name,
                                    country: result.country,
                                    latitude: result.latitude,
                                    longitude: result.longitude,
                                    radiusKm: result.suggestedRadiusKm,
                                  ),
                                ),
                              const Divider(height: 18),
                            ] else if (hasSearched && !searching) ...[
                              const SizedBox(height: 2),
                            ],
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
                              child: Text(
                                'PASSPORT DESTINATIONS',
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink.withAlpha(125),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8,
                                ),
                              ),
                            ),
                            for (final city in PassportCities.all)
                              Builder(
                                builder: (context) {
                                  final selected =
                                      city.name.toLowerCase() ==
                                      discovery.city.toLowerCase();
                                  return ListTile(
                                    dense: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    leading: Icon(
                                      Icons.location_on_outlined,
                                      color: selected
                                          ? const Color(0xFF60A5FA)
                                          : ink,
                                    ),
                                    title: Text(
                                      city.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: ink,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      city.country,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: ink.withAlpha(125),
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: selected
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF60A5FA),
                                            size: 20,
                                          )
                                        : null,
                                    onTap: () => selectLocation(
                                      city: city.name,
                                      country: city.country,
                                      latitude: city.lat,
                                      longitude: city.lng,
                                      radiusKm: 25,
                                    ),
                                  );
                                },
                              ),
                          ],
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
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _pickDates() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Choose dates',
      saveText: 'Apply',
    );
    if (!mounted || range == null) return;

    final start = DateFormat('MMM d').format(range.start);
    final end = DateFormat('MMM d').format(range.end);
    final label = DateUtils.isSameDay(range.start, range.end)
        ? start
        : '$start–$end';
    ref.read(discoveryLocationProvider.notifier).setDateLabel(label);
  }

  Future<void> _pickGuests() async {
    var guests = ref.read(discoveryLocationProvider).guests;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isLight = Theme.of(sheetContext).brightness == Brightness.light;
        final ink = isLight ? const Color(0xFF101014) : Colors.white;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.white.withAlpha(245)
                      : const Color(0xFF12161D).withAlpha(248),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withAlpha(18)
                        : Colors.white.withAlpha(30),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ink.withAlpha(55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Guests',
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'How many people?',
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink.withAlpha(130),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Remove guest',
                          onPressed: guests > 1
                              ? () => setSheetState(() => guests--)
                              : null,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '$guests',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Add guest',
                          onPressed: guests < 16
                              ? () => setSheetState(() => guests++)
                              : null,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, guests),
                        child: const Text('Apply'),
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

    if (!mounted || selected == null) return;
    ref.read(discoveryLocationProvider.notifier).setGuests(selected);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(isLightThemeProvider);
    final discovery = ref.watch(discoveryLocationProvider);
    final market = ref.watch(appMarketProvider).value;
    final visibleItems = _bentoItems
        .where((item) => _bentoFeatureEnabled(market, item.id))
        .toList(growable: false);
    final leftItems = visibleItems.where((i) => i.index.isEven).toList();
    final rightItems = visibleItems.where((i) => i.index.isOdd).toList();

    return Container(
      color: isLight ? AppTheme.lightDashBg : const Color(0xFF0D1015),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFFFF4D00),
          backgroundColor: isLight ? Colors.white : const Color(0xFF15171C),
          onRefresh: () async {
            try {
              AppHaptics.light();
            } catch (_) {}
            ref.invalidate(newItemsCountProvider);
            ref.invalidate(appMarketProvider);
            try {
              await Future.wait([
                ref.read(newItemsCountProvider.future),
                ref.read(appMarketProvider.future),
              ]);
            } catch (_) {}
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                // SafeArea already accounts for the status bar. Keep the AI
                // field tucked directly under the compact persistent header.
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
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
                          hint: market != null &&
                                  (!market.effectiveOpen ||
                                      !market.featureEnabled('ai'))
                              ? 'AI is not active in this market'
                              : 'What are you looking for?',
                          onTap: () => _openAiSearch(),
                          controller: _aiSearchController,
                          onSubmitted: (val) => _openAiSearch(val),
                          locationLabel: discovery.city,
                          dateLabel: discovery.dateLabel,
                          guestLabel:
                              '${discovery.guests} ${discovery.guests == 1 ? 'guest' : 'guests'}',
                          onLocationTap: _pickCity,
                          onDatesTap: _pickDates,
                          onGuestsTap: _pickGuests,
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
                child: Padding(
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

class _BentoTile extends ConsumerWidget {
  const _BentoTile({
    required this.item,
    required this.isLight,
    required this.onOpen,
  });

  final _BentoItemData item;
  final bool isLight;
  final void Function(String id, String title) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(newItemsCountProvider).value ?? const {};
    final unreadCount = counts[item.id] ?? 0;
    
    final badgeWidget = unreadCount > 0 
      ? Positioned(
          top: 10,
          right: 10,
          child: _CategoryBadge(count: unreadCount),
        )
      : const SizedBox.shrink();

    if (item.id == 'events') {
      return Consumer(
        builder: (context, ref, _) {
          return SizedBox(
            height: item.height,
            child: DecoratedBox(
              decoration: AppTheme.qfNeoFrame(isLight: isLight),
              child: ClipRRect(
                borderRadius: AppTheme.qfNeoFrameRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventsTeaserCard(
                      onTap: () {
                        ref.read(accessedCategoriesProvider).markAccessed(item.id);
                        final sub = ref.read(subscriptionProvider).value;
                        if (sub != null &&
                            sub.effectiveTier.canViewEvents != true) {
                          showPaywall(context, featureName: 'Events & Pros');
                          return;
                        }
                        onOpen(item.id, item.title);
                      },
                    ),
                    badgeWidget,
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Stack(
      children: [
        _BentoCard(
          title: item.title,
          subtitle: item.subtitle,
          height: item.height,
          media: BentoMediaPools.forId(item.id),
          stagger: Duration(seconds: int.parse(item.delaySeconds)),
          isLight: isLight,
          enableVideo: true,
          onTap: () {
            ref.read(accessedCategoriesProvider).markAccessed(item.id);
            onOpen(item.id, item.title);
          },
        ),
        badgeWidget,
      ],
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

  static const _clarityMatrix = <double>[
    1.14,
    0,
    0,
    0,
    4,
    0,
    1.14,
    0,
    0,
    4,
    0,
    0,
    1.14,
    0,
    4,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
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
                colorFilter: const ColorFilter.matrix(_clarityMatrix),
                child: QuickFilterMedia(
                  sources: widget.media,
                  enableVideo: widget.enableVideo,
                ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0x4D000000),
                      ],
                      stops: [0, 0.82, 1],
                    ),
                  ),
                ),
              ),
              // Open the category from the card body, but leave the bottom-right
              // control stack free so volume/play taps are never stolen.
              Positioned(
                top: 0,
                left: 0,
                right: 52,
                bottom: 52,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  onTapCancel: () => setState(() => _pressed = false),
                  onTap: widget.onTap,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: 8,
                right: 75,
                bottom: 8,
                child: IgnorePointer(
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
                          color: Colors.white.withAlpha(238),
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

String? _featureForBentoId(String id) => switch (id) {
      'property' => 'properties',
      'services' => 'workers',
      'yacht' => 'yachts',
      'motorcycle' => 'motorcycles',
      'bicycle' => 'bicycles',
      'events' => 'events',
      'seekers' => 'seekers',
      'legal' => 'legal',
      'premium' => 'premium',
      _ => null,
    };

bool _bentoFeatureEnabled(AppMarketContext? market, String id) {
  final feature = _featureForBentoId(id);
  if (feature == null || market == null) return true;
  return market.effectiveOpen && market.featureEnabled(feature);
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