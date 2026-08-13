import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/service_categories.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
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
  String? _service;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(swipeListingsProvider('worker'));

    return NeoNaiveScaffold(
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
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.transparent),
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
                            style:
                                AppTheme.displayItalic.copyWith(fontSize: 20)),
                        Text(
                          'Cleaners · chauffeurs · massage · guides · holistic',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.invalidate(swipeListingsProvider('worker')),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white70),
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
                    ('all', 'All rates'),
                    ('hour', 'Hourly'),
                    ('day', 'Daily'),
                    ('job', 'Per job'),
                    ('month', 'Monthly'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: NeoNaiveChip(
                        label: p.$2,
                        selected: _pricing == p.$1,
                        onSelected: () => setState(() => _pricing = p.$1),
                        selectedColor: AppTheme.brandPrimary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NeoNaiveChip(
                      label: 'All services',
                      selected: _service == null,
                      onSelected: () => setState(() => _service = null),
                      selectedColor: AppTheme.brandPrimary,
                    ),
                  ),
                  for (final s in serviceCategories.take(24))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: NeoNaiveChip(
                        label: s.label,
                        selected: _service == s.value,
                        onSelected: () =>
                            setState(() => _service = s.value),
                        selectedColor: AppTheme.brandPrimary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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
                data: (listings) {
                  final filtered = listings.where((l) {
                    if (_pricing != 'all' &&
                        (l.pricingUnit ?? '').toLowerCase() != _pricing) {
                      return false;
                    }
                    if (_service != null &&
                        (l.serviceCategory ?? '') != _service) {
                      return false;
                    }
                    return true;
                  }).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No workers match this filter yet.',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final listing = filtered[index];
                      return _WorkerCard(
                        listing: listing,
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ListingDetailScreen(listingData: listing),
                            ),
                          );
                        },
                      );
                    },
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
  const _WorkerCard({required this.listing, required this.onOpen});
  final Listing listing;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final image = listing.primaryImage;
    final service = serviceCategoryLabel(listing.serviceCategory);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 112,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.transparent),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: image == null
                    ? const ColoredBox(color: Color(0xFF16161C))
                    : Image.network(image, fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title ?? 'Worker',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.isEmpty ? 'Pro service' : service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        listing.formattedPrice,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
