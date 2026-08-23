import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `OwnerFilters` — leads / motos / bikes / jobs + client intent chips.
class OwnerFiltersScreen extends ConsumerStatefulWidget {
  const OwnerFiltersScreen({super.key});

  @override
  ConsumerState<OwnerFiltersScreen> createState() => _OwnerFiltersScreenState();
}

class _OwnerFiltersScreenState extends ConsumerState<OwnerFiltersScreen> {
  String _category = 'property';
  String _clientType = 'all';

  static const _cats = [
    ('property', 'Leads', Icons.home_rounded),
    ('motorcycle', 'Motos', Icons.two_wheeler_rounded),
    ('bicycle', 'Bikes', Icons.pedal_bike_rounded),
    ('worker', 'Jobs', Icons.work_rounded),
  ];

  static const _intents = [
    ('all', 'All'),
    ('buy', 'Buy'),
    ('rent', 'Rent'),
    ('hire', 'Hire'),
    ('individual', 'Individual'),
    ('family', 'Family'),
    ('business', 'Business'),
  ];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return NeoNaiveScaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, top + 12, 20, 40),
        children: [
          const CapBackButton(),
          const SizedBox(height: 16),
          Text(
            'OWNER FILTERS',
            style: AppTheme.displayItalic.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Who should see your listings',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _cats)
                _chip(c.$2, _category == c.$1, () {
                  setState(() => _category = c.$1);
                }),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'CLIENT INTENT',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _intents)
                _chip(c.$2, _clientType == c.$1, () {
                  setState(() => _clientType = c.$1);
                }),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                AppHaptics.medium();
                final interest = switch (_clientType) {
                  'buy' => 'sale',
                  'rent' => 'rent',
                  _ => 'both',
                };
                ref
                    .read(swipeFilterProvider.notifier)
                    .replace(
                      SwipeFilter(category: _category, interestType: interest),
                    );
                context.go(AppPaths.clientDashboard);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'APPLY FILTERS',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: on ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
