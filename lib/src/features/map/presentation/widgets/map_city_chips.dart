import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact liquid-glass city pills with a protected lane that never runs
/// underneath the map's right-side zoom/location controls.
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
    return Padding(
      // The control rail is 42 px wide, sits 12 px from the edge, and needs
      // breathing room. Keeping the viewport itself away from that area avoids
      // the transparent vertical cut/overlap visible on compact phones.
      padding: const EdgeInsets.only(left: 12, right: 68),
      child: SizedBox(
        height: 33,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.zero,
          itemCount: PassportCities.all.length,
          separatorBuilder: (_, _) => const SizedBox(width: 5),
          itemBuilder: (context, i) {
            final city = PassportCities.all[i];
            final cityName = city.name.toLowerCase();
            final currentCity = activeCity.toLowerCase();
            final active = currentCity.contains(cityName) || cityName == currentCity;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                AppHaptics.selection();
                onSelect(city);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: active
                          ? Colors.white.withAlpha(218)
                          : Colors.black.withAlpha(94),
                      border: Border.all(
                        color: active
                            ? Colors.white.withAlpha(226)
                            : Colors.white.withAlpha(48),
                        width: 0.7,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        city.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: GoogleFonts.plusJakartaSans(
                          color: active
                              ? const Color(0xFF111318)
                              : Colors.white.withAlpha(238),
                          fontWeight: FontWeight.w800,
                          fontSize: 9.2,
                          letterSpacing: 0.48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
