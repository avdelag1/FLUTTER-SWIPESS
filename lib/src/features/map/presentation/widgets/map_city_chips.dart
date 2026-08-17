import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact liquid-glass city pills that stay clear of the map control rail.
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
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: PassportCities.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active
                        ? Colors.white.withAlpha(222)
                        : Colors.black.withAlpha(104),
                    border: Border.all(
                      color: active
                          ? Colors.white.withAlpha(230)
                          : Colors.white.withAlpha(52),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      city.name.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: active
                            ? const Color(0xFF111318)
                            : Colors.white.withAlpha(238),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.65,
                      ),
                    ),
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
