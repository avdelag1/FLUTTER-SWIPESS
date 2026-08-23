import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';

class AdminGeoMarketsScreen extends ConsumerStatefulWidget {
  const AdminGeoMarketsScreen({super.key});

  @override
  ConsumerState<AdminGeoMarketsScreen> createState() =>
      _AdminGeoMarketsScreenState();
}

class _AdminGeoMarketsScreenState extends ConsumerState<AdminGeoMarketsScreen> {
  PassportCity? _selectedCity;

  final Map<String, Map<String, bool>> _marketConfig = {};

  final _allCategories = <_GeoCategory>[
    // MOBILITY & TRANSPORT
    _GeoCategory(
      'properties',
      'Properties & Rentals',
      'mobility',
      Icons.home_work_rounded,
    ),
    _GeoCategory('yachts', 'Yachts & Boats', 'mobility', Icons.sailing_rounded),
    _GeoCategory(
      'exotic_cars',
      'Exotic Cars',
      'mobility',
      Icons.directions_car_rounded,
    ),
    _GeoCategory(
      'private_jets',
      'Private Jets & Helis',
      'mobility',
      Icons.flight_takeoff_rounded,
    ),
    _GeoCategory(
      'motorcycles',
      'Motorcycles',
      'mobility',
      Icons.two_wheeler_rounded,
    ),
    _GeoCategory(
      'bicycles',
      'Bicycles & Scooters',
      'mobility',
      Icons.pedal_bike_rounded,
    ),
    _GeoCategory(
      'atv_quads',
      'ATVs & Quads',
      'mobility',
      Icons.agriculture_rounded,
    ),
    _GeoCategory(
      'golf_carts',
      'Golf Carts',
      'mobility',
      Icons.electric_car_rounded,
    ),
    _GeoCategory(
      'chauffeurs',
      'Chauffeurs & Limos',
      'mobility',
      Icons.airport_shuttle_rounded,
    ),

    // WORKERS & PROS
    _GeoCategory(
      'cleaners',
      'Cleaning Staff',
      'workers',
      Icons.cleaning_services_rounded,
    ),
    _GeoCategory(
      'maintenance',
      'Maintenance',
      'workers',
      Icons.build_circle_rounded,
    ),
    _GeoCategory(
      'security',
      'Security & Bodyguards',
      'workers',
      Icons.security_rounded,
    ),
    _GeoCategory(
      'translators',
      'Translators / Guides',
      'workers',
      Icons.translate_rounded,
    ),
    _GeoCategory(
      'chefs',
      'Private Chefs',
      'workers',
      Icons.restaurant_menu_rounded,
    ),
    _GeoCategory(
      'bartenders',
      'Bartenders & Mixologists',
      'workers',
      Icons.local_bar_rounded,
    ),
    _GeoCategory(
      'nannies',
      'Nannies & Babysitters',
      'workers',
      Icons.child_care_rounded,
    ),

    // BEAUTY, HEALTH & STYLE
    _GeoCategory('massage', 'Massage Therapists', 'beauty', Icons.spa_rounded),
    _GeoCategory(
      'makeup_artists',
      'Makeup Artists',
      'beauty',
      Icons.face_retouching_natural_rounded,
    ),
    _GeoCategory(
      'hair_stylists',
      'Hair Stylists & Colorists',
      'beauty',
      Icons.content_cut_rounded,
    ),
    _GeoCategory(
      'personal_trainers',
      'Personal Trainers',
      'beauty',
      Icons.fitness_center_rounded,
    ),
    _GeoCategory(
      'personal_shoppers',
      'Personal Shoppers & Stylists',
      'beauty',
      Icons.checkroom_rounded,
    ),

    // EXPERIENCES & OUTDOORS
    _GeoCategory(
      'surf_lessons',
      'Surf Instructors',
      'experiences',
      Icons.surfing_rounded,
    ),
    _GeoCategory(
      'scuba',
      'Scuba & Freediving',
      'experiences',
      Icons.scuba_diving_rounded,
    ),
    _GeoCategory(
      'fishing',
      'Fishing Charters',
      'experiences',
      Icons.phishing_rounded,
    ),
    _GeoCategory(
      'ski',
      'Ski & Snowboard',
      'experiences',
      Icons.downhill_skiing_rounded,
    ),
    _GeoCategory(
      'desert_safari',
      'Desert Safari & Camels',
      'experiences',
      Icons.wb_sunny_rounded,
    ),
    _GeoCategory(
      'volcano_trekking',
      'Volcano / Trekking Guides',
      'experiences',
      Icons.terrain_rounded,
    ),
    _GeoCategory(
      'food_tours',
      'Food & Culinary Tours',
      'experiences',
      Icons.tapas_rounded,
    ),
    _GeoCategory(
      'wine_tastings',
      'Sommeliers & Wine Tastings',
      'experiences',
      Icons.wine_bar_rounded,
    ),

    // CULTURE & ENTERTAINMENT
    _GeoCategory('djs', 'DJs & VIP Hosts', 'culture', Icons.headphones_rounded),
    _GeoCategory(
      'photographers',
      'Photographers / Paparazzi',
      'culture',
      Icons.camera_alt_rounded,
    ),
    _GeoCategory(
      'spiritual',
      'Spiritual Guides & Cacao',
      'culture',
      Icons.self_improvement_rounded,
    ),
    _GeoCategory(
      'salsa',
      'Salsa & Bachata Classes',
      'culture',
      Icons.music_note_rounded,
    ),
    _GeoCategory('tango', 'Tango Classes', 'culture', Icons.music_note_rounded),
    _GeoCategory(
      'martial_arts',
      'Martial Arts / Muay Thai',
      'culture',
      Icons.sports_martial_arts_rounded,
    ),
    _GeoCategory(
      'kpop_dance',
      'K-Pop / Dance Classes',
      'culture',
      Icons.library_music_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCity = PassportCities.all.firstWhere(
      (c) => c.name == 'Miami',
      orElse: () => PassportCities.all.first,
    );

    // Seed global defaults & hyper-local specialities
    for (final city in PassportCities.all) {
      _marketConfig[city.name] = {
        // Global defaults available everywhere
        'properties': true,
        'cleaners': true,
        'maintenance': true,
        'massage': true,
        'makeup_artists': true,
        'hair_stylists': true,
        'nannies': true,
        'bartenders': true,
        'chauffeurs': true,
        'photographers': true,
      };

      final n = city.name;

      // Tropical / Beach Hubs
      if ([
        'Tulum',
        'Bali',
        'Mykonos',
        'Ibiza',
        'Cabo',
        'Punta Cana',
        'Cancún',
        'Miami',
        'Sydney',
        'Rio',
      ].contains(n)) {
        _marketConfig[n]!['yachts'] = true;
      }

      if (['Tulum', 'Bali', 'Punta Cana', 'Cancún'].contains(n)) {
        _marketConfig[n]!['golf_carts'] = true;
        _marketConfig[n]!['scuba'] = true;
      }

      if (['Tulum', 'Bali'].contains(n)) {
        _marketConfig[n]!['spiritual'] = true;
        _marketConfig[n]!['bicycles'] = true;
        _marketConfig[n]!['motorcycles'] = true;
      }

      // Surf & Water Sports
      if (['Bali', 'Sydney', 'Cabo', 'Rio', 'Hawaii', 'Oaxaca'].contains(n)) {
        _marketConfig[n]!['surf_lessons'] = true;
      }
      if (['Cabo', 'Cancún', 'Miami', 'Punta Cana'].contains(n)) {
        _marketConfig[n]!['fishing'] = true;
      }

      // Mega-Luxury / VIP Nightlife
      if ([
        'Dubai',
        'Monaco',
        'Las Vegas',
        'Miami',
        'LA',
        'London',
        'Paris',
        'New York',
      ].contains(n)) {
        _marketConfig[n]!['exotic_cars'] = true;
        _marketConfig[n]!['private_jets'] = true;
        _marketConfig[n]!['security'] = true;
      }

      if ([
        'Ibiza',
        'Mykonos',
        'Las Vegas',
        'Miami',
        'Dubai',
        'Tulum',
      ].contains(n)) {
        _marketConfig[n]!['djs'] = true;
      }

      // Deserts & Treks
      if (['Dubai', 'Marrakech'].contains(n)) {
        _marketConfig[n]!['desert_safari'] = true;
        _marketConfig[n]!['atv_quads'] = true;
      }
      if (['Bali', 'Tokyo', 'Medellín'].contains(n)) {
        _marketConfig[n]!['volcano_trekking'] = true;
      }

      // Culture, Food & Fashion capitals
      if ([
        'Paris',
        'Rome',
        'Barcelona',
        'New York',
        'London',
        'Tokyo',
        'Seoul',
      ].contains(n)) {
        _marketConfig[n]!['translators'] = true;
        _marketConfig[n]!['food_tours'] = true;
        _marketConfig[n]!['personal_shoppers'] = true;
      }
      if (['Paris', 'Rome', 'Barcelona', 'New York', 'London'].contains(n)) {
        _marketConfig[n]!['wine_tastings'] = true;
      }
      if (['Paris', 'Ibiza', 'Monaco', 'Cabo', 'LA'].contains(n)) {
        _marketConfig[n]!['chefs'] = true; // High-end villa chefs
      }

      // Regional specifics
      if (['Medellín', 'Cartagena', 'Miami'].contains(n)) {
        _marketConfig[n]!['salsa'] = true;
      }
      if (n == 'Buenos Aires' || n == 'Argentina') {
        _marketConfig[n]!['tango'] = true;
      }
      if (['Tokyo', 'Seoul', 'Bangkok', 'Rio'].contains(n)) {
        _marketConfig[n]!['martial_arts'] = true;
      }
      if (n == 'Seoul' || n == 'LA') {
        _marketConfig[n]!['kpop_dance'] = true;
      }

      // Fitness capitals
      if (['LA', 'Miami', 'Sydney', 'Rio'].contains(n)) {
        _marketConfig[n]!['personal_trainers'] = true;
      }
    }
  }

  void _toggleCategory(String categoryId, bool value) {
    if (_selectedCity == null) return;
    setState(() {
      _marketConfig[_selectedCity!.name] ??= {};
      _marketConfig[_selectedCity!.name]![categoryId] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;

    return AdminShell(
      title: 'Geo Markets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'MARKET CONFIGURATION',
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(120),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Toggle local capabilities based on the active market hub. This defines which categories, workers, and experiences users can discover.',
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(180),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // City Selector
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: PassportCities.all.length,
              itemBuilder: (context, index) {
                final city = PassportCities.all[index];
                final selected = _selectedCity?.name == city.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(city.name),
                    selected: selected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCity = city);
                    },
                    selectedColor: AppTheme.brandPrimary,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: selected ? Colors.white : ink,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppTheme.brandPrimary
                            : ink.withAlpha(30),
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          if (_selectedCity != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(_selectedCity!.photoUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCity!.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _selectedCity!.country,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink.withAlpha(150),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Categories List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              children: [
                _buildGroup('CORE & MOBILITY', ['mobility'], ink),
                _buildGroup('WORKERS, SECURITY & SERVICES', ['workers'], ink),
                _buildGroup('BEAUTY, WELLNESS & STYLE', ['beauty'], ink),
                _buildGroup('OUTDOORS & EXPERIENCES', ['experiences'], ink),
                _buildGroup('CULTURE & ENTERTAINMENT', ['culture'], ink),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(String title, List<String> groupIds, Color ink) {
    if (_selectedCity == null) return const SizedBox.shrink();
    final categories = _allCategories
        .where((c) => groupIds.contains(c.groupId))
        .toList();
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: ink.withAlpha(120),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: ink.withAlpha(8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ink.withAlpha(15)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < categories.length; i++) ...[
                _buildCategoryTile(categories[i], ink),
                if (i < categories.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                    color: ink.withAlpha(15),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(_GeoCategory category, Color ink) {
    final isActive = _marketConfig[_selectedCity!.name]?[category.id] ?? false;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.brandPrimary.withAlpha(20)
              : ink.withAlpha(10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          category.icon,
          color: isActive ? AppTheme.brandPrimary : ink.withAlpha(150),
          size: 20,
        ),
      ),
      title: Text(
        category.name,
        style: GoogleFonts.plusJakartaSans(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      trailing: Switch.adaptive(
        value: isActive,
        activeColor: AppTheme.brandPrimary,
        onChanged: (val) => _toggleCategory(category.id, val),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _GeoCategory {
  _GeoCategory(this.id, this.name, this.groupId, this.icon);
  final String id;
  final String name;
  final String groupId;
  final IconData icon;
}
