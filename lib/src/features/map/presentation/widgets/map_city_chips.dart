import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:google_fonts/google_fonts.dart';

/// Horizontal city pills with cover photos — always readable on satellite.
class MapCityChips extends StatelessWidget {
  const MapCityChips({
    super.key,
    required this.activeCity,
    required this.onSelect,
  });

  final String activeCity;
  final ValueChanged<PassportCity> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: PassportCities.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final city = PassportCities.all[i];
          final active =
              activeCity.toLowerCase().contains(city.name.toLowerCase()) ||
              city.name.toLowerCase() == activeCity.toLowerCase();
          return GestureDetector(
            onTap: () {
              AppHaptics.selection();
              onSelect(city);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active ? Colors.white : Colors.black.withAlpha(180),
                border: Border.all(
                  color: active ? Colors.white : Colors.white24,
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  city.name.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: active ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
