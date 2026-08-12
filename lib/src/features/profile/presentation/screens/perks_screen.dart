import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor ClientPerks / PerksDashboard shell.
class PerksScreen extends StatefulWidget {
  const PerksScreen({super.key});

  @override
  State<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends State<PerksScreen> {
  int _tab = 0;

  static const _offers = [
    ('Tulum Cafe Collective', '15% off breakfast bowls', Icons.coffee_rounded),
    ('Coastal Gym Pass', '1 free guest day / month', Icons.fitness_center_rounded),
    ('Laguna Surf School', '\$20 off first lesson', Icons.surfing_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(35)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'RESIDENT PERKS',
                      style: AppTheme.displayItalic.copyWith(fontSize: 22),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Resident QR opens when partner scan is live'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final (i, label) in [
                    (0, 'Home'),
                    (1, 'Partners'),
                    (2, 'Inbox'),
                    (3, 'History'),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _tab == i,
                          onSelected: (_) => setState(() => _tab = i),
                          selectedColor: AppTheme.brandPrimary,
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                          backgroundColor: Colors.white.withAlpha(14),
                          side: BorderSide(color: Colors.white.withAlpha(30)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  if (_tab == 0 || _tab == 1) ...[
                    Text(
                      _tab == 0 ? 'ACTIVE OFFERS' : 'PARTNER NETWORK',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final o in _offers) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withAlpha(28)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                                ),
                              ),
                              child: Icon(o.$3, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.$1,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    o.$2,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Colors.white38),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (_tab == 2)
                    Text(
                      'Promo inbox is empty. Partner codes will land here.',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                    ),
                  if (_tab == 3)
                    Text(
                      'No redemptions yet. Show your resident QR at partners to earn history.',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
