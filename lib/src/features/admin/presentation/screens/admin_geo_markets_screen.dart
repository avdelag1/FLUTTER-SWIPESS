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

  // Local state to mock the "idea and base". In the future this will be backed by a DB.
  // Map of City Name -> Map of Category ID -> bool (is active)
  final Map<String, Map<String, bool>> _marketConfig = {};

  final _allCategories = <_GeoCategory>[
    _GeoCategory(
      'properties',
      'Properties & Rentals',
      'core',
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
      'motorcycles',
      'Motorcycles',
      'mobility',
      Icons.two_wheeler_rounded,
    ),
    _GeoCategory(
      'atv_quads',
      'ATVs & Quads',
      'mobility',
      Icons.agriculture_rounded,
    ),
    _GeoCategory(
      'bicycles',
      'Bicycles & Scooters',
      'mobility',
      Icons.pedal_bike_rounded,
    ),

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
    _GeoCategory('massage', 'Massage & Wellness', 'workers', Icons.spa_rounded),
    _GeoCategory(
      'security',
      'Security / Bodyguards',
      'workers',
      Icons.security_rounded,
    ),
    _GeoCategory(
      'translators',
      'Translators',
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
      'paparazzi',
      'Photographers',
      'workers',
      Icons.camera_alt_rounded,
    ),
    _GeoCategory('djs', 'DJ / VIP Hosts', 'workers', Icons.headphones_rounded),

    _GeoCategory(
      'surf_lessons',
      'Surf Instructors',
      'experiences',
      Icons.surfing_rounded,
    ),
    _GeoCategory(
      'tango',
      'Tango Classes',
      'experiences',
      Icons.music_note_rounded,
    ),
    _GeoCategory(
      'salsa',
      'Salsa Classes',
      'experiences',
      Icons.music_note_rounded,
    ),
    _GeoCategory(
      'ski',
      'Ski / Snowboard',
      'experiences',
      Icons.downhill_skiing_rounded,
    ),
    _GeoCategory(
      'spiritual',
      'Spiritual Guides & Cacao',
      'experiences',
      Icons.self_improvement_rounded,
    ),
    _GeoCategory(
      'desert_safari',
      'Desert Safari',
      'experiences',
      Icons.wb_sunny_rounded,
    ),
    _GeoCategory(
      'scuba',
      'Scuba & Cenote Diving',
      'experiences',
      Icons.scuba_diving_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCity = PassportCities.all.firstWhere(
      (c) => c.name == 'Miami',
      orElse: () => PassportCities.all.first,
    );

    // Seed some defaults
    for (final city in PassportCities.all) {
      _marketConfig[city.name] = {
        'properties': true,
        'cleaners': true,
        'maintenance': true,
        'massage': true,
      };

      // Seed specific ones for the idea
      if (city.name == 'Tulum' || city.name == 'Bali') {
        _marketConfig[city.name]!['spiritual'] = true;
        _marketConfig[city.name]!['bicycles'] = true;
      }
      if (city.name == 'Hawaii' ||
          city.name == 'Bali' ||
          city.name == 'Oaxaca' ||
          city.name == 'Sydney') {
        _marketConfig[city.name]!['surf_lessons'] = true;
      }
      if (city.name == 'Dubai' || city.name == 'Marrakech') {
        _marketConfig[city.name]!['desert_safari'] = true;
        _marketConfig[city.name]!['exotic_cars'] = true;
      }
      if (city.name == 'Ibiza' ||
          city.name == 'Miami' ||
          city.name == 'Mykonos' ||
          city.name == 'Las Vegas') {
        _marketConfig[city.name]!['djs'] = true;
        _marketConfig[city.name]!['yachts'] = true;
        _marketConfig[city.name]!['exotic_cars'] = true;
      }
      if (city.name == 'Medellín' || city.name == 'Cartagena') {
        _marketConfig[city.name]!['salsa'] = true;
      }
      if (city.name == 'Paris' ||
          city.name == 'Tokyo' ||
          city.name == 'Seoul') {
        _marketConfig[city.name]!['translators'] = true;
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
              'Toggle listing categories and services based on the city. These settings control what users see when they browse that specific market.',
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
                _buildGroup('CORE & MOBILITY', ['core', 'mobility'], ink),
                _buildGroup('WORKERS & PROS', ['workers'], ink),
                _buildGroup('EXPERIENCES & LESSONS', ['experiences'], ink),
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
