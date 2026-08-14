import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glow_search_bar.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/category_card.dart';
import 'package:google_fonts/google_fonts.dart';

class _ChipSpec {
  const _ChipSpec(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

const _chips = [
  _ChipSpec('Properties', Color(0xFFFF4D4D), Icons.apartment_rounded),
  _ChipSpec('Events', Color(0xFF3B82F6), Icons.celebration_rounded),
  _ChipSpec('Pros', Color(0xFFEAB308), Icons.auto_awesome),
];

/// Capacitor dashboard home: glow search, category pills, photo card grid.
class DiscoverHomeScreen extends StatefulWidget {
  const DiscoverHomeScreen({
    super.key,
    required this.onOpenSwipe,
    required this.onOpenEvents,
  });

  final ValueChanged<String> onOpenSwipe;
  final VoidCallback onOpenEvents;

  @override
  State<DiscoverHomeScreen> createState() => _DiscoverHomeScreenState();
}

class _DiscoverHomeScreenState extends State<DiscoverHomeScreen> {
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: AppTheme.dashBg,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 72, 20, 0),
              child: Column(
                children: [
                  GlowSearchBar(onTap: () => widget.onOpenSwipe('property')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var i = 0; i < _chips.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _CategoryChip(
                            spec: _chips[i],
                            selected: _chip == i,
                            onTap: () {
                              AppHaptics.selection();
                              setState(() => _chip = i);
                              if (i == 1) {
                                widget.onOpenEvents();
                              } else {
                                widget.onOpenSwipe(i == 2 ? 'worker' : 'property');
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) {
                    return _PhotoTile(
                      image: AppAssets.filterEvents,
                      label: 'Events',
                      onTap: widget.onOpenEvents,
                    );
                  }
                  final card = dashboardCategories[(index - 1) % dashboardCategories.length];
                  return _PhotoTile(
                    image: card.photos.first,
                    label: card.label,
                    onTap: () => widget.onOpenSwipe(_listingCategoryFor(card.id)),
                  );
                },
                childCount: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _listingCategoryFor(String cardId) {
  return switch (cardId) {
    'pros' => 'worker',
    'buyers' || 'renters' || 'leads' => 'property',
    _ => cardId,
  };
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _ChipSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        decoration: BoxDecoration(
          color: selected ? spec.color.withValues(alpha: 0.18) : const Color(0x14101016),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? spec.color.withValues(alpha: 0.7) : const Color(0x33FFFFFF),
          ),
          boxShadow: selected
              ? [BoxShadow(color: spec.color.withValues(alpha: 0.35), blurRadius: 12)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: spec.color.withValues(alpha: 0.25),
                border: Border.all(color: spec.color, width: 1.2),
              ),
              child: Icon(spec.icon, size: 10, color: spec.color),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spec.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.image,
    required this.label,
    required this.onTap,
  });

  final String image;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x40FFFFFF)),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(image, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                right: 12,
                child: Text(
                  label.toUpperCase(),
                  style: AppTheme.displayItalic.copyWith(
                    fontSize: 18,
                    shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 8)],
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
