import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
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
  final LiveVoiceInput _voice = LiveVoiceInput.instance;
  final AiEdgeRepository _ai = AiEdgeRepository();
  Timer? _promptTimer;
  Timer? _countdownTimer;
  int _promptIndex = 0;
  int? _countdown;
  double _voiceLevel = 0;
  bool _voiceActive = false;
  bool _submittingVoice = false;
  bool _inlineAiLoading = false;
  String? _inlineQuestion;
  String? _inlineAnswer;
  late final AnimationController _glintController;

  bool get _isEditableSearch => widget.controller != null;

  bool get _showPrompt {
    if (!_isEditableSearch) return true;
    return (widget.controller?.text.trim().isEmpty ?? true) &&
        !_focusNode.hasFocus &&
        !_voiceActive &&
        !_inlineAiLoading;
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
    _countdownTimer?.cancel();
    unawaited(_voice.cancel(owner: this));
    widget.controller?.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _glintController.dispose();
    super.dispose();
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  void _beginCountdown() {
    if (!mounted || _submittingVoice) return;
    final text = widget.controller?.text.trim() ?? '';
    if (text.isEmpty) return;
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _countdown ?? 0;
      if (current > 1) {
        setState(() => _countdown = current - 1);
        return;
      }
      timer.cancel();
      _countdownTimer = null;
      setState(() => _countdown = null);
      unawaited(_submitVoiceSearch());
    });
  }

  Future<void> _toggleVoice() async {
    if (!_isEditableSearch) {
      widget.onTap?.call();
      return;
    }

    if (_voice.isOwnedBy(this) || _voiceActive) {
      _cancelCountdown();
      await _voice.cancel(owner: this);
      if (mounted) {
        setState(() {
          _voiceActive = false;
          _voiceLevel = 0;
        });
      }
      return;
    }

    AppHaptics.light();
    _focusNode.requestFocus();
    final started = await _voice.start(
      owner: this,
      initialText: widget.controller?.text ?? '',
      onText: (text) {
        if (!mounted) return;
        _cancelCountdown();
        final controller = widget.controller;
        if (controller != null) {
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
        widget.onChanged?.call(text);
        setState(() => _voiceActive = true);
      },
      onSilence: _beginCountdown,
      onListeningChanged: (listening) {
        if (!mounted) return;
        setState(() {
          _voiceActive = listening;
          if (!listening) _voiceLevel = 0;
        });
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        final normalized = ((level + 45) / 45).clamp(0.0, 1.0);
        setState(() => _voiceLevel = normalized);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _voiceActive = false;
          _voiceLevel = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );

    if (mounted) {
      setState(() {
        _voiceActive = started;
        if (!started) _voiceLevel = 0;
      });
    }
  }

  Future<void> _submitVoiceSearch() async {
    if (_submittingVoice) return;
    _submittingVoice = true;
    _cancelCountdown();
    await _voice.finish(owner: this);
    if (mounted) {
      setState(() {
        _voiceActive = false;
        _voiceLevel = 0;
      });
    }
    final text = widget.controller?.text ?? '';
    _submitSearch(text);
    _submittingVoice = false;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _submitSearch(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      widget.onTap?.call();
      return;
    }

    if (!_runDirectSearch(input)) {
      // First conversational question is answered directly under the dashboard
      // field. A second free-form question means the user is continuing the
      // conversation, so expand into Intel Core through the existing callback.
      if (_inlineAnswer != null && !_inlineAiLoading) {
        widget.onSubmitted?.call(input);
      } else {
        unawaited(_runInlineAi(input));
      }
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _runInlineAi(String input) async {
    if (_inlineAiLoading) return;
    setState(() {
      _inlineAiLoading = true;
      _inlineQuestion = input;
      _inlineAnswer = null;
    });
    widget.controller?.clear();

    try {
      final reply = await _ai.chatConcierge(
        messages: [
          const AiChatMessage(
            role: 'system',
            content:
                'This reply is shown in the compact SWIPESS dashboard search area. '
                'Answer in 1-3 short sentences. Be useful and direct. Do not mention '
                'that this is a compact UI. Preserve any useful SWIPESS action tags.',
          ),
          AiChatMessage(role: 'user', content: input),
        ],
        locationContext: {
          'passportMode': true,
          'passportLabel': widget.locationLabel,
          'radiusKm': 50,
        },
        stream: false,
      );
      if (!mounted) return;
      final parsed = ConciergeParse.of(reply);
      final clean = parsed.cleanContent.trim();
      setState(() {
        _inlineAiLoading = false;
        _inlineAnswer = clean.isNotEmpty ? clean : reply.trim();
      });
    } on AiUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineAiLoading = false;
        _inlineAnswer = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineAiLoading = false;
        _inlineAnswer = 'AI is temporarily unavailable. Try again.';
      });
    }
  }

  void _continueInChat() {
    final question = _inlineQuestion?.trim();
    if (question == null || question.isEmpty) {
      widget.onTap?.call();
      return;
    }
    widget.onSubmitted?.call(question);
  }

  void _dismissInlineAi() {
    if (!mounted) return;
    setState(() {
      _inlineQuestion = null;
      _inlineAnswer = null;
      _inlineAiLoading = false;
    });
  }

  bool _runDirectSearch(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return false;
    final q = _normalize(input);
    
    // If the query is clearly a conversational question, answer it with AI
    // instead of routing to a screen. Short keyword lookups (e.g. "events",
    // "motorcycles near me") still hit the direct routes below.
    final isQuestion = q.contains('?') ||
        RegExp(r'^(what|how|why|can|could|would|who|where|when|is|are|do|does)\b').hasMatch(q);
    if (isQuestion && q.split(' ').length > 2) {
      return false;
    }

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
      return false;
    }

    widget.controller?.clear();
    return true;
  }

  Widget _voiceBars(Color color) {
    final level = _voiceLevel.clamp(0.0, 1.0);
    const multipliers = <double>[.52, 1, .68, .9, .45];
    return SizedBox(
      width: 24,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final multiplier in multipliers)
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              width: 3,
              height: 4 + (12 * level * multiplier),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ),
    );
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

  Widget _inlineAiPanel({
    required bool isLight,
    required Color ink,
    required Color blue,
  }) {
    final answer = _inlineAnswer;
    if (!_inlineAiLoading && (answer == null || answer.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: isLight ? blue.withAlpha(10) : blue.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: blue.withAlpha(isLight ? 70 : 90)),
      ),
      child: _inlineAiLoading
          ? Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: blue,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'Swipess AI is thinking…',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink.withAlpha(180),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: blue, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'SWIPESS AI',
                      style: GoogleFonts.plusJakartaSans(
                        color: blue,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismissInlineAi,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: ink.withAlpha(120),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  answer!,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Ask another question to continue in chat',
                      style: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(120),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _continueInChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: blue.withAlpha(isLight ? 18 : 32),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: blue.withAlpha(75)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue',
                              style: GoogleFonts.plusJakartaSans(
                                color: blue,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.arrow_outward_rounded,
                              color: blue,
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final blue = isLight ? const Color(0xFF2563EB) : const Color(0xFF60A5FA);
    final prompts = _rotatingPrompts;
    final safeIndex = _promptIndex % prompts.length;
    final displayHint = prompts[safeIndex];
    final voiceVisible = _voiceActive || _countdown != null;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isEditableSearch ? null : widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 44,
              padding: const EdgeInsets.only(left: 12, right: 3),
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.white.withAlpha(205)
                    : const Color(0xFF121822).withAlpha(230),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: voiceVisible
                      ? blue
                      : const Color(0xFF60A5FA).withAlpha(
                          isLight ? 125 : 145,
                        ),
                  width: voiceVisible ? 1.5 : .9,
                ),
                boxShadow: voiceVisible
                    ? [
                        BoxShadow(
                          color: blue.withAlpha(38),
                          blurRadius: 16 + (_voiceLevel * 10),
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.centerLeft,
              child: _isEditableSearch
                  ? Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (_showPrompt)
                          Positioned.fill(
                            right: 84,
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
                          onChanged: (value) {
                            _cancelCountdown();
                            widget.onChanged?.call(value);
                          },
                          onSubmitted: _submitSearch,
                          textInputAction: TextInputAction.search,
                          autofocus: false,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                          cursorColor: const Color(0xFF60A5FA),
                          decoration: InputDecoration(
                            prefixIcon: _voiceActive
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 7),
                                    child: Center(child: _voiceBars(blue)),
                                  )
                                : null,
                            prefixIconConstraints: _voiceActive
                                ? const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 38,
                                  )
                                : null,
                            hintText: _voiceActive
                                ? 'Recording — tap Stop when finished'
                                : null,
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: blue.withAlpha(190),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: _voiceActive
                                      ? 'Stop recording'
                                      : 'Speak your search',
                                  child: Semantics(
                                    button: true,
                                    label: _voiceActive
                                        ? 'Stop recording'
                                        : 'Start voice search',
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _toggleVoice,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: _voiceActive
                                              ? blue
                                              : blue.withAlpha(
                                                  isLight ? 18 : 34,
                                                ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _voiceActive
                                                ? blue
                                                : blue.withAlpha(90),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 110,
                                          ),
                                          child: _countdown != null
                                              ? Text(
                                                  '$_countdown',
                                                  key: ValueKey(_countdown),
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    color: _voiceActive
                                                        ? Colors.white
                                                        : blue,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                )
                                              : Icon(
                                                  _voiceActive
                                                      ? Icons.stop_rounded
                                                      : Icons.mic_rounded,
                                                  key: ValueKey(_voiceActive),
                                                  color: _voiceActive
                                                      ? Colors.white
                                                      : blue,
                                                  size: 18,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Search',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _submitSearch(
                                    widget.controller?.text ?? '',
                                  ),
                                  icon: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 19,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 76,
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
          if (voiceVisible) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _countdown != null
                    ? 'Sending in $_countdown · speak again to keep recording'
                    : 'Recording · waveform is live · tap Stop to transcribe',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
          _inlineAiPanel(isLight: isLight, ink: ink, blue: blue),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Swipess AI · can make mistakes.',
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
