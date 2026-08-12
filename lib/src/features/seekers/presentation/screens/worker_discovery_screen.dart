import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor ClientWorkerDiscovery — browse worker / pro listings.
class WorkerDiscoveryScreen extends ConsumerStatefulWidget {
  const WorkerDiscoveryScreen({super.key});

  @override
  ConsumerState<WorkerDiscoveryScreen> createState() =>
      _WorkerDiscoveryScreenState();
}

class _WorkerDiscoveryScreenState extends ConsumerState<WorkerDiscoveryScreen> {
  String _pricing = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(swipeListingsProvider('worker'));

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WORKER DISCOVERY',
                            style: AppTheme.displayItalic.copyWith(fontSize: 20)),
                        Text(
                          'Elite skillset · book a pro',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref.invalidate(swipeListingsProvider('worker')),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final p in const [
                    ('all', 'All'),
                    ('hour', 'Hourly'),
                    ('day', 'Daily'),
                    ('project', 'Project'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.$2),
                        selected: _pricing == p.$1,
                        onSelected: (_) => setState(() => _pricing = p.$1),
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
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(swipeListingsProvider('worker')),
                    child: const Text('Could not load workers — retry'),
                  ),
                ),
                data: (items) {
                  final filtered = _pricing == 'all'
                      ? items
                      : items
                          .where((l) =>
                              (l.pricingUnit ?? '')
                                  .toLowerCase()
                                  .contains(_pricing))
                          .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No workers match this filter yet.',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _WorkerCard(listing: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final image = listing.primaryImage;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 160,
            child: image != null
                ? Image.network(image, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFF16161C),
                          child: Icon(Icons.work_rounded, color: Colors.white24),
                        ))
                : const ColoredBox(
                    color: Color(0xFF16161C),
                    child: Icon(Icons.work_rounded, color: Colors.white24),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (listing.title ?? 'Pro').toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (listing.serviceCategory != null) listing.serviceCategory!,
                    listing.formattedLocation,
                    listing.formattedPrice,
                  ].where((s) => s.trim().isNotEmpty).join(' · '),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (listing.experienceYears != null)
                      Text(
                        '${listing.experienceYears}y exp',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF69DB7C),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(
                              listingId: listing.id,
                              listingData: listing,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'VIEW',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
