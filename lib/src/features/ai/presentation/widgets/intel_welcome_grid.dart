import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `filterData.FILTERS` — category → prompt chips for Intel Core welcome.
class IntelFilterOption {
  const IntelFilterOption({required this.label, required this.prompt});
  final String label;
  final String prompt;
}

class IntelFilterCategory {
  const IntelFilterCategory({
    required this.label,
    required this.glowColor,
    required this.options,
  });
  final String label;
  final Color glowColor;
  final List<IntelFilterOption> options;
}

const intelFilterCategories = <IntelFilterCategory>[
  IntelFilterCategory(
    label: 'Properties',
    glowColor: Color(0xFFF97316),
    options: [
      IntelFilterOption(label: 'All Rentals', prompt: 'Show me all rental properties'),
      IntelFilterOption(label: 'Houses', prompt: 'Show me available houses'),
      IntelFilterOption(label: 'Apartments', prompt: 'Find apartments for rent'),
      IntelFilterOption(label: 'Studios', prompt: 'Show me studios'),
      IntelFilterOption(label: 'Penthouse', prompt: 'Find penthouses'),
      IntelFilterOption(label: 'Loft', prompt: 'Show me lofts'),
      IntelFilterOption(label: 'Cabin', prompt: 'Find cabins'),
      IntelFilterOption(label: 'Land', prompt: 'Find land for sale'),
      IntelFilterOption(label: 'Commercial', prompt: 'Show me commercial properties'),
      IntelFilterOption(label: 'Vacation', prompt: 'Find vacation rentals'),
      IntelFilterOption(label: 'Luxury', prompt: 'Show luxury properties'),
      IntelFilterOption(label: 'Cheapest', prompt: 'Show cheapest properties'),
    ],
  ),
  IntelFilterCategory(
    label: 'Workers',
    glowColor: Color(0xFF3B82F6),
    options: [
      IntelFilterOption(label: 'Cleaning', prompt: 'Find me cleaning workers'),
      IntelFilterOption(label: 'Maintenance', prompt: 'Find maintenance workers'),
      IntelFilterOption(label: 'Construction', prompt: 'Find construction workers'),
      IntelFilterOption(label: 'Electrician', prompt: 'Find an electrician'),
      IntelFilterOption(label: 'Plumber', prompt: 'Find a plumber'),
      IntelFilterOption(label: 'Driver', prompt: 'Find a private driver'),
      IntelFilterOption(label: 'Nanny', prompt: 'Find a nanny or babysitter'),
      IntelFilterOption(label: 'Gardener', prompt: 'Find a gardener'),
      IntelFilterOption(label: 'Cook', prompt: 'Find a cook or chef'),
      IntelFilterOption(label: 'Tutor', prompt: 'Find a tutor'),
      IntelFilterOption(label: 'Wellness', prompt: 'Find massage and wellness'),
      IntelFilterOption(label: 'All Workers', prompt: 'Show me all workers and services'),
    ],
  ),
  IntelFilterCategory(
    label: 'Motorcycles',
    glowColor: Color(0xFFEF4444),
    options: [
      IntelFilterOption(label: 'For Sale', prompt: 'Find motorcycles for sale'),
      IntelFilterOption(label: 'Cheapest', prompt: 'Show cheapest motorcycles'),
      IntelFilterOption(label: 'New Listings', prompt: 'Show newest motorcycle listings'),
      IntelFilterOption(label: 'Near Me', prompt: 'Find motorcycles near me'),
    ],
  ),
  IntelFilterCategory(
    label: 'Bicycles',
    glowColor: Color(0xFF10B981),
    options: [
      IntelFilterOption(label: 'For Sale', prompt: 'Find bicycles for sale'),
      IntelFilterOption(label: 'Cheapest', prompt: 'Show cheapest bicycles'),
      IntelFilterOption(label: 'New Listings', prompt: 'Show new bicycle listings'),
      IntelFilterOption(label: 'Near Me', prompt: 'Find bicycles near me'),
    ],
  ),
  IntelFilterCategory(
    label: 'Yachts',
    glowColor: Color(0xFF14B8A6),
    options: [
      IntelFilterOption(label: 'For Charter', prompt: 'Find yachts for charter'),
      IntelFilterOption(label: 'For Sale', prompt: 'Find yachts for sale'),
      IntelFilterOption(label: 'Catamarans', prompt: 'Show me catamarans'),
      IntelFilterOption(label: 'Cheapest', prompt: 'Show cheapest yachts'),
      IntelFilterOption(label: 'Near Me', prompt: 'Find yachts near me'),
    ],
  ),
  IntelFilterCategory(
    label: 'Buyers',
    glowColor: Color(0xFFA855F7),
    options: [
      IntelFilterOption(label: 'Looking for Houses', prompt: 'Find people looking to buy houses'),
      IntelFilterOption(label: 'Looking for Land', prompt: 'Find people looking to buy land'),
      IntelFilterOption(label: 'Looking for Vehicles', prompt: 'Find people looking to buy vehicles'),
      IntelFilterOption(label: 'All Buyers', prompt: 'Show me all buyers'),
    ],
  ),
  IntelFilterCategory(
    label: 'Renters',
    glowColor: Color(0xFFD946EF),
    options: [
      IntelFilterOption(label: 'Looking for Apartments', prompt: 'Find people looking to rent apartments'),
      IntelFilterOption(label: 'Looking for Houses', prompt: 'Find people looking to rent houses'),
      IntelFilterOption(label: 'Looking for Rooms', prompt: 'Find people looking for rooms'),
      IntelFilterOption(label: 'All Renters', prompt: 'Show me all renters'),
    ],
  ),
  IntelFilterCategory(
    label: 'Seekers',
    glowColor: Color(0xFF06B6D4),
    options: [
      IntelFilterOption(label: 'Find Services', prompt: 'Find people looking for services'),
      IntelFilterOption(label: 'Find Workers', prompt: 'Find people looking to hire workers'),
      IntelFilterOption(label: 'Find Roommates', prompt: 'Find people looking for roommates'),
      IntelFilterOption(label: 'Find Friends', prompt: 'Find people looking for friends'),
      IntelFilterOption(label: 'All Seekers', prompt: 'Show me everyone looking for something'),
    ],
  ),
];

