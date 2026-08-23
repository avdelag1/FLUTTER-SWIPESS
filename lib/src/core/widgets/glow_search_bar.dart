import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowSearchBar extends StatefulWidget {
  const GlowSearchBar({
    super.key,
    this.hint = 'What are you looking for?',
    this.onTap,
    this.controller,
    this.onChanged,
    this.onSubmitted,
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
  final ValueChanged<String>? onSubmitted;
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
  final math.Random _random = math.Random();
  final FocusNode _focusNode = FocusNode();
  Timer? _promptTimer;
  int _promptIndex = 0;
  late final AnimationController _glintController;

  bool get _isEditableSearch => widget.controller != null;

  bool get _showPrompt {
    if (!_isEditableSearch) return true;
    return (widget.controller?.text.trim().isEmpty ?? true) &&
        !_focusNode.hasFocus;
  }

  String get _place {
    final value = widget.locationLabel.trim();
    return value.isEmpty ? 'your area' : value;
  }

  List<String> get _rotatingPrompts {
    final place = _place;
    return <String>[
      'What are you looking for today?',
      'Show me something nearby',
      'Find a beautiful property in $place',
      'What’s happening around $place tonight?',
      'Find trusted workers near me',
      'Show me homes for rent',
      'Find a trusted mechanic',
      'Show me yachts nearby',
      'Find motorcycles around $place',
      'Need local legal help in $place?',
      'What’s popular around $place right now?',
      'Show me something worth swiping',
    ];
  }

  @override
  void initState() {
    super.initState();
    _glintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _focusNode.addListener(_handleFocusChanged);
    widget.controller?.addListener(_handleControllerChanged);
    _scheduleNextPrompt();
  }

  @override
  void didUpdateWidget(covariant GlowSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
    }
    if (oldWidget.locationLabel != widget.locationLabel) {
      _promptIndex = 0;
      if (mounted) _glintController.forward(from: 0);
    }
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleNextPrompt() {
    _promptTimer?.cancel();
    final delay = Duration(milliseconds: 6000 + _random.nextInt(2001));
    _promptTimer = Timer(delay, () {
      if (!mounted) return;
      if (_showPrompt) {
        final prompts = _rotatingPrompts;
        if (prompts.length > 1) {
          var next = _random.nextInt(prompts.length);
          while (next == _promptIndex) {
            next = _random.nextInt(prompts.length);
          }
          setState(() => _promptIndex = next);
          _glintController.forward(from: 0);
        }
      }
      _scheduleNextPrompt();
    });
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    widget.controller?.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _glintController.dispose();
    super.dispose();
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _runDirectSearch(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return;
    final q = _normalize(input);
    bool has(String pattern) => RegExp(pattern).hasMatch(q);

    if (has(
      r'\b(events?|party|parties|nightlife|concert|festival|happening|tonight)\b',
    )) {
      context.go(AppPaths.exploreEvents);
    } else if (has(
      r'\b(documents?|document vault|vault|paperwork|files?|pdfs?|passport files?|ids?)\b',
    )) {
      context.go(AppPaths.documents);
    } else if (has(
      r'\b(legal|lawyer|lawyers|attorney|contract|contracts|lease|leases|fideicomiso|escrow|police help|legal help)\b',
    )) {
      context.go(AppPaths.clientLegalServices);
    } else if (has(
      r'\b(workers?|hire|services?|maintenance|plumber|cleaner|cleaning|maid|chef|cook|driver|chauffeur|nanny|electrician|handyman|gardener|mechanic|contractor|painter|carpenter|welder|technician)\b',
    )) {
      context.go(AppPaths.clientServices);
    } else if (has(
      r'\b(people|persons?|profiles?|users?|roommates?|seekers?|friends?|buyers?|renters?|gente|personas|amigos?)\b',
    )) {
      context.go(AppPaths.exploreSeekers);
    } else if (has(r'\b(messages?|chat|inbox)\b')) {
      context.go(AppPaths.messages);
    } else if (has(
      r'\b(map|maps|near me|nearby|gps|passport|location|city|ciudad|zona|area)\b',
    )) {
      context.go(AppPaths.map);
    } else if (has(
      r'\b(yachts?|boats?|catamarans?|sailboats?|yates?|barcos?)\b',
    )) {
      openClientSwipeDeck(
        context,
        categoryId: 'yacht',
        categoryTitle: 'YACHTS',
      );
    } else if (has(
      r'\b(motorcycles?|motorbikes?|motos?|scooters?|vespas?|motocicletas?)\b',
    )) {
      openClientSwipeDeck(
        context,
        categoryId: 'motorcycle',
        categoryTitle: 'MOTORCYCLES',
      );
    } else if (has(r'\b(bicycles?|bikes?|bicis?|bicicletas?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'bicycle',
        categoryTitle: 'BICYCLES',
      );
    } else if (has(
      r'\b(properties?|property|listings?|homes?|houses?|apartments?|rooms?|studios?|villas?|condos?|rentals?|rent|buy|sale|renta|casas?|departamentos?)\b',
    )) {
      openClientSwipeDeck(
        context,
        categoryId: 'property',
        categoryTitle: 'PROPERTIES',
      );
    } else {
      context.go(
        '${AppPaths.clientFilters}?q=${Uri.encodeQueryComponent(input)}',
      );
    }

    widget.controller?.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _animatedPrompt({
    required String text,
    required Color ink,
    required bool isLight,
    required Key key,
  }) {
    final base = ink.withAlpha(isLight ? 190 : 225);
    final highlight = isLight ? const Color(0xFF6D9FEA) : Colors.white;

    return AnimatedBuilder(
      animation: _glintController,
      child: Text(
        text,
        key: key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          color: ink,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
          letterSpacing: .02,
        ),
      ),
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(
          _glintController.value,
        );
        final x = -2.2 + (progress * 4.4);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x - .8, 0),
            end: Alignment(x + .8, 0),
            colors: [base, base, highlight, base, base],
            stops: const [0, .30, .50, .70, 1],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }

  Widget _promptSwitcher({
    required String text,
    required Color ink,
    required bool isLight,
    required int index,
  }) {
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 620),
        reverseDuration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.centerLeft,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .16),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: .985, end: 1).animate(curved),
                child: child,
              ),
            ),
          );
        },
        child: _animatedPrompt(
          text: text,
          ink: ink,
          isLight: isLight,
          key: ValueKey<String>('${widget.locationLabel}:$index:$text'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final prompts = _rotatingPrompts;
    final safeIndex = _promptIndex % prompts.length;
    final displayHint = prompts[safeIndex];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isEditableSearch ? null : widget.onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 16, right: 5),
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
              child: _isEditableSearch
                  ? Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (_showPrompt)
                          Positioned.fill(
                            right: 42,
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _promptSwitcher(
                                  text: displayHint,
                                  ink: ink,
                                  isLight: isLight,
                                  index: safeIndex,
                                ),
                              ),
                            ),
                          ),
                        TextField(
                          focusNode: _focusNode,
                          controller: widget.controller,
                          onChanged: widget.onChanged,
                          onSubmitted: _runDirectSearch,
                          textInputAction: TextInputAction.search,
                          autofocus: false,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                          cursorColor: const Color(0xFF60A5FA),
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              tooltip: 'Search',
                              onPressed: () => _runDirectSearch(
                                widget.controller?.text ?? '',
                              ),
                              icon: Icon(
                                Icons.arrow_forward_rounded,
                                size: 19,
                                color: ink,
                              ),
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 38,
                              minHeight: 38,
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
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 11,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.only(right: 11),
                      child: _promptSwitcher(
                        text: displayHint,
                        ink: ink,
                        isLight: isLight,
                        index: safeIndex,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Powered by Gemini · AI can make mistakes.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(isLight ? 135 : 170),
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
                letterSpacing: .02,
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
      ),
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
          color: isLight ? Colors.black.withAlpha(20) : Colors.transparent,
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
