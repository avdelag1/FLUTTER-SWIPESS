import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/client_filter_preferences_repository.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/core/widgets/glass_dropdown_field.dart';

/// Capacitor ClientFilters — category picker + detail filters.
class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key, this.asPage = false});

  /// When true, render as a full Cap `/client/filters` page (not a modal).
  final bool asPage;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterBottomSheet(),
    );
  }

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  /// null = main category selector step. Keeping this in one StatefulWidget is
  /// intentional: Back from a category returns to the exact selector state.
  String? _activeCategory;
  late String _interestType;
  late String? _priceRange;
  late int _minBeds;
  late int _minBaths;
  late bool _furnished;
  late bool _petFriendly;
  late List<String> _propertyTypes;
  late String? _city;
  late final TextEditingController _cityController;
  late double _radiusKm;

  static const _categories = [
    (
      'property',
      'Properties',
      'Settle anywhere',
      Icons.home_rounded,
      Color(0xFFFF2D6F),
    ),
    (
      'motorcycle',
      'Motos',
      'High velocity',
      Icons.two_wheeler_rounded,
      Color(0xFFFF4D6A),
    ),
    (
      'bicycle',
      'Bikes',
      'Urban agility',
      Icons.pedal_bike_rounded,
      Color(0xFF22C55E),
    ),
    (
      'yacht',
      'Yachts',
      'Open waters',
      Icons.sailing_rounded,
      Color(0xFF3B82F6),
    ),
    (
      'worker',
      'Workers',
      'Elite skillset',
      Icons.work_rounded,
      Color(0xFF8B5CF6),
    ),
    (
      'roommates',
      'Roommates',
      'Find people to live with',
      Icons.people_alt_rounded,
      Color(0xFF7C3AED),
    ),
    (
      'buyers',
      'Buyers',
      'Purchase ready',
      Icons.sell_rounded,
      Color(0xFF60A5FA),
    ),
    (
      'renters',
      'Renters',
      'Looking to move',
      Icons.key_rounded,
      Color(0xFFE4007C),
    ),
    (
      'seekers',
      'Hire workers',
      'Browse workers to hire',
      Icons.groups_rounded,
      Color(0xFFEB4898),
    ),
  ];

  Color get _accent {
    for (final c in _categories) {
      if (c.$1 == _activeCategory) return c.$5;
    }
    return const Color(0xFFFF2D6F);
  }

  static const _rentBudgets = [
    ('250-500', '\$250 - \$500/mo', 250.0, 500.0),
    ('500-1000', '\$500 - \$1,000/mo', 500.0, 1000.0),
    ('1000-3000', '\$1,000 - \$3,000/mo', 1000.0, 3000.0),
    ('3000-5000', '\$3,000 - \$5,000/mo', 3000.0, 5000.0),
    ('5000+', '\$5,000+/mo', 5000.0, 50000.0),
  ];

  static const _buyBudgets = [
    ('50k-100k', '\$50K - \$100K', 50000.0, 100000.0),
    ('100k-250k', '\$100K - \$250K', 100000.0, 250000.0),
    ('250k-500k', '\$250K - \$500K', 250000.0, 500000.0),
    ('500k-1m', '\$500K - \$1M', 500000.0, 1000000.0),
    ('1m+', '\$1M+', 1000000.0, 50000000.0),
  ];

  static const _motoRent = [
    ('50-150', '\$50 - \$150/d', 50.0, 150.0),
    ('150-300', '\$150 - \$300/d', 150.0, 300.0),
    ('300-500', '\$300 - \$500/d', 300.0, 500.0),
    ('500+', '\$500+/d', 500.0, 5000.0),
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(swipeFilterProvider);
    _activeCategory = null;
    _interestType = current.interestType;
    _priceRange = current.priceRangeLabel;
    _minBeds = current.minBeds ?? 0;
    _minBaths = current.minBaths ?? 0;
    _furnished = current.furnished == true;
    _petFriendly = current.petFriendly == true;
    _propertyTypes = List.of(current.propertyTypes);
    _city = current.city;
    _cityController = TextEditingController(text: current.city);
    _radiusKm = current.radiusKm;
    _hydrateFromCloud();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _hydrateFromCloud() async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    final row = await ClientFilterPreferencesRepository().fetchOwn();
    if (!mounted || row == null) return;
    final remote = ClientFilterPreferencesRepository().toFilter(row);
    if (remote == null) return;
    setState(() {
      _interestType = remote.interestType;
      _priceRange = remote.priceRangeLabel;
      _minBeds = remote.minBeds ?? 0;
      _minBaths = remote.minBaths ?? 0;
      _furnished = remote.furnished == true;
      _petFriendly = remote.petFriendly == true;
      _propertyTypes = List.of(remote.propertyTypes);
      _city = remote.city;
    });
  }

  List<(String, String, double, double)> get _budgets {
    final cat = _activeCategory;
    if (cat == 'motorcycle' || cat == 'bicycle' || cat == 'yacht') {
      if (_interestType == 'sale') return _buyBudgets;
      return _motoRent;
    }
    if (_interestType == 'sale') return _buyBudgets;
    return _rentBudgets;
  }

  void _openRoommates() {
    AppHaptics.medium();
    if (!widget.asPage) Navigator.of(context).pop();
    context.push(AppPaths.exploreRoommates);
  }

  void _openCategory(String id) {
    if (id == 'roommates') {
      _openRoommates();
      return;
    }
    setState(() => _activeCategory = id);
  }

  void _apply() {
    final cat = _activeCategory ?? 'property';
    if (cat == 'roommates') {
      _openRoommates();
      return;
    }
    final budget = _budgets.where((b) => b.$1 == _priceRange).firstOrNull;
    final mappedCategory = switch (cat) {
      'buyers' || 'renters' => 'property',
      'seekers' => 'worker',
      'worker' => 'worker',
      _ => cat,
    };
    ref
        .read(swipeFilterProvider.notifier)
        .replace(
          SwipeFilter(
            category: mappedCategory,
            interestType: cat == 'buyers'
                ? 'sale'
                : cat == 'renters'
                ? 'rent'
                : _interestType,
            minPrice: budget?.$3,
            maxPrice: budget?.$4,
            priceRangeLabel: _priceRange,
            minBeds: _minBeds > 0 ? _minBeds : null,
            minBaths: _minBaths > 0 ? _minBaths : null,
            furnished: _furnished ? true : null,
            petFriendly: _petFriendly ? true : null,
            propertyTypes: _propertyTypes,
            city: _city,
            radiusKm: _radiusKm,
          ),
        );
    final next = ref.read(swipeFilterProvider);
    final preferences = ClientFilterPreferencesRepository();
    // Keep Apply instant. Persist search filters in the background, but never
    // change the user's public Buyer/Renter/Seeker visibility from browsing.
    unawaited(preferences.upsertFromFilter(next));
    ref.invalidate(swipeListingsProvider);
    AppHaptics.medium();
    final title =
        _categories.where((c) => c.$1 == cat).map((c) => c.$2).firstOrNull ??
        'Scan';
    if (widget.asPage) {
      // Push, never replace: Back from the deck must restore this exact filter
      // page and the category the user was editing.
      openClientSwipeDeck(
        context,
        categoryId: mappedCategory,
        categoryTitle: title,
        replace: false,
      );
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filters applied. Your deck is updating.')),
    );
  }

  void _reset() {
    ref.read(swipeFilterProvider.notifier).reset();
    setState(() {
      _activeCategory = null;
      _interestType = 'both';
      _priceRange = null;
      _minBeds = 0;
      _minBaths = 0;
      _furnished = false;
      _petFriendly = false;
      _propertyTypes = [];
      _city = null;
      _cityController.clear();
      _radiusKm = 50;
    });
    AppHaptics.light();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (widget.asPage) {
      return Scaffold(
        backgroundColor: MatteSurface.canvas(context),
        body: _filterBody(context, bottom, null),
      );
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return _filterBody(context, bottom, scrollController);
      },
    );
  }

  Widget _filterBody(
    BuildContext context,
    double bottom,
    ScrollController? scrollController,
  ) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final canvas = MatteSurface.canvas(context);
    final accent = _accent;
    final actionInk = accent.computeLuminance() > 0.72
        ? Colors.black
        : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: canvas,
        borderRadius: widget.asPage
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          if (!widget.asPage) ...[
            SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: muted.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ] else
            SizedBox(height: MediaQuery.paddingOf(context).top + 8),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 112),
              children: [
                if (_activeCategory == null) ...[
                  _titleBlock(context),
                  SizedBox(height: 8),
                  if (!widget.asPage)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.chevron_left_rounded, color: ink),
                        label: Text(
                          'Back',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 8),
                  for (final cat in _categories) ...[
                    _CategoryCard(
                      icon: cat.$4,
                      title: cat.$2,
                      subtitle: cat.$3,
                      color: cat.$5,
                      onTap: () {
                        AppHaptics.selection();
                        _openCategory(cat.$1);
                      },
                    ),
                    SizedBox(height: 12),
                  ],
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _activeCategory = null),
                      icon: Icon(Icons.chevron_left_rounded, color: ink),
                      label: Text(
                        'Back',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final cat in _categories)
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: _Pill(
                              label: cat.$2,
                              active: _activeCategory == cat.$1,
                              accent: cat.$5,
                              onTap: () => _openCategory(cat.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    _detailTitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -1.6,
                      height: 0.95,
                    ),
                  ),
                  Text(
                    'FILTERS',
                    style: GoogleFonts.plusJakartaSans(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.2,
                    ),
                  ),
                  SizedBox(height: 22),
                  if (_showsInterest) ...[
                    _sectionLabel(context, 'INTEREST'),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final opt in const [
                          ('rent', 'For Rent'),
                          ('sale', 'For Sale'),
                          ('both', 'Both'),
                        ])
                          _Pill(
                            label: opt.$2,
                            active: _interestType == opt.$1,
                            accent: accent,
                            onTap: () => setState(() => _interestType = opt.$1),
                          ),
                      ],
                    ),
                    SizedBox(height: 22),
                  ],
                  _sectionLabel(context, 'BUDGET'),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in _budgets)
                        _Pill(
                          label: b.$2,
                          active: _priceRange == b.$1,
                          accent: accent,
                          onTap: () => setState(() => _priceRange = b.$1),
                        ),
                    ],
                  ),
                  SizedBox(height: 22),
                  if (_activeCategory == 'property') ...[
                    _sectionLabel(context, 'PROPERTY TYPE'),
                    SizedBox(height: 10),
                    GlassDropdownField(
                      label: 'Property type',
                      options: ListingTaxonomies.propertyTypes,
                      multi: true,
                      selectedValues: _propertyTypes,
                      hint: 'All types (tap to select)',
                      icon: Icons.home_work_rounded,
                      onChanged: (val) {
                        setState(() {
                          _propertyTypes = List.from(val);
                        });
                      },
                    ),
                    SizedBox(height: 22),
                    _sectionLabel(context, 'MIN BEDROOMS'),
                    SizedBox(height: 10),
                    _NumberRow(
                      value: _minBeds,
                      max: 6,
                      anyLabel: 'Any',
                      accent: accent,
                      onChanged: (v) => setState(() => _minBeds = v),
                    ),
                    SizedBox(height: 18),
                    _sectionLabel(context, 'MIN BATHROOMS'),
                    SizedBox(height: 10),
                    _NumberRow(
                      value: _minBaths,
                      max: 5,
                      anyLabel: 'Any',
                      accent: accent,
                      onChanged: (v) => setState(() => _minBaths = v),
                    ),
                    SizedBox(height: 18),
                    _FilterToggle(
                      label: 'Furnished',
                      value: _furnished,
                      accent: accent,
                      onChanged: (v) => setState(() => _furnished = v),
                    ),
                    SizedBox(height: 10),
                    _FilterToggle(
                      label: 'Pet friendly',
                      value: _petFriendly,
                      accent: accent,
                      onChanged: (v) => setState(() => _petFriendly = v),
                    ),
                    SizedBox(height: 22),
                  ],
                  if (_activeCategory == 'motorcycle') ...[
                    _sectionLabel(context, 'MOTO TYPE'),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in ListingTaxonomies.motoTypes)
                          _Pill(
                            label: t,
                            active: _propertyTypes.contains(t),
                            accent: accent,
                            onTap: () => setState(() {
                              if (_propertyTypes.contains(t)) {
                                _propertyTypes.remove(t);
                              } else {
                                _propertyTypes.add(t);
                              }
                            }),
                          ),
                      ],
                    ),
                    SizedBox(height: 22),
                  ],
                  if (_activeCategory == 'yacht') ...[
                    _sectionLabel(context, 'YACHT TYPE'),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in const [
                          'Motor yacht',
                          'Sailboat',
                          'Catamaran',
                          'Super yacht',
                          'Pontoon',
                        ])
                          _Pill(
                            label: t,
                            active: _propertyTypes.contains(t),
                            accent: accent,
                            onTap: () => setState(() {
                              if (_propertyTypes.contains(t)) {
                                _propertyTypes.remove(t);
                              } else {
                                _propertyTypes.add(t);
                              }
                            }),
                          ),
                      ],
                    ),
                    SizedBox(height: 22),
                  ],
                  if (_activeCategory == 'bicycle') ...[
                    _sectionLabel(context, 'BIKE TYPE'),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in const [
                          'Road',
                          'Mountain',
                          'Hybrid',
                          'Electric',
                          'Cruiser',
                          'BMX',
                          'Folding',
                        ])
                          _Pill(
                            label: t,
                            active: _propertyTypes.contains(t),
                            accent: accent,
                            onTap: () => setState(() {
                              if (_propertyTypes.contains(t)) {
                                _propertyTypes.remove(t);
                              } else {
                                _propertyTypes.add(t);
                              }
                            }),
                          ),
                      ],
                    ),
                    SizedBox(height: 22),
                  ],
                  _sectionLabel(context, 'CITY'),
                  SizedBox(height: 10),
                  GlassTextField(
                    controller: _cityController,
                    hint: 'Type a city name...',
                    icon: Icons.location_city_rounded,
                    onChanged: (val) {
                      setState(() {
                        _city = val.trim().isEmpty ? null : val.trim();
                      });
                    },
                  ),
                  SizedBox(height: 22),
                  _sectionLabel(context, 'RADIUS  ${_radiusKm.round()} KM'),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accent,
                      inactiveTrackColor: hairline,
                      thumbColor: accent,
                      overlayColor: accent.withAlpha(40),
                    ),
                    child: Slider(
                      value: _radiusKm,
                      min: 5,
                      max: 200,
                      divisions: 39,
                      onChanged: (v) => setState(() => _radiusKm = v),
                    ),
                  ),
                  Text(
                    'Radius filtering uses your current GPS or selected location.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_activeCategory != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ink,
                          side: BorderSide(color: hairline),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Reset',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              Color.lerp(
                                    accent,
                                    const Color(0xFFEB4898),
                                    0.55,
                                  ) ??
                                  accent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(90),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _apply,
                          icon: Icon(Icons.search_rounded),
                          label: Text(
                            'Apply Filters',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: actionInk,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get _detailTitle {
    switch (_activeCategory) {
      case 'motorcycle':
        return 'Moto';
      case 'bicycle':
        return 'Bicycle';
      case 'yacht':
        return 'Yacht';
      case 'worker':
        return 'Worker';
      case 'buyers':
        return 'Buyers';
      case 'renters':
        return 'Renters';
      case 'seekers':
        return 'Seekers';
      default:
        return 'Property';
    }
  }

  bool get _showsInterest =>
      _activeCategory == 'property' ||
      _activeCategory == 'motorcycle' ||
      _activeCategory == 'bicycle' ||
      _activeCategory == 'yacht';

  Widget _titleBlock(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'SWIPESS ',
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.2,
                ),
              ),
              TextSpan(
                text: 'FILTER',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFFF2D6F),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.2,
                ),
              ),
            ],
          ),
        ),
        Text(
          'Pick a category — each one has its own filters',
          style: GoogleFonts.plusJakartaSans(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: MatteSurface.muted(context),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 88,
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: MatteSurface.cardFill(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(36),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active ? accent : Colors.transparent,
          border: Border.all(
            color: active ? accent : MatteSurface.hairline(context),
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: active ? Colors.white : ink,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.value,
    required this.max,
    required this.anyLabel,
    required this.onChanged,
    required this.accent,
  });

  final int value;
  final int max;
  final String anyLabel;
  final ValueChanged<int> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i <= max; i++) ...[
          if (i > 0) SizedBox(width: 6),
          Expanded(
            child: _Pill(
              label: i == 0 ? anyLabel : '$i+',
              active: value == i,
              accent: accent,
              onTap: () => onChanged(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
