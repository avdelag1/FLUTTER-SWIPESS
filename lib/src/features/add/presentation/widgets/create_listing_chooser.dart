import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/ai_listing_builder_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor “CREATE NEW LISTING” chooser — Magic AI + manual + mode.
Future<void> showCreateListingChooser(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(190),
    builder: (context) => const _CreateListingChooser(),
  );
}

class _CreateListingChooser extends StatefulWidget {
  const _CreateListingChooser();

  @override
  State<_CreateListingChooser> createState() => _CreateListingChooserState();
}

class _CreateListingChooserState extends State<_CreateListingChooser> {
  String? _pendingCategory;

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
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
          children: [
            Row(
              children: [
                if (_pendingCategory != null) ...[
                  GestureDetector(
                    onTap: () => setState(() => _pendingCategory = null),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pendingCategory == null
                            ? 'CREATE NEW LISTING'
                            : 'LISTING TYPE',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pendingCategory == null
                            ? 'SELECT THE TYPE OF LISTING YOU WANT TO CREATE'
                            : 'FOR RENT, FOR SALE, OR BOTH',
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
            if (_pendingCategory == null) ...[
              _MagicCard(
                onTap: () {
                  AppHaptics.medium();
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiListingBuilderScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.transparent)),
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
                  const Expanded(child: Divider(color: Colors.transparent)),
                ],
              ),
              const SizedBox(height: 14),
              _ManualTile(
                icon: Icons.apartment_rounded,
                wash: const Color(0xFFFF4D6A),
                title: 'PROPERTY',
                subtitle: 'Apartments, houses, condos, villas',
                badge: 'POPULAR',
                onTap: () => _pickCategory('property'),
              ),
              _ManualTile(
                icon: Icons.two_wheeler_rounded,
                wash: const Color(0xFFFF8C42),
                title: 'MOTORCYCLE',
                subtitle: 'Motorcycles, scooters, ATVs',
                onTap: () => _pickCategory('motorcycle'),
              ),
              _ManualTile(
                icon: Icons.pedal_bike_rounded,
                wash: const Color(0xFF9B5DE5),
                title: 'BICYCLE',
                subtitle: 'Bikes, e-bikes, mountain bikes',
                onTap: () => _pickCategory('bicycle'),
              ),
              _ManualTile(
                icon: Icons.anchor_rounded,
                wash: const Color(0xFF2EC4B6),
                title: 'YACHT',
                subtitle: 'Yachts, boats, catamarans, charters',
                onTap: () => _pickCategory('yacht'),
              ),
              _ManualTile(
                icon: Icons.work_rounded,
                wash: const Color(0xFFFFD166),
                title: 'JOBS & SERVICES',
                subtitle: 'Chef, cleaner, nanny, handyman, and more',
                onTap: () => _openManual('worker', ListingMode.rent),
              ),
            ] else ...[
              for (final mode in _modesFor(_pendingCategory!))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ModeCard(
                    icon: mode.$2,
                    title: mode.$3,
                    subtitle: mode.$4,
                    onTap: () => _openManual(_pendingCategory!, mode.$1),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<(ListingMode, IconData, String, String)> _modesFor(String category) {
    switch (category) {
      case 'yacht':
        return const [
          (
            ListingMode.rent,
            Icons.key_rounded,
            'FOR CHARTER',
            'Day trips, weekly, or seasonal charter',
          ),
          (
            ListingMode.sale,
            Icons.sell_rounded,
            'FOR SALE',
            'Yacht for purchase',
          ),
          (
            ListingMode.both,
            Icons.sync_rounded,
            'BOTH OPTIONS',
            'Charter & sale available',
          ),
        ];
      default:
        return const [
          (
            ListingMode.rent,
            Icons.key_rounded,
            'FOR RENT',
            'Monthly or short-term rental',
          ),
          (
            ListingMode.sale,
            Icons.sell_rounded,
            'FOR SALE',
            'Available for purchase',
          ),
          (
            ListingMode.both,
            Icons.sync_rounded,
            'BOTH OPTIONS',
            'Rent & sale available',
          ),
        ];
    }
  }

  void _pickCategory(String category) {
    AppHaptics.light();
    setState(() => _pendingCategory = category);
  }

  void _openManual(String category, ListingMode mode) {
    AppHaptics.light();
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AddListingScreen(initialCategory: category, initialMode: mode),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16161C),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.brandPrimary),
            ),
            const SizedBox(width: 14),
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
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
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
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'MAGIC AI LISTING',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FASTEST',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFB8D9FF),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
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
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF9B5DE5),
              size: 16,
            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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
    return Tooltip(
      message: 'Close',
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        highlightShape: BoxShape.circle,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.close_rounded, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}
