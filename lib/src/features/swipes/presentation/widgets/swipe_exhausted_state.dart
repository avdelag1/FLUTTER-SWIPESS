import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `SwipeExhaustedState` — empty deck with radius, map, AI, categories.
class SwipeExhaustedState extends ConsumerStatefulWidget {
  const SwipeExhaustedState({
    super.key,
    required this.categoryName,
    required this.activeCategory,
    this.onBack,
    this.onRadiusChange,
    this.onDetectLocation,
    this.onOpenFilters,
    this.onOpenMap,
    this.onOpenAi,
    this.onCategoryChange,
    this.detecting = false,
    this.detected = false,
  });

  final String categoryName;
  final String activeCategory;
  final VoidCallback? onBack;
  final ValueChanged<int>? onRadiusChange;
  final VoidCallback? onDetectLocation;
  final VoidCallback? onOpenFilters;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenAi;
  final ValueChanged<String>? onCategoryChange;
  final bool detecting;
  final bool detected;

  @override
  ConsumerState<SwipeExhaustedState> createState() =>
      _SwipeExhaustedStateState();
}

class _SwipeExhaustedStateState extends ConsumerState<SwipeExhaustedState> {
  static const _kmSteps = [
    1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100,
  ];

  static const _clientCategories = [
    ('property', 'Properties'),
    ('motorcycle', 'Motorcycles'),
    ('bicycle', 'Bicycles'),
    ('yacht', 'Yachts'),
    ('services', 'Workers'),
  ];

  int _stepFor(int km) {
    var closest = 0;
    var minDiff = 1 << 20;
    for (var i = 0; i < _kmSteps.length; i++) {
      final diff = (_kmSteps[i] - km).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = i;
      }
    }
    return closest;
  }

  @override
  Widget build(BuildContext context) {
    final radiusKm = ref.watch(discoveryLocationProvider).radiusKm;
    final step = _stepFor(radiusKm);
    final others = _clientCategories
        .where((c) => c.$1 != widget.activeCategory)
        .toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Stack(
        children: [
          if (widget.onBack != null)
            Positioned(
              top: 12,
              left: 16,
              child: SafeArea(
                bottom: false,
                child: _GlassRoundButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: widget.onBack!,
                ),
              ),
            ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Text(
                      'No ${widget.categoryName} found nearby',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ADJUST RADIUS OR TRY ANOTHER CATEGORY',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(140),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                    if (widget.onRadiusChange != null) ...[
                      const SizedBox(height: 28),
                      _RadiusCard(
                        km: _kmSteps[step],
                        step: step,
                        maxStep: _kmSteps.length - 1,
                        detecting: widget.detecting,
                        detected: widget.detected,
                        onStep: (s) =>
                            widget.onRadiusChange!(_kmSteps[s]),
                        onDetect: widget.onDetectLocation,
                        onOpenFilters: widget.onOpenFilters,
                      ),
                    ],
                    if (widget.onOpenMap != null) ...[
                      const SizedBox(height: 16),
                      _MapCta(onTap: widget.onOpenMap!),
                    ],
                    if (widget.onOpenAi != null) ...[
                      const SizedBox(height: 16),
                      _AiCta(onTap: widget.onOpenAi!),
                    ],
                    if (widget.onCategoryChange != null &&
                        others.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'OR TRY ANOTHER',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(128),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: others.length >= 3 ? 3 : others.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.4,
                        children: [
                          for (final cat in others)
                            _CategoryChip(
                              label: cat.$2,
                              onTap: () =>
                                  widget.onCategoryChange!(cat.$1),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadiusCard extends StatelessWidget {
  const _RadiusCard({
    required this.km,
    required this.step,
    required this.maxStep,
    required this.onStep,
    this.onDetect,
    this.onOpenFilters,
    this.detecting = false,
    this.detected = false,
  });

  final int km;
  final int step;
  final int maxStep;
  final ValueChanged<int> onStep;
  final VoidCallback? onDetect;
  final VoidCallback? onOpenFilters;
  final bool detecting;
  final bool detected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 14,
                color: Colors.white.withAlpha(180),
              ),
              const SizedBox(width: 6),
              Text(
                'SEARCH RADIUS',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withAlpha(160),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                ),
              ),
              const Spacer(),
              if (onOpenFilters != null)
                _GlassRoundButton(
                  icon: Icons.tune_rounded,
                  size: 40,
                  iconSize: 16,
                  onTap: onOpenFilters!,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$km km',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTheme.brandPrimary,
              inactiveTrackColor: Colors.white.withAlpha(30),
              thumbColor: Colors.white,
              overlayColor: AppTheme.brandPrimary.withAlpha(40),
            ),
            child: Slider(
              value: step.toDouble(),
              min: 0,
              max: maxStep.toDouble(),
              divisions: maxStep,
              onChanged: (v) {
                AppHaptics.selection();
                onStep(v.round());
              },
            ),
          ),
          if (onDetect != null)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  onDetect!();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: detected
                        ? const Color(0x3334D399)
                        : Colors.white.withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: detected
                          ? const Color(0xFF34D399)
                          : Colors.white.withAlpha(40),
                    ),
                  ),
                  child: detecting
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          detected
                              ? Icons.check_rounded
                              : Icons.my_location_rounded,
                          color: detected
                              ? const Color(0xFF34D399)
                              : Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Move the slider to search further',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withAlpha(140),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCta extends StatelessWidget {
  const _MapCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.heavy();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppTheme.brandPrimary, Color(0xFFFC567E)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.transparent,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'EXPLORE ON LIVE MAP',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCta extends StatelessWidget {
  const _AiCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.heavy();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(31),
            color: const Color(0xE60A0A0C),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  gradient: LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Let AI Find Your Match',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "Describe what you're looking for",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(166),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        onTap();
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _GlassRoundButton extends StatelessWidget {
  const _GlassRoundButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(77),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x80000000), blurRadius: 24),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
