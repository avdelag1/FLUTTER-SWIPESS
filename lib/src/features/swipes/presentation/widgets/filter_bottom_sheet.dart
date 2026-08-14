import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/client_filter_preferences_repository.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capacitor ClientFilters — white/light sheet with category picker + detail filters.
class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key, this.asPage = false});

  /// When true, render as a full Cap `/client/filters` page (not a modal).
  final bool asPage;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FilterBottomSheet(),
    );
  }

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  /// null = Cap category selector step
  String? _activeCategory;
  late String _interestType;
  late String? _priceRange;
  late int _minBeds;
  late int _minBaths;
  late bool _furnished;
  late bool _petFriendly;
  late List<String> _propertyTypes;
  late String? _city;
  late double _radiusKm;

  static const _categories = [
    ('property', 'Properties', 'Settle Anywhere', Icons.home_rounded),
    ('motorcycle', 'Motos', 'High Velocity', Icons.two_wheeler_rounded),
    ('bicycle', 'Bikes', 'Urban Agility', Icons.pedal_bike_rounded),
    ('yacht', 'Yachts', 'Open Waters', Icons.sailing_rounded),
    ('worker', 'Workers', 'Elite Skillset', Icons.work_rounded),
    ('buyers', 'Buyers', 'Purchase Ready', Icons.sell_rounded),
    ('renters', 'Renters', 'Looking to Move', Icons.key_rounded),
    ('leads', 'Leads', 'Seeking Workers', Icons.people_rounded),
  ];

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
    _radiusKm = current.radiusKm;
    _hydrateFromCloud();
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
      // Radius isn't part of Cap's persisted columns — keep the session value.
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

  void _apply() {
    final cat = _activeCategory ?? 'property';
    final budget = _budgets.where((b) => b.$1 == _priceRange).firstOrNull;
    final mappedCategory = switch (cat) {
      'buyers' || 'renters' || 'leads' => 'property',
      'worker' => 'worker',
      _ => cat,
    };
    ref.read(swipeFilterProvider.notifier).replace(
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
    // Cap: persist preferences when logged in (best-effort).
    final next = ref.read(swipeFilterProvider);
    ClientFilterPreferencesRepository().upsertFromFilter(next);
    // Force deck reload with new filters.
    ref.invalidate(swipeListingsProvider);
    AppHaptics.medium();
    final title = _categories
            .where((c) => c.$1 == cat)
            .map((c) => c.$2)
            .firstOrNull ??
        'Scan';
    if (widget.asPage) {
      openClientSwipeDeck(
        context,
        categoryId: mappedCategory,
        categoryTitle: title,
        replace: true,
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
      _radiusKm = 50;
    });
    AppHaptics.light();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (widget.asPage) {
      return Scaffold(
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
    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: widget.asPage
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              if (!widget.asPage) ...[
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ] else
                SizedBox(height: MediaQuery.paddingOf(context).top + 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 120),
                  children: [
                    if (_activeCategory == null) ...[
                      _titleBlock(),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.chevron_left_rounded,
                              color: Colors.white),
                          label: Text(
                            'Back',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final cat in _categories) ...[
                        _CategoryCard(
                          icon: cat.$4,
                          title: cat.$2,
                          subtitle: cat.$3,
                          onTap: () {
                            AppHaptics.selection();
                            setState(() => _activeCategory = cat.$1);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ] else ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _activeCategory = null),
                          icon: const Icon(Icons.chevron_left_rounded,
                              color: Colors.white),
                          label: Text(
                            'Back',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final cat in _categories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _Pill(
                                  label: cat.$2,
                                  active: _activeCategory == cat.$1,
                                  onTap: () => setState(
                                      () => _activeCategory = cat.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _detailTitle,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
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
                          color: AppTheme.brandPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.2,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_showsInterest) ...[
                        _sectionLabel('INTEREST'),
                        const SizedBox(height: 10),
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
                                onTap: () =>
                                    setState(() => _interestType = opt.$1),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ],
                      _sectionLabel('BUDGET'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final b in _budgets)
                            _Pill(
                              label: b.$2,
                              active: _priceRange == b.$1,
                              onTap: () => setState(() => _priceRange = b.$1),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (_activeCategory == 'property') ...[
                        _sectionLabel('PROPERTY TYPE'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in ListingTaxonomies.propertyTypes)
                              _Pill(
                                label: t,
                                active: _propertyTypes.contains(t),
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
                        const SizedBox(height: 22),
                        _sectionLabel('MIN BEDROOMS'),
                        const SizedBox(height: 10),
                        _NumberRow(
                          value: _minBeds,
                          max: 6,
                          anyLabel: 'Any',
                          onChanged: (v) => setState(() => _minBeds = v),
                        ),
                        const SizedBox(height: 18),
                        _sectionLabel('MIN BATHROOMS'),
                        const SizedBox(height: 10),
                        _NumberRow(
                          value: _minBaths,
                          max: 5,
                          anyLabel: 'Any',
                          onChanged: (v) => setState(() => _minBaths = v),
                        ),
                        const SizedBox(height: 18),
                        _WhiteToggle(
                          label: 'Furnished',
                          value: _furnished,
                          onChanged: (v) => setState(() => _furnished = v),
                        ),
                        const SizedBox(height: 10),
                        _WhiteToggle(
                          label: 'Pet friendly',
                          value: _petFriendly,
                          onChanged: (v) => setState(() => _petFriendly = v),
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (_activeCategory == 'motorcycle') ...[
                        _sectionLabel('MOTO TYPE'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in ListingTaxonomies.motoTypes)
                              _Pill(
                                label: t,
                                active: _propertyTypes.contains(t),
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
                        const SizedBox(height: 22),
                      ],
                      if (_activeCategory == 'yacht') ...[
                        _sectionLabel('YACHT TYPE'),
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 22),
                      ],
                      if (_activeCategory == 'bicycle') ...[
                        _sectionLabel('BIKE TYPE'),
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 22),
                      ],
                      _sectionLabel('CITY'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in ListingTaxonomies.popularCities)
                            _Pill(
                              label: c,
                              active: _city == c,
                              onTap: () => setState(
                                  () => _city = _city == c ? null : c),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _sectionLabel('RADIUS  ${_radiusKm.round()} KM'),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.brandPrimary,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: AppTheme.brandPrimary,
                          overlayColor: AppTheme.brandPrimary.withAlpha(40),
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
                          color: Colors.white60,
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reset,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0A0A0D),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Reset Parameters',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF4D00),
                                  Color(0xFFEB4898),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4D00).withAlpha(90),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _apply,
                              icon: const Icon(Icons.search_rounded),
                          label: Text(
                            'Apply Filters',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
      case 'leads':
        return 'Leads';
      default:
        return 'Property';
    }
  }

  bool get _showsInterest =>
      _activeCategory == 'property' ||
      _activeCategory == 'motorcycle' ||
      _activeCategory == 'bicycle' ||
      _activeCategory == 'yacht';

  Widget _titleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'SWIPESS ',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.2,
                ),
              ),
              TextSpan(
                text: 'FILTER',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandPrimary,
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
          'Filter Your Best Deal',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.2,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white60,
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      subtitle.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
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
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                )
              : null,
          color: active ? null : Colors.white,
          border: Border.all(
            color: active ? Colors.transparent : Colors.white12,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF4D00).withAlpha(70),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: active ? Colors.white : const Color(0xFF0A0A0D),
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.6,
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
  });

  final int value;
  final int max;
  final String anyLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i <= max; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Pill(
              label: i == 0 ? anyLabel : '$i+',
              active: value == i,
              onTap: () => onChanged(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _WhiteToggle extends StatelessWidget {
  const _WhiteToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.brandPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
