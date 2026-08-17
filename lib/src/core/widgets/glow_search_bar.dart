import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowSearchBar extends StatefulWidget {
  const GlowSearchBar({
    super.key,
    this.hint = 'Search Swipess',
    this.onTap,
    this.controller,
    this.onChanged,
    this.locationLabel = 'Tulum',
    this.dateLabel = 'Any date',
    this.guestLabel = '1 guest',
    this.onLocationTap,
    this.onDatesTap,
    this.onGuestsTap,
  });

  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String locationLabel;
  final String dateLabel;
  final String guestLabel;
  final VoidCallback? onLocationTap;
  final VoidCallback? onDatesTap;
  final VoidCallback? onGuestsTap;

  @override
  State<GlowSearchBar> createState() => _GlowSearchBarState();
}

class _GlowSearchBarState extends State<GlowSearchBar>
    with SingleTickerProviderStateMixin {
  static const _rotatingPrompts = <String>[
    'Ask anything',
    'Want to find the best properties?',
    'Looking to make a reservation?',
    'Need a massage expert nearby?',
    'Find a private chef for tonight',
    'Looking for a yacht in Tulum?',
    'Need a trusted local lawyer?',
    'What’s happening in Tulum tonight?',
    'Find a cleaner or maintenance expert',
    'Want AI to create your listing?',
  ];

  Timer? _promptTimer;
  Timer? _shineTimer;
  int _promptIndex = 0;
  late final AnimationController _shineController;

  bool get _isTapOnly => widget.onTap != null && widget.onChanged == null;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _startPromptRotation();
    _startShinePulse();
  }

  @override
  void didUpdateWidget(covariant GlowSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasTapOnly = oldWidget.onTap != null && oldWidget.onChanged == null;
    if (_isTapOnly != wasTapOnly) {
      _startPromptRotation();
      _startShinePulse();
    }
  }

  void _startPromptRotation() {
    _promptTimer?.cancel();
    if (!_isTapOnly) return;
    _promptTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() {
        _promptIndex = (_promptIndex + 1) % _rotatingPrompts.length;
      });
    });
  }

  void _startShinePulse() {
    _shineTimer?.cancel();
    _shineController.reset();
    if (!_isTapOnly) return;

    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _isTapOnly) _runShine();
    });
    _shineTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _isTapOnly) _runShine();
    });
  }

  Future<void> _runShine() async {
    if (_shineController.isAnimating) return;
    await _shineController.forward(from: 0);
    if (mounted) _shineController.reset();
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    _shineTimer?.cancel();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final muted = ink.withAlpha(150);
    final displayHint = _isTapOnly
        ? _rotatingPrompts[_promptIndex]
        : widget.hint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.white.withAlpha(178)
                      : Colors.black.withAlpha(18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(
                      0xFF60A5FA,
                    ).withAlpha(isLight ? 160 : 180),
                    width: 1.05,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF60A5FA,
                      ).withAlpha(isLight ? 22 : 16),
                      blurRadius: 10,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 18),
                    Expanded(
                      child: _isTapOnly
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 650),
                                reverseDuration: const Duration(
                                  milliseconds: 420,
                                ),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0, .18),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  final scale = Tween<double>(
                                    begin: .985,
                                    end: 1,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: ScaleTransition(
                                        scale: scale,
                                        alignment: Alignment.centerLeft,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: AnimatedBuilder(
                                  key: ValueKey(_promptIndex),
                                  animation: _shineController,
                                  child: Text(
                                    displayHint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      letterSpacing: .05,
                                    ),
                                  ),
                                  builder: (context, child) {
                                    final sweep = _shineController.value;
                                    return ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (bounds) {
                                        final x = -2.4 + (sweep * 4.8);
                                        return LinearGradient(
                                          begin: Alignment(x - .75, 0),
                                          end: Alignment(x + .75, 0),
                                          colors: [
                                            ink.withAlpha(145),
                                            const Color(0xFF93C5FD),
                                            Colors.white,
                                            const Color(0xFF60A5FA),
                                            ink.withAlpha(145),
                                          ],
                                          stops: const [0, .34, .5, .66, 1],
                                        ).createShader(bounds);
                                      },
                                      child: child,
                                    );
                                  },
                                ),
                              ),
                            )
                          : TextField(
                              controller: widget.controller,
                              onChanged: widget.onChanged,
                              style: GoogleFonts.plusJakartaSans(
                                color: ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              cursorColor: const Color(0xFF60A5FA),
                              decoration: InputDecoration(
                                hintText: widget.hint,
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  color: ink.withAlpha(130),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF60A5FA),
              size: 11,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Powered by Gemini · AI may make mistakes.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                  letterSpacing: .15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _outerPill(
                Icons.location_on_rounded,
                widget.locationLabel,
                ink,
                isLight,
                widget.onLocationTap,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _outerPill(
                Icons.calendar_month_rounded,
                widget.dateLabel,
                ink,
                isLight,
                widget.onDatesTap,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _outerPill(
                Icons.person_rounded,
                widget.guestLabel,
                ink,
                isLight,
                widget.onGuestsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _outerPill(
    IconData icon,
    String label,
    Color ink,
    bool isLight,
    VoidCallback? onTap,
  ) {
    final pill = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 33,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withAlpha(145)
                : Colors.white.withAlpha(11),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isLight
                  ? Colors.black.withAlpha(22)
                  : Colors.white.withAlpha(38),
              width: .6,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ink.withAlpha(240), size: 13),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return pill;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: pill,
      ),
    );
  }
}
