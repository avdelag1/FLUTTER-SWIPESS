import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/ai_listing_builder_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor “CREATE NEW LISTING” chooser — Magic AI + manual categories.
Future<void> showCreateListingChooser(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _CreateListingChooser(),
  );
}

class _CreateListingChooser extends StatelessWidget {
  const _CreateListingChooser();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREATE NEW LISTING',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SELECT THE TYPE OF LISTING YOU WANT TO CREATE',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                _Close(onTap: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 18),
            _MagicCard(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiListingBuilderScreen()),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withAlpha(40))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR MANUAL MODE',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withAlpha(40))),
              ],
            ),
            const SizedBox(height: 14),
            _ManualTile(
              icon: Icons.apartment_rounded,
              wash: const Color(0xFFFF4D6A),
              title: 'PROPERTY',
              subtitle: 'Apartments, houses, condos, villas',
              badge: 'POPULAR',
              onTap: () => _openManual(context, 'property'),
            ),
            _ManualTile(
              icon: Icons.two_wheeler_rounded,
              wash: const Color(0xFFFF8C42),
              title: 'MOTORCYCLE',
              subtitle: 'Motorcycles, scooters, ATVs',
              onTap: () => _openManual(context, 'motorcycle'),
            ),
            _ManualTile(
              icon: Icons.pedal_bike_rounded,
              wash: const Color(0xFF9B5DE5),
              title: 'BICYCLE',
              subtitle: 'Bikes, e-bikes, mountain bikes',
              onTap: () => _openManual(context, 'bicycle'),
            ),
            _ManualTile(
              icon: Icons.anchor_rounded,
              wash: const Color(0xFF2EC4B6),
              title: 'YACHT',
              subtitle: 'Yachts, boats, catamarans, charters',
              onTap: () => _openManual(context, 'yacht'),
            ),
            _ManualTile(
              icon: Icons.work_rounded,
              wash: const Color(0xFFFFD166),
              title: 'JOBS & SERVICES',
              subtitle: 'Chef, cleaner, nanny, handyman, and more',
              onTap: () => _openManual(context, 'worker'),
            ),
          ],
        ),
      ),
    );
  }

  void _openManual(BuildContext context, String category) {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddListingScreen(initialCategory: category),
      ),
    );
  }
}

class _MagicCard extends StatelessWidget {
  const _MagicCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1B4A), Color(0xFF1A1433)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0x669B5DE5)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF9B5DE5), Color(0xFF4DABF7)],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'MAGIC AI LISTING',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4DABF7).withAlpha(60),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'FASTEST',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFB8D9FF),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload photos & describe your asset. AI generates the entire listing in seconds.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9B5DE5), size: 16),
          ],
        ),
      ),
    );
  }
}

class _ManualTile extends StatelessWidget {
  const _ManualTile({
    required this.icon,
    required this.wash,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color wash;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16161C),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withAlpha(28)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: wash.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: wash, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: -6,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Close extends StatelessWidget {
  const _Close({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}
