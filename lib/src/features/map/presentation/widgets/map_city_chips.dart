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
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active ? Colors.white : const Color(0xFF0A0A0D),
                border: Border.all(
                  color: Colors.white,
                  width: active ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      city.photoUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.white24,
                        child: SizedBox(width: 28, height: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    city.name.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: active ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
