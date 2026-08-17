import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Quiet, ChatGPT-style empty state for Intel Core.
///
/// Keep discovery suggestions compact. The previous two-column category grid
/// expanded into giant pills on wide screens and made the AI feel like a
/// separate page instead of a conversation.
class IntelWelcomeGrid extends StatelessWidget {
  const IntelWelcomeGrid({
    super.key,
    required this.isLight,
    required this.onPick,
  });

  final bool isLight;
  final ValueChanged<String> onPick;

  static const _suggestions = <(IconData, String, String)>[
    (
      Icons.home_outlined,
      'Find a place',
      'Help me find a property that matches what I need',
    ),
    (
      Icons.handyman_outlined,
      'Find a worker',
      'Help me find a worker or local service',
    ),
    (
      Icons.groups_2_outlined,
      'People nearby',
      'Show me seekers and people looking for something nearby',
    ),
    (
      Icons.celebration_outlined,
      'What’s happening?',
      'Show me interesting events happening nearby',
    ),
    (
      Icons.sailing_outlined,
      'Yachts',
      'Help me find yachts available near me',
    ),
    (
      Icons.two_wheeler_outlined,
      'Motorcycles',
      'Help me find motorcycles available near me',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ink = isLight ? const Color(0xFF111114) : Colors.white;
    final muted = ink.withAlpha(120);
    final chipFill = isLight
        ? const Color(0xFFF5F5F7)
        : Colors.white.withAlpha(10);
    final border = isLight
        ? Colors.black.withAlpha(22)
        : Colors.white.withAlpha(28);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withAlpha(6)
                  : Colors.white.withAlpha(10),
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: ink, size: 21),
          ),
          const SizedBox(height: 16),
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
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in _suggestions)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      AppHaptics.selection();
                      onPick(item.$3);
                    },
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: chipFill,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.$1, size: 16, color: muted),
                          const SizedBox(width: 7),
                          Text(
                            item.$2,
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