/// Cap `WelcomeState` — INTEL CORE category grid, then prompt chips.
class IntelWelcomeGrid extends StatefulWidget {
  const IntelWelcomeGrid({
    super.key,
    required this.isLight,
    required this.onPick,
  });

  final bool isLight;
  final ValueChanged<String> onPick;

  @override
  State<IntelWelcomeGrid> createState() => _IntelWelcomeGridState();
}

class _IntelWelcomeGridState extends State<IntelWelcomeGrid> {
  IntelFilterCategory? _active;

  Color get _ink =>
      widget.isLight ? const Color(0xFF0A0A0D) : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (_active?.label ?? 'Intel Core').toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: _ink,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              fontSize: 28,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _active == null ? 'CHOOSE A CATEGORY' : 'PICK A PROMPT',
            style: GoogleFonts.plusJakartaSans(
              color: _ink.withAlpha(120),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 20),
          if (_active != null) ...[
            GestureDetector(
              onTap: () {
                AppHaptics.selection();
                setState(() => _active = null);
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_rounded,
                        size: 14, color: _ink.withAlpha(140)),
                    const SizedBox(width: 6),
                    Text(
                      'Back to categories',
                      style: GoogleFonts.plusJakartaSans(
                        color: _ink.withAlpha(140),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final opt in _active!.options)
                  _IntelPill(
                    label: opt.label,
                    isLight: widget.isLight,
                    centered: false,
                    onTap: () => widget.onPick(opt.prompt),
                  ),
              ],
            ),
          ] else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: intelFilterCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.55,
              ),
              itemBuilder: (context, i) {
                final cat = intelFilterCategories[i];
                return _IntelPill(
                  label: cat.label.toUpperCase(),
                  isLight: widget.isLight,
                  centered: true,
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _active = cat);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _IntelPill extends StatelessWidget {
  const _IntelPill({
    required this.label,
    required this.isLight,
    required this.onTap,
    this.centered = true,
  });

  final String label;
  final bool isLight;
  final VoidCallback onTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: isLight ? Colors.white : Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ink, width: 1.4),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: centered ? 8 : 16,
                vertical: centered ? 0 : 14,
              ),
              child: Text(
                label,
                textAlign: centered ? TextAlign.center : TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: centered ? 13 : 13,
                  letterSpacing: centered ? 1.4 : 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
