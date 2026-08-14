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
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                      )
                    : null,
                color: active ? null : const Color(0xE6121824),
                border: Border.all(
                  color: active ? Colors.white : const Color(0xAA00C6FF),
                  width: active ? 1.5 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (active ? const Color(0xFF00C6FF) : Colors.black)
                        .withAlpha(active ? 90 : 80),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.network(
                      city.photoUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFF1D4ED8),
                        child: SizedBox(width: 28, height: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    city.name.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
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
