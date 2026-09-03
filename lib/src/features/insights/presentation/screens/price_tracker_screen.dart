import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/insights/domain/price_point.dart';
import 'package:flutter_swipes/src/features/insights/presentation/providers/insights_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PriceTrackerScreen extends ConsumerStatefulWidget {
  const PriceTrackerScreen({super.key});

  @override
  ConsumerState<PriceTrackerScreen> createState() => _PriceTrackerScreenState();
}

class _PriceTrackerScreenState extends ConsumerState<PriceTrackerScreen> {
  String _zoneKey = 'all';

  String _key(PricePoint point) =>
      '${point.neighborhood.toLowerCase()}|${point.currency.toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(priceHistoryProvider);

    return NeoNaiveScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const CapBackButton(),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SWIPESS ASKING PRICES',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          'Live averages from active property listings inside Swipess',
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: MatteSurface.ink(context),
                    strokeWidth: 2,
                  ),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(priceHistoryProvider),
                    child: Text('Could not load prices — retry'),
                  ),
                ),
                data: (points) {
                  if (points.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'Not enough active priced listings in the same area yet. Swipess only shows an area average when at least two comparable listing prices are available.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            height: 1.45,
                          ),
                        ),
                      ),
                    );
                  }

                  final visible = _zoneKey == 'all'
                      ? points
                      : points.where((point) => _key(point) == _zoneKey).toList();

                  return ListView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 34),
                    children: [
                      _AccuracyNote(
                        sampleCount: points.fold<int>(
                          0,
                          (sum, p) => sum + p.listingCount,
                        ),
                      ),
                      SizedBox(height: 14),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _ZoneChip(
                              label: 'All',
                              selected: _zoneKey == 'all',
                              onTap: () => setState(() => _zoneKey = 'all'),
                            ),
                            for (final point in points)
                              _ZoneChip(
                                label:
                                    '${point.neighborhood} · ${point.currency}',
                                selected: _zoneKey == _key(point),
                                onTap: () =>
                                    setState(() => _zoneKey = _key(point)),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      for (final point in visible)
                        _MarketPriceCard(point: point),
                    ],
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

class _AccuracyNote extends StatelessWidget {
  const _AccuracyNote({required this.sampleCount});

  final int sampleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.brandPrimary.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.brandPrimary.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: AppTheme.brandPrimary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'REAL SWIPESS DATA · $sampleCount active priced listings in the displayed samples. These are asking prices posted by Swipess users—not closed-sale prices, an appraisal, MLS data, or a complete Tulum market index.',
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.muted(context),
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketPriceCard extends StatelessWidget {
  const _MarketPriceCard({required this.point});

  final PricePoint point;

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.decimalPattern().format(point.avgPrice.round());
    final sampleLabel = point.listingCount <= 2
        ? 'SMALL SAMPLE'
        : point.listingCount <= 5
        ? 'LIMITED SAMPLE'
        : 'STRONGER SAMPLE';
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  point.neighborhood,
                  style: TextStyle(
                    color: MatteSurface.ink(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: MatteSurface.hairline(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  point.currency,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.ink(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '${point.currency} $amount',
            style: TextStyle(
              color: AppTheme.brandPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Average asking price · ${point.listingCount} listings',
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 12,
            ),
          ),
          SizedBox(height: 7),
          Text(
            sampleLabel,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.faint(context),
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: NeoNaiveChip(
        label: label,
        selected: selected,
        onSelected: onTap,
        selectedColor: AppTheme.brandPrimary,
      ),
    );
  }
}
