import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_controls.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_layout.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';

/// Distinct but restrained AI welcome state: same Swipess system, with the
/// violet/pink intelligence accent reserved for AI interactions.
class IntelWelcomeGrid extends ConsumerWidget {
  const IntelWelcomeGrid({
    super.key,
    required this.isLight,
    required this.onPick,
  });

  final bool isLight;
  final ValueChanged<String> onPick;

  List<(IconData, String, String)> _getDynamicSuggestions(String? city) {
    final lowerCity = city?.toLowerCase() ?? '';

    if (lowerCity.contains('tulum')) {
      return const [
        (Icons.water_rounded, 'Find a cenote 🌴', 'Help me find the best secret cenotes in Tulum'),
        (Icons.nightlife_rounded, 'Jungle party 🪩', 'Where are the best jungle parties tonight in Tulum?'),
        (Icons.auto_awesome_rounded, 'Spiritual guide ✨', 'Help me find a spiritual guide, shaman, or yoga teacher in Tulum'),
        (Icons.villa_rounded, 'Tulum real estate 🏡', 'Show me real estate opportunities or villas to buy in Tulum'),
        (Icons.two_wheeler_rounded, 'Scooter rental 🛵', 'Where can I rent a scooter or ATV near me?'),
        (Icons.beach_access_rounded, 'Beach clubs 🏖️', 'What are the top beach clubs to chill at today?'),
      ];
    }

    if (lowerCity.contains('mexico city') ||
        lowerCity.contains('cdmx') ||
        lowerCity.contains('méxico')) {
      return const [
        (Icons.restaurant_rounded, 'Chido tacos 🌮', 'Where can I find the most authentic and best street tacos in CDMX?'),
        (Icons.local_bar_rounded, 'Speakeasies 🍸', 'Help me find hidden speakeasy bars in Polanco or Roma Norte'),
        (Icons.palette_rounded, 'Art & Culture 🎨', 'What are the must-see museums and art galleries right now?'),
        (Icons.laptop_mac_rounded, 'Coworking spots 💻', 'Find me a great cafe or coworking space with fast wifi'),
        (Icons.apartment_rounded, 'Find a place 🏢', 'Help me find a loft or apartment to rent'),
        (Icons.groups_rounded, 'People nearby 👥', 'Show me other expats and creatives in Mexico City'),
      ];
    }

    if (city != null && city.isNotEmpty && city.toLowerCase() != 'global') {
      return [
        (Icons.home_work_rounded, 'Find a place in $city', 'Help me find a property that matches what I need in $city'),
        (Icons.handyman_rounded, 'Find a worker', 'Help me find a worker or local service in $city'),
        (Icons.groups_rounded, 'People in $city', 'Show me seekers and people looking for something in $city'),
        (Icons.event_rounded, 'Events tonight', 'Show me interesting events happening nearby in $city'),
        (Icons.sailing_rounded, 'Yachts', 'Help me find yachts available near me in $city'),
        (Icons.two_wheeler_rounded, 'Motorcycles', 'Help me find motorcycles available near me in $city'),
      ];
    }

    return const [
      (Icons.home_work_rounded, 'Find a place', 'Help me find a property that matches what I need'),
      (Icons.handyman_rounded, 'Find a worker', 'Help me find a worker or local service'),
      (Icons.groups_rounded, 'People nearby', 'Show me seekers and people looking for something nearby'),
      (Icons.event_rounded, 'What’s happening?', 'Show me interesting events happening nearby'),
      (Icons.sailing_rounded, 'Yachts', 'Help me find yachts available near me'),
      (Icons.two_wheeler_rounded, 'Motorcycles', 'Help me find motorcycles available near me'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = isLight ? const Color(0xFF111114) : Colors.white;
    final muted = ink.withAlpha(isLight ? 135 : 165);
    final chipFill = isLight
        ? Colors.white
        : SwipessTokens.darkElevated.withAlpha(230);
    final loc = ref.watch(discoveryLocationProvider);
    final suggestions = _getDynamicSuggestions(loc.label);
    final narrow = SwipessResponsive.isNarrow(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 14 : 22, 34, narrow ? 14 : 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [SwipessTokens.brandViolet, SwipessTokens.brandPink],
              ),
              boxShadow: [
                BoxShadow(
                  color: SwipessTokens.brandViolet.withAlpha(55),
                  blurRadius: 24,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(height: 16),
          Text(
            'How can I help?',
            textAlign: TextAlign.center,
            style: SwipessTokens.displayItalic(color: ink, fontSize: 23),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask anything, or start with one of these.',
            textAlign: TextAlign.center,
            style: SwipessTokens.bodyClean(color: muted, fontSize: 13),
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
                SwipessPressable(
                  onTap: () => onPick(item.$3),
                  haptic: SwipessHaptic.selection,
                  semanticLabel: item.$2,
                  borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: narrow ? 108 : 116,
                      maxWidth: narrow ? 190 : 230,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: chipFill,
                      borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
                      border: Border.all(
                        color: isLight
                            ? Colors.black.withAlpha(20)
                            : SwipessTokens.brandViolet.withAlpha(42),
                      ),
                      boxShadow: isLight
                          ? [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$1, size: 16, color: SwipessTokens.brandViolet),
                        const SizedBox(width: 7),
                        Text(
                          item.$2,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwipessTokens.meta(color: ink, fontSize: 11.5)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
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
