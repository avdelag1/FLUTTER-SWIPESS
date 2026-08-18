import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowSearchBar extends StatefulWidget {
  const GlowSearchBar({
    super.key,
    this.hint = 'What are you looking for?',
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
      'What are you looking for today?',
      'Find something worth your time',
      'Show me something nearby',
      'What’s happening around $place tonight?',
      'Find a great place to eat in $place',
      'Show me homes for rent in $place',
      'Find trusted workers in $place',
      'Find a private chef in $place',
      'Need local legal help in $place?',
      'What’s popular around $place right now?',
      'Create a listing in $place',
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
      _promptIndex = 0;
    }
    if (_isTapOnly != wasTapOnly) {
      _startPromptRotation();
    }
  }

  void _startPromptRotation() {
    _promptTimer?.cancel();
    if (!_isTapOnly) return;
    _promptTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted) return;
      final prompts = _rotatingPrompts;
      setState(() => _promptIndex = (_promptIndex + 1) % prompts.length);
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
    final prompts = _rotatingPrompts;
    final safeIndex = _promptIndex % prompts.length;
    final displayHint = _isTapOnly ? prompts[safeIndex] : widget.hint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withAlpha(205)
                  : const Color(0xFF121822).withAlpha(230),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF60A5FA).withAlpha(isLight ? 125 : 145),
                width: .9,
              ),
            ),
            alignment: Alignment.centerLeft,
            child: _isTapOnly
                ? RepaintBoundary(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 520),
                      reverseDuration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
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
                          fontSize: 14.5,
                          letterSpacing: .02,
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
                      fontSize: 14.5,
                    ),
                    cursorColor: const Color(0xFF60A5FA),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(130),
                        fontWeight: FontWeight.w500,
                        fontSize: 14.5,
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
            const SizedBox(width: 6),
            Expanded(
              child: _outerPill(
                Icons.calendar_month_rounded,
                widget.dateLabel,
                ink,
                isLight,
                widget.onDatesTap,
              ),
            ),
            const SizedBox(width: 6),
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
    final pill = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withAlpha(190)
            : const Color(0xFF171C25).withAlpha(235),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isLight
              ? Colors.black.withAlpha(20)
              : Colors.white.withAlpha(34),
          width: .6,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ink.withAlpha(235), size: 13),
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
