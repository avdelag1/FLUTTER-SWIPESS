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

class _GlowSearchBarState extends State<GlowSearchBar> {
  Timer? _promptTimer;
  int _promptIndex = 0;

  bool get _isTapOnly => widget.onTap != null && widget.onChanged == null;

  String get _place {
    final value = widget.locationLabel.trim();
    return value.isEmpty ? 'your area' : value;
  }

  List<String> get _rotatingPrompts {
    final place = _place;
    return <String>[
      'Ask Swipess anything about $place',
      'What’s happening in $place tonight?',
      'Book a great table in $place',
      'Find a private chef in $place',
      'Show me homes for rent in $place',
      'Find trusted workers in $place',
      'Need a massage expert in $place?',
      'Need local legal help in $place?',
      'What’s popular around $place right now?',
      'Create a listing in $place with AI',
    ];
  }

  @override
  void initState() {
    super.initState();
    _startPromptRotation();
  }

  @override
  void didUpdateWidget(covariant GlowSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasTapOnly = oldWidget.onTap != null && oldWidget.onChanged == null;

    if (oldWidget.locationLabel != widget.locationLabel) {
      // A city change should be reflected immediately instead of waiting for
      // the next timer tick. AnimatedSwitcher handles the visual transition.
      _promptIndex = 0;
    }

    if (_isTapOnly != wasTapOnly) {
      _startPromptRotation();
    }
  }

  void _startPromptRotation() {
    _promptTimer?.cancel();
    if (!_isTapOnly) return;

    // Keep this intentionally lightweight and slower than media rotations.
    // Only this small text subtree changes; videos/maps/cards are unaffected.
    _promptTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final prompts = _rotatingPrompts;
      setState(() {
        _promptIndex = (_promptIndex + 1) % prompts.length;
      });
    });
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final muted = ink.withAlpha(150);
    final prompts = _rotatingPrompts;
    final safeIndex = _promptIndex % prompts.length;
    final displayHint = _isTapOnly ? prompts[safeIndex] : widget.hint;

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
                    color: const Color(0xFF60A5FA)
                        .withAlpha(isLight ? 160 : 180),
                    width: 1.05,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF60A5FA)
                          .withAlpha(isLight ? 22 : 16),
                      blurRadius: 10,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    if (_isTapOnly) ...[
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF60A5FA),
                        size: 16,
                      ),
                      const SizedBox(width: 9),
                    ],
                    Expanded(
                      child: _isTapOnly
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: RepaintBoundary(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 900),
                                  reverseDuration:
                                      const Duration(milliseconds: 700),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  layoutBuilder: (currentChild, previousChildren) {
                                    return Stack(
                                      alignment: Alignment.centerLeft,
                                      children: <Widget>[
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    );
                                  },
                                  transitionBuilder: (child, animation) {
                                    final fade = CurvedAnimation(
                                      parent: animation,
                                      curve: const Interval(
                                        .08,
                                        1,
                                        curve: Curves.easeOutCubic,
                                      ),
                                      reverseCurve: Curves.easeInCubic,
                                    );
                                    final slide = Tween<Offset>(
                                      begin: const Offset(0, .07),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                        reverseCurve: Curves.easeInCubic,
                                      ),
                                    );
                                    return FadeTransition(
                                      opacity: fade,
                                      child: SlideTransition(
                                        position: slide,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    displayHint,
                                    key: ValueKey<String>(
                                      '${widget.locationLabel}:$safeIndex:$displayHint',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: ink.withAlpha(225),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      letterSpacing: .05,
                                    ),
                                  ),
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
