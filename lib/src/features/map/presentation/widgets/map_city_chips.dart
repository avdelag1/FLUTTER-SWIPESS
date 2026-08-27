import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact city pills with soft edge fading. The mask fades the pill content
/// itself, so there is no rectangular overlay, border, seam or hard line where
/// the horizontal rail meets the phone/browser edge.
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
      padding: const EdgeInsets.only(left: 6, right: 58),
      child: SizedBox(
        height: 36,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, .055, .945, 1],
          ).createShader(rect),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: PassportCities.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final city = PassportCities.all[i];
              final cityName = city.name.toLowerCase();
              final currentCity = activeCity.toLowerCase();
              final active =
                  currentCity.contains(cityName) || cityName == currentCity;

              return Semantics(
                button: true,
                selected: active,
                label: 'Show ${city.name} on map',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    AppHaptics.selection();
                    onSelect(city);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xF2111317)
                          : const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        city.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: GoogleFonts.plusJakartaSans(
                          color: active ? Colors.white : const Color(0xFF111318),
                          fontWeight: FontWeight.w800,
                          fontSize: 9.4,
                          letterSpacing: .44,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
