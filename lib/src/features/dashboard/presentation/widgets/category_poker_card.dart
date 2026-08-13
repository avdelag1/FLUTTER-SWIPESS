import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/liquid_glass.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/category_card.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryPokerCard extends StatefulWidget {
  const CategoryPokerCard({
    super.key,
    required this.card,
    required this.isTop,
    required this.onEngage,
  });

  final CategoryCardData card;
  final bool isTop;
  final VoidCallback onEngage;

  @override
  State<CategoryPokerCard> createState() => _CategoryPokerCardState();
}

class _CategoryPokerCardState extends State<CategoryPokerCard> {
  int _photoIndex = 0;

  @override
  void didUpdateWidget(covariant CategoryPokerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _photoIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.card.photos;
    final photo = photos[_photoIndex % photos.length];
    final compactLabel = widget.card.label.length <= 8;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Image.asset(photo, fit: BoxFit.cover),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x4D000000),
                  Color(0xCC000000),
                ],
                stops: [0.35, 0.62, 1],
              ),
            ),
          ),
          if (!widget.isTop)
            ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
          if (widget.isTop && photos.length > 1)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _photoIndex ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == _photoIndex
                            ? const Color(0xE6FFFFFF)
                            : const Color(0x59FFFFFF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 1,
                      color: const Color(0x66FFFFFF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.card.description.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.kicker.copyWith(
                          letterSpacing: 2.8,
                          shadows: const [
                            Shadow(color: Color(0xB3000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.card.label.toUpperCase(),
                  style: AppTheme.displayItalic.copyWith(
                    fontSize: compactLabel ? 42 : 32,
                    shadows: const [
                      Shadow(color: Color(0xD9000000), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: LiquidGlassPanel(
                    borderRadius: 16,
                    blur: LiquidGlass.blurSm,
                    weight: LiquidGlassWeight.thin,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.isTop
                            ? () {
                                HapticFeedback.mediumImpact();
                                widget.onEngage();
                              }
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'ENGAGE DISCOVERY',
                                  maxLines: 1,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: 2.2,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
