import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
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
  String _zone = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(priceHistoryProvider);
    final currency = NumberFormat.compactCurrency(symbol: '\$');

    return NeoNaiveScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
                      ),
                      child: Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: MatteSurface.ink(context), size: 18),
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MARKET PRICES', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                        Text(
                          'Neighborhood averages from price_history',
                          style: GoogleFonts.plusJakartaSans(color: MatteSurface.muted(context), fontSize: 11),
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
                  child: CircularProgressIndicator(color: MatteSurface.ink(context), strokeWidth: 2),
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
                      child: Text(
                        'No price history yet.',
                        style: GoogleFonts.plusJakartaSans(color: MatteSurface.muted(context)),
                      ),
                    );
                  }
                  final zones = points.map((p) => p.neighborhood).toSet().toList()..sort();
                  final activeZones = _zone == 'all' ? zones : [_zone];
                  final stats = [
                    for (final zone in activeZones) _ZoneStats.from(points, zone),
                  ];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _ZoneChip(
                              label: 'All',
                              selected: _zone == 'all',
                              onTap: () => setState(() => _zone = 'all'),
                            ),
                            for (final zone in zones)
                              _ZoneChip(
                                label: zone,
                                selected: _zone == zone,
                                onTap: () => setState(() => _zone = zone),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      for (final stat in stats) ...[
                        Container(
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
                              Text(
                                stat.zone,
                                style: TextStyle(
                                  color: MatteSurface.ink(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(stat.current),
                                    style: const TextStyle(
                                      color: AppTheme.brandPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (stat.change >= 0 ? Colors.green : Colors.red).withAlpha(50),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${stat.change >= 0 ? '+' : ''}${stat.change.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: stat.change >= 0 ? Colors.greenAccent : Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${stat.count} listings · latest sample',
                                style: GoogleFonts.plusJakartaSans(color: MatteSurface.muted(context), fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              _MiniBars(points: stat.series.length > 8
                                  ? stat.series.sublist(stat.series.length - 8)
                                  : stat.series),
                            ],
                          ),
                        ),
                      ],
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

class _ZoneStats {
  const _ZoneStats({
    required this.zone,
    required this.current,
    required this.change,
    required this.count,
    required this.series,
  });

  final String zone;
  final double current;
  final double change;
  final int count;
  final List<PricePoint> series;

  factory _ZoneStats.from(List<PricePoint> all, String zone) {
    final series = all.where((p) => p.neighborhood == zone).toList()
      ..sort((a, b) {
        final ya = a.year.compareTo(b.year);
        return ya != 0 ? ya : a.month.compareTo(b.month);
      });
    if (series.isEmpty) {
      return _ZoneStats(zone: zone, current: 0, change: 0, count: 0, series: const []);
    }
    final current = series.last.avgPrice;
    final prev = series.length > 1 ? series[series.length - 2].avgPrice : current;
    final change = prev == 0 ? 0.0 : ((current - prev) / prev) * 100;
    return _ZoneStats(
      zone: zone,
      current: current,
      change: change,
      count: series.last.listingCount,
      series: series,
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.points});
  final List<PricePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final max = points.map((p) => p.avgPrice).fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 52 * (max <= 0 ? 0.1 : (point.avgPrice / max).clamp(0.08, 1.0)),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary.withAlpha(200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _monthLabel(point.month),
                      style: TextStyle(color: MatteSurface.faint(context), fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _monthLabel(int month) {
    const labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    if (month < 1 || month > 12) return '·';
    return labels[month - 1];
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
      padding: const EdgeInsets.only(right: 8),
      child: NeoNaiveChip(
        label: label,
        selected: selected,
        onSelected: () => onTap(),
        selectedColor: AppTheme.brandPrimary,
      ),
    );
  }
}
