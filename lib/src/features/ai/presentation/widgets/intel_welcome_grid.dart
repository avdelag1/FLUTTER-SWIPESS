import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean empty state for Intel Core.
class IntelWelcomeGrid extends StatelessWidget {
  const IntelWelcomeGrid({
    super.key,
    required this.isLight,
    required this.onPick,
  });

  final bool isLight;
  final ValueChanged<String> onPick;

  static const _suggestions = <(String, String)>[
    ('Find a place', 'Help me find a property that matches what I need'),
    ('Find a worker', 'Help me find a worker or local service'),
    ('People nearby', 'Show me seekers and people looking for something nearby'),
    ('What’s happening?', 'Show me interesting events happening nearby'),
    ('Yachts', 'Help me find yachts available near me'),
    ('Motorcycles', 'Help me find motorcycles available near me'),
  ];

  @override
  Widget build(BuildContext context) {
    final ink = isLight ? const Color(0xFF111114) : Colors.white;
    final muted = isLight ? ink.withAlpha(120) : Colors.white70;
    final chipFill = isLight
        ? const Color(0xFFF5F5F7)
        : Colors.white.withAlpha(10);
    final border = isLight ? Colors.black.withAlpha(22) : Colors.white70;

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
              for (final item in _suggestions)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      AppHaptics.selection();
                      onPick(item.$2);
                    },
                    child: Ink(
                      constraints: const BoxConstraints(minWidth: 116),
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
            ],
          ),
        ],
      ),
    );
  }
}
