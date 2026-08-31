import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean empty state for Intel Core.
class IntelWelcomeGrid extends ConsumerWidget {
  const IntelWelcomeGrid({
    super.key,
    required this.isLight,
    required this.onPick,
  });

  final bool isLight;
  final ValueChanged<String> onPick;

  List<(String, String)> _getDynamicSuggestions(String? city) {
    final lowerCity = city?.toLowerCase() ?? '';

    // Tulum specific slang/vibes
    if (lowerCity.contains('tulum')) {
      return [
        ('Find a cenote 🌴', 'Help me find the best secret cenotes in Tulum'),
        ('Jungle party 🪩', 'Where are the best jungle parties tonight in Tulum?'),
        ('Spiritual guide ✨', 'Help me find a spiritual guide, shaman, or yoga teacher in Tulum'),
        ('Tulum real estate 🏡', 'Show me real estate opportunities or villas to buy in Tulum'),
        ('Scooter rental 🛵', 'Where can I rent a scooter or ATV near me?'),
        ('Beach clubs 🏖️', 'What are the top beach clubs to chill at today?'),
      ];
    }
    
    // Mexico City specific
    if (lowerCity.contains('mexico city') || lowerCity.contains('cdmx') || lowerCity.contains('méxico')) {
      return [
        ('Chido tacos 🌮', 'Where can I find the most authentic and best street tacos in CDMX?'),
        ('Speakeasies 🍸', 'Help me find hidden speakeasy bars in Polanco or Roma Norte'),
        ('Art & Culture 🎨', 'What are the must-see museums and art galleries right now?'),
        ('Coworking spots 💻', 'Find me a great cafe or coworking space with fast wifi'),
        ('Find a place 🏢', 'Help me find a loft or apartment to rent'),
        ('People nearby 👥', 'Show me other expats and creatives in Mexico City'),
      ];
    }

    // Default dynamic (injects the city name)
    if (city != null && city.isNotEmpty && city.toLowerCase() != 'global') {
      return [
        ('Find a place in $city', 'Help me find a property that matches what I need in $city'),
        ('Find a worker', 'Help me find a worker or local service in $city'),
        ('People in $city', 'Show me seekers and people looking for something in $city'),
        ('Events tonight', 'Show me interesting events happening nearby in $city'),
        ('Yachts', 'Help me find yachts available near me in $city'),
        ('Motorcycles', 'Help me find motorcycles available near me in $city'),
      ];
    }

    // Fallback standard globally
    return [
      ('Find a place', 'Help me find a property that matches what I need'),
      ('Find a worker', 'Help me find a worker or local service'),
      ('People nearby', 'Show me seekers and people looking for something nearby'),
      ('What’s happening?', 'Show me interesting events happening nearby'),
      ('Yachts', 'Help me find yachts available near me'),
      ('Motorcycles', 'Help me find motorcycles available near me'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = isLight ? const Color(0xFF111114) : Colors.white;
    final muted = isLight ? ink.withAlpha(120) : Colors.white70;
    final chipFill = isLight
        ? const Color(0xFFF5F5F7)
        : Colors.white.withAlpha(10);
    final border = isLight ? Colors.black.withAlpha(22) : Colors.white70;
    
    final loc = ref.watch(discoveryLocationProvider);
    final suggestions = _getDynamicSuggestions(loc.label);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 42, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'How can I help?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask anything, or start with one of these.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in suggestions)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      AppHaptics.selection();
                      onPick(item.$2);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 116),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: chipFill,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          item.$1,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
