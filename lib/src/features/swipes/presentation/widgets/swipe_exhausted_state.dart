import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Empty state for real swipe/discovery categories only.
/// Full product sections such as Legal, Events, Seekers and Premium route
/// directly from the dashboard and should never land on this screen.
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
  static const _kmSteps = [1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100];

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
    final canvas = MatteSurface.canvas(context);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return ColoredBox(
      color: canvas,
      child: Stack(
        children: [
          if (widget.onBack != null)
            Positioned(
              top: 12,
              left: 16,
              child: SafeArea(
                bottom: false,
                child: _RoundAction(
                  icon: Icons.chevron_left_rounded,
                  onTap: widget.onBack!,
                ),
              ),
            ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 76, 24, 34),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Text(
                      'No ${widget.categoryName} found nearby',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Move the radius or try another discovery category.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.onRadiusChange != null) ...[
                      const SizedBox(height: 24),
                      _RadiusCard(
                        km: _kmSteps[step],
                        step: step,
                        maxStep: _kmSteps.length - 1,
                        detecting: widget.detecting,
                        detected: widget.detected,
                        onStep: (s) => widget.onRadiusChange!(_kmSteps[s]),
                        onDetect: widget.onDetectLocation,
                        onOpenFilters: widget.onOpenFilters,
                      ),
                    ],
                    if (widget.onOpenMap != null) ...[
                      const SizedBox(height: 12),
                      _PrimaryAction(
                        icon: Icons.map_outlined,
                        label: 'Explore on live map',
                        onTap: widget.onOpenMap!,
                      ),
                    ],
                    if (widget.onOpenAi != null) ...[
                      const SizedBox(height: 10),
                      _SecondaryAction(onTap: widget.onOpenAi!),
                    ],
                    if (widget.onCategoryChange != null && others.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'TRY ANOTHER',
                          style: GoogleFonts.plusJakartaSans(
                            color: muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cat in others)
                            _CategoryChip(
                              label: cat.$2,
                              onTap: () => widget.onCategoryChange!(cat.$1),
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
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 14, color: muted),
              const SizedBox(width: 6),
              Text(
                'SEARCH RADIUS',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (onOpenFilters != null)
                _RoundAction(
                  icon: Icons.tune_rounded,
                  onTap: onOpenFilters!,
                  size: 38,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$km km',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTheme.brandPrimary,
              inactiveTrackColor: ink.withAlpha(24),
              thumbColor: ink,
              overlayColor: AppTheme.brandPrimary.withAlpha(32),
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
              child: _RoundAction(
                icon: detected ? Icons.check_rounded : Icons.my_location_rounded,
                onTap: onDetect!,
                size: 38,
                busy: detecting,
                accent: detected ? const Color(0xFF34D399) : null,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Move the slider to search further',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
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
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [AppTheme.brandPrimary, Color(0xFFFC567E)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Let AI find your match',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    "Describe what you're looking for",
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted, size: 18),
          ],
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
    final ink = MatteSurface.ink(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: ink,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.busy = false,
    this.accent,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool busy;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return GestureDetector(
      onTap: busy
          ? null
          : () {
              AppHaptics.light();
              onTap();
            },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: MatteSurface.cardFill(context),
          shape: BoxShape.circle,
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent ?? ink,
                ),
              )
            : Icon(icon, color: accent ?? ink, size: size * .45),
      ),
    );
  }
}
