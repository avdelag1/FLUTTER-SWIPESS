import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact city pills with a protected lane that never runs underneath the
/// map's right-side controls. Deliberately avoids BackdropFilter so Flutter web
/// never needs an extra blur/platform-view layer above the Mapbox canvas.
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
            final active =
                currentCity.contains(cityName) || cityName == currentCity;

            return Material(
              color: active ? const Color(0xE8FFFFFF) : const Color(0xB011141A),
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  AppHaptics.selection();
                  onSelect(city);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? Colors.white.withAlpha(225)
                          : Colors.white.withAlpha(52),
                      width: .7,
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
                        letterSpacing: .48,
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
