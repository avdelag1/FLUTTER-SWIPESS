import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/performance/app_refresh_service.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/bento_media_pools.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/dashboard_discovery_menu_actions_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/events_teaser_card.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/quick_filter_media.dart';
import 'package:flutter_swipes/src/features/map/data/mapbox_place_search.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:flutter_swipes/src/features/session/domain/app_market_context.dart';
import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/paywall_screen.dart';
import 'package:flutter_swipes/src/features/events/presentation/utils/open_events_feed.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
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
    'services': 'worker',
    'yacht': 'yacht',
    'motorcycle': 'motorcycle',
    'bicycle': 'bicycle',
  };

  DateTime getLastAccessed(String id) {
    final str = prefs.getString('bento_last_accessed_$id');
    if (str != null) return DateTime.parse(str).toUtc();
    return DateTime.now().toUtc().subtract(const Duration(days: 7));
  }

  try {
    final rows = await client
        .from('listings')
        .select('category, created_at, owner_id')
        .eq('is_active', true)
        .eq('status', 'active');

    final currentUserId = client.auth.currentUser?.id;
    final listings = (rows as List)
        .where(
          (row) =>
              currentUserId == null ||
              row['owner_id']?.toString() != currentUserId,
        )
        .toList(growable: false);

    for (final entry in categoryMap.entries) {
      final lastAccessed = getLastAccessed(entry.key);
      int count = 0;
      for (final row in listings) {
        final cat = row['category']?.toString();
        if (cat == entry.value) {
          final createdAt = DateTime.tryParse(
            row['created_at']?.toString() ?? '',
          )?.toUtc();
          if (createdAt != null && createdAt.isAfter(lastAccessed)) {
            count++;
          }
        }
      }
      counts[entry.key] = count;
    }

    try {
      var peopleRows =
          await client
                  .from('client_profiles')
                  .select('user_id, intentions, updated_at')
                  .order('updated_at', ascending: false)
              as List;
      if (currentUserId != null) {
        peopleRows = peopleRows
            .where((row) => row['user_id']?.toString() != currentUserId)
            .toList(growable: false);
        if (peopleRows.isNotEmpty) {
          try {
            final visibleData = await client.rpc(
              'rpc_filter_discoverable_profile_ids',
              params: {
                'p_ids': peopleRows
                    .map((row) => row['user_id']?.toString())
                    .whereType<String>()
                    .toList(growable: false),
              },
            );
            if (visibleData is List) {
              final visible = visibleData.map((e) => e.toString()).toSet();
              peopleRows = peopleRows
                  .where((row) => visible.contains(row['user_id']?.toString()))
                  .toList(growable: false);
            } else {
              peopleRows = const [];
            }
          } catch (_) {
            peopleRows = const [];
          }
        }
      }
      for (final id in const ['buyers', 'renters', 'seekers']) {
        final lastAccessed = getLastAccessed(id);
        counts[id] = peopleRows.where((row) {
          if (!_peopleQuickFilterMatches(row['intentions'], id)) return false;
          final updatedAt = DateTime.tryParse(
            row['updated_at']?.toString() ?? '',
          )?.toUtc();
          return updatedAt != null && updatedAt.isAfter(lastAccessed);
        }).length;
      }
    } catch (_) {}

    try {
      final eventRows = await client
          .from('events')
          .select('created_at')
          .eq('is_published', true);
      final evLast = getLastAccessed('events');
      counts['events'] = (eventRows as List).where((r) {
        final dt = DateTime.tryParse(
          r['created_at']?.toString() ?? '',
        )?.toUtc();
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
    await prefs.setString(
      'bento_last_accessed_$id',
      DateTime.now().toUtc().toIso8601String(),
    );
    ref.invalidate(newItemsCountProvider);
  }
}

final accessedCategoriesProvider = Provider(
  (ref) => AccessedCategoriesManager(ref),
);

bool _peopleQuickFilterMatches(dynamic rawIntentions, String id) {
  if (rawIntentions is! List) return false;
  final intentions = rawIntentions
      .map((e) => e.toString().trim().toLowerCase())
      .where((e) => e.isNotEmpty);
  switch (id) {
    case 'buyers':
      return intentions.contains('buyer');
    case 'renters':
      return intentions.contains('renter');
    case 'seekers':
      return intentions.contains('seeker');
    default:
      return false;
  }
}

List<String> _peoplePreviewImages(Map<String, dynamic> row) {
  final images = <String>[];
  final raw = row['profile_images'];
  if (raw is List) {
    images.addAll(
      raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).take(3),
    );
  }
  final avatar = row['vap_avatar']?.toString().trim() ?? '';
  if (images.isEmpty && avatar.isNotEmpty) images.add(avatar);
  return images;
}

final quickFilterPeoplePreviewProvider =
    FutureProvider.family<List<String>, String>((ref, id) async {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;
      var rows =
          await client
                  .from('client_profiles')
                  .select(
                    'user_id, profile_images, vap_avatar, intentions, updated_at',
                  )
                  .order('updated_at', ascending: false)
                  .limit(48)
              as List;

      rows = rows
          .where(
            (row) =>
                row is Map<String, dynamic> &&
                row['user_id']?.toString() != currentUserId &&
                _peopleQuickFilterMatches(row['intentions'], id),
          )
          .toList(growable: false);

      if (currentUserId != null && rows.isNotEmpty) {
        try {
          final visibleData = await client.rpc(
            'rpc_filter_discoverable_profile_ids',
            params: {
              'p_ids': rows
                  .map((row) => row['user_id']?.toString())
                  .whereType<String>()
                  .toList(growable: false),
            },
          );
          if (visibleData is List) {
            final visible = visibleData.map((e) => e.toString()).toSet();
            rows = rows
                .where((row) => visible.contains(row['user_id']?.toString()))
                .toList(growable: false);
          } else {
            rows = const [];
          }
        } catch (_) {
          rows = const [];
        }
      }

      final seen = <String>{};
      final media = <String>[];
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        for (final image in _peoplePreviewImages(row)) {
          if (seen.add(image)) media.add(image);
          if (media.length >= 12) return media;
        }
      }
      return media;
    });

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
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
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(dashboardDiscoveryMenuActionsProvider.notifier)
          .register(
            openLocation: _pickCity,
            openDates: _pickDates,
            openGuests: _pickGuests,
          );
    });
  }

  @override
  void dispose() {
    ref.read(dashboardDiscoveryMenuActionsProvider.notifier).clear();
    _scroll.dispose();
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

  void _openCategory(String id, String title, String? preferredListingId) {
    final feature = _featureForBentoId(id);
    if (feature != null && !_marketAllows(feature)) {
      _showMarketUnavailable();
      return;
    }

    switch (id) {
      case 'events':
        openEventsFeed(context, ref: ref);
        return;
      case 'buyers':
        context.go(AppPaths.exploreBuyers);
        return;
      case 'renters':
        context.go(AppPaths.exploreRenters);
        return;
      case 'seekers':
        context.go(AppPaths.explorePeopleSeekers);
        return;
      case 'jets':
        context.go(AppPaths.map);
        return;
      case 'legal':
        context.go(AppPaths.clientLegal);
        return;
      case 'premium':
        context.go(AppPaths.subscriptionPackages);
        return;
      default:
        openClientSwipeDeck(
          context,
          categoryId: id,
          categoryTitle: title,
          preferredListingId: preferredListingId,
        );
    }
  }

  void _openAiSearch([String? query]) {
    if (!_marketAllows('ai')) {
      _showMarketUnavailable();
      return;
    }
    final subscription = ref.read(subscriptionProvider).value;
    if (subscription != null && subscription.effectiveTier.canUseAI != true) {
      showPaywall(context, featureName: 'SWIPESS AI');
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
                  margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                      SizedBox(height: 10),
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ink.withAlpha(55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(18, 12, 10, 8),
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
                                  SizedBox(height: 2),
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
                        padding: EdgeInsets.fromLTRB(14, 4, 14, 8),
                        child: TextField(
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: true,
                          onSubmitted: (_) => runSearch(),
                          decoration: InputDecoration(
                            hintText: 'Search Texas, Nashville, Alaska…',
                            prefixIcon: Icon(Icons.travel_explore_rounded),
                            suffixIcon: IconButton(
                              tooltip: 'Search world',
                              onPressed: searching ? null : runSearch,
                              icon: Icon(Icons.search_rounded),
                            ),
                            filled: true,
                            fillColor: isLight
                                ? Colors.black.withAlpha(7)
                                : Colors.white.withAlpha(13),
                            contentPadding: EdgeInsets.symmetric(
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
                          padding: EdgeInsets.fromLTRB(16, 2, 16, 8),
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
                          padding: EdgeInsets.fromLTRB(10, 0, 10, 14),
                          children: [
                            if (searchResults.isNotEmpty) ...[
                              Padding(
                                padding: EdgeInsets.fromLTRB(8, 8, 8, 5),
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
                                  leading: Icon(
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
                                  trailing: Icon(
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
                              SizedBox(height: 2),
                            ],
                            Padding(
                              padding: EdgeInsets.fromLTRB(8, 8, 8, 5),
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
                                        ? Icon(
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
                margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
                padding: EdgeInsets.fromLTRB(18, 12, 18, 18),
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
                    SizedBox(height: 16),
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
                              SizedBox(height: 3),
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
                          icon: Icon(Icons.remove_rounded),
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
                          icon: Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, guests),
                        child: Text('Apply'),
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
    final safe = MediaQuery.paddingOf(context);
    // Dock floats at bottom:16 with a 52px pill + safe area; extra room so the
    // last quick-filter row clears the dock even with bounce overscroll.
    final bottomScrollPad = safe.bottom + 16 + 52 + 56;
    const scrollPhysics = AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    );

    return Container(
      color: isLight ? AppTheme.lightDashBg : const Color(0xFF0D1015),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          color: AppTheme.brandAccent2,
          backgroundColor: isLight ? Colors.white : const Color(0xFF171B22),
          elevation: 2,
          displacement: 56,
          edgeOffset: 8,
          strokeWidth: 2.4,
          onRefresh: () async {
            await AppRefreshService.refreshDashboard(ref);
            if (mounted) AppHaptics.light();
          },
          child: CustomScrollView(
            controller: _scroll,
            scrollCacheExtent: const .pixels(900),
            physics: scrollPhysics,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 48, 16, 2),
                  child: GlowSearchBar(
                    hint:
                        market != null &&
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
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomScrollPad),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 2, 8, 8),
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
                        SizedBox(width: 8),
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
  final void Function(String id, String title, String? preferredListingId)
  onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: 8),
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
  final void Function(String id, String title, String? preferredListingId)
  onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(newItemsCountProvider).value ?? const {};
    final unreadCount = counts[item.id] ?? 0;

    // Events keeps its continuous live teaser. Listing quick filters use the
    // real media from each listing: video when that listing has one, otherwise
    // its cover photo. A shared round-robin clock lets only one non-Events card
    // move at a time.
    const listingPreviewQuickFilters = <String>{
      'property',
      'services',
      'yacht',
      'motorcycle',
      'bicycle',
    };
    final isListingPreviewQuickFilter = listingPreviewQuickFilters.contains(
      item.id,
    );
    const peoplePreviewQuickFilters = <String>{'buyers', 'renters', 'seekers'};
    final isPeoplePreviewQuickFilter = peoplePreviewQuickFilters.contains(
      item.id,
    );
    final peoplePreviewAsync = isPeoplePreviewQuickFilter
        ? ref.watch(quickFilterPeoplePreviewProvider(item.id))
        : null;
    final peoplePreviewMedia = peoplePreviewAsync?.value ?? const <String>[];
    final peoplePreviewResolved = peoplePreviewAsync == null
        ? true
        : peoplePreviewAsync.when(
            data: (_) => true,
            error: (_, __) => true,
            loading: () => false,
          );
    final previewAsync = isListingPreviewQuickFilter
        ? ref.watch(quickFilterPreviewListingsProvider(item.id))
        : null;
    final previewListings = previewAsync?.value ?? const <Listing>[];
    final previewResolved = previewAsync == null
        ? true
        : previewAsync.when(
            data: (_) => true,
            error: (_, __) => true,
            loading: () => false,
          );
    final seenPreviewUrls = <String>{};
    final sourceListingIds = <String, String>{};
    final sourceImageListingIds = <String, String>{};
    final videoPosterUrls = <String, String>{};
    final listingPreviewMedia = <String>[];

    // Premium/video listings lead the category preview. Each listing contributes
    // exactly one dashboard source: its video if present, otherwise its cover.
    // That prevents a video listing from being silently replaced by its photo.
    final orderedPreviewListings = <Listing>[
      ...previewListings.where(
        (listing) => (listing.videoUrl ?? '').trim().isNotEmpty,
      ),
      ...previewListings.where(
        (listing) => (listing.videoUrl ?? '').trim().isEmpty,
      ),
    ];
    for (final listing in orderedPreviewListings) {
      final video = (listing.videoUrl ?? '').trim();
      final image = listing.primaryImage?.trim() ?? '';
      final source = video.isNotEmpty ? video : image;
      if (source.isEmpty || !seenPreviewUrls.add(source)) continue;
      listingPreviewMedia.add(source);
      if (video.isNotEmpty) {
        sourceListingIds[video] = listing.id;
        if (image.isNotEmpty) videoPosterUrls[video] = image;
      } else {
        sourceImageListingIds[source] = listing.id;
      }
    }
    final liveListingMedia = isPeoplePreviewQuickFilter
        ? peoplePreviewMedia.isNotEmpty
              ? peoplePreviewMedia
              : !peoplePreviewResolved
              ? const <String>[]
              : BentoMediaPools.forId(item.id)
        : listingPreviewMedia.isNotEmpty
        ? listingPreviewMedia
        : isListingPreviewQuickFilter && !previewResolved
        ? const <String>[]
        : BentoMediaPools.forId(item.id);

    final badgeWidget = unreadCount > 0
        ? Positioned(
            top: 10,
            right: 10,
            child: IgnorePointer(child: _CategoryBadge(count: unreadCount)),
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
                        ref
                            .read(accessedCategoriesProvider)
                            .markAccessed(item.id);
                        final sub = ref.read(subscriptionProvider).value;
                        if (sub != null &&
                            sub.effectiveTier.canViewEvents != true) {
                          showPaywall(context, featureName: 'Events & Pros');
                          return;
                        }
                        onOpen(item.id, item.title, null);
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
          media: liveListingMedia,
          isLight: isLight,
          enableVideo: isListingPreviewQuickFilter,
          rotateSlot: item.index - 1,
          slotCount: _bentoItems.length - 1,
          sourceListingIds: sourceListingIds,
          sourceImageListingIds: sourceImageListingIds,
          videoPosterUrls: videoPosterUrls,
          handoffCategoryId: isListingPreviewQuickFilter ? item.id : null,
          onTap: (listingId) {
            ref.read(accessedCategoriesProvider).markAccessed(item.id);
            onOpen(item.id, item.title, listingId);
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
    required this.isLight,
    required this.onTap,
    this.enableVideo = true,
    this.rotateSlot = 0,
    this.slotCount = 1,
    this.sourceListingIds = const <String, String>{},
    this.sourceImageListingIds = const <String, String>{},
    this.videoPosterUrls = const <String, String>{},
    this.handoffCategoryId,
  });

  final String title;
  final String subtitle;
  final double height;
  final List<String> media;
  final bool isLight;
  final ValueChanged<String?> onTap;
  final bool enableVideo;
  final int rotateSlot;
  final int slotCount;
  final Map<String, String> sourceListingIds;
  final Map<String, String> sourceImageListingIds;
  final Map<String, String> videoPosterUrls;
  final String? handoffCategoryId;

  @override
  State<_BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<_BentoCard> {
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
      scale: 1,
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
                  rotateSlot: widget.rotateSlot,
                  slotCount: widget.slotCount,
                  enableVideo: widget.enableVideo,
                  showMute: widget.enableVideo,
                  sourceListingIds: widget.sourceListingIds,
                  sourceImageListingIds: widget.sourceImageListingIds,
                  videoPosterUrls: widget.videoPosterUrls,
                  handoffCategoryId: widget.handoffCategoryId,
                  onOpen: widget.onTap,
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
              // Body taps are handled inside QuickFilterMedia: left/right change media
              // and the center always opens the exact listing.
              Positioned(
                left: 8,
                right: 75,
                bottom: 8,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          softWrap: false,
                          style: AppTheme.displayItalic.copyWith(
                            fontSize: 12,
                            letterSpacing: 1.6,
                            height: 1.1,
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
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
  });

  final int index;
  final String id;
  final String title;
  final String subtitle;
  final double height;
}

String? _featureForBentoId(String id) => switch (id) {
  'property' => 'properties',
  'services' => 'workers',
  'yacht' => 'yachts',
  'motorcycle' => 'motorcycles',
  'bicycle' => 'bicycles',
  'events' => 'events',
  'buyers' => 'properties',
  'renters' => 'properties',
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
    id: 'events',
    title: 'EVENTS LIVE',
    subtitle: 'Swipe event videos · tap to open',
    height: 360,
  ),
  _BentoItemData(
    index: 1,
    id: 'property',
    title: 'PROPERTIES',
    subtitle: 'Listings to buy or rent',
    height: 320,
  ),
  _BentoItemData(
    index: 2,
    id: 'services',
    title: 'WORKERS',
    subtitle: 'Find people offering services',
    height: 360,
  ),
  _BentoItemData(
    index: 3,
    id: 'yacht',
    title: 'YACHTS',
    subtitle: 'Yachts & boats to charter or buy',
    height: 300,
  ),
  _BentoItemData(
    index: 4,
    id: 'buyers',
    title: 'BUYERS',
    subtitle: 'People actively looking to buy',
    height: 300,
  ),
  _BentoItemData(
    index: 5,
    id: 'motorcycle',
    title: 'MOTORCYCLES',
    subtitle: 'Motorcycles for sale or rent',
    height: 320,
  ),
  _BentoItemData(
    index: 6,
    id: 'renters',
    title: 'RENTERS',
    subtitle: 'People actively looking to rent',
    height: 320,
  ),
  _BentoItemData(
    index: 7,
    id: 'bicycle',
    title: 'BICYCLES',
    subtitle: 'Bicycles and e-bikes',
    height: 300,
  ),
  _BentoItemData(
    index: 8,
    id: 'seekers',
    title: 'SEEKERS',
    subtitle: 'People actively looking to hire workers',
    height: 340,
  ),
  _BentoItemData(
    index: 9,
    id: 'legal',
    title: 'LEGAL SERVICES',
    subtitle: 'Hire a top tier lawyer',
    height: 300,
  ),
  _BentoItemData(
    index: 10,
    id: 'premium',
    title: 'PREMIUM',
    subtitle: 'Video promotion, AI, Legal & more',
    height: 320,
  ),
  _BentoItemData(
    index: 11,
    id: 'jets',
    title: 'JETS',
    subtitle: 'Private aviation on the live map',
    height: 280,
  ),
];
