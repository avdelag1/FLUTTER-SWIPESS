import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dashboard AI field.
///
/// Contract: mic is always the first control on the LEFT. Voice transcription
/// appears as real text in the field. No waveform is rendered here. Enter and
/// the send arrow answer on the dashboard; Intel Core opens only from Continue.
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

class _GlowSearchBarState extends State<GlowSearchBar> {
  final _random = math.Random();
  final _voice = LiveVoiceInput.instance;
  final _ai = AiEdgeRepository();

  late final FocusNode _focusNode = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _submitSearch(widget.controller?.text ?? '');
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

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

  bool get _isEditableSearch => widget.controller != null;

  bool get _showPrompt =>
      _isEditableSearch &&
      (widget.controller?.text.trim().isEmpty ?? true) &&
      !_focusNode.hasFocus &&
      !_voiceActive &&
      !_inlineAiLoading;

  String get _place {
    final value = widget.locationLabel.trim();
    return value.isEmpty ? 'your area' : value;
  }

  List<String> get _rotatingPrompts => <String>[
        'What are you looking for today?',
        'Show me something nearby',
        'Find a beautiful property in $_place',
        'What’s happening around $_place tonight?',
        'Find trusted workers near me',
        'Show me homes for rent',
        'Find a trusted mechanic',
        'Show me yachts nearby',
        'Find motorcycles around $_place',
        'Need local legal help in $_place?',
        'What’s popular around $_place right now?',
        'Show me something worth swiping',
      ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
    widget.controller?.addListener(_refresh);
    _schedulePrompt();
  }

  @override
  void didUpdateWidget(covariant GlowSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_refresh);
      widget.controller?.addListener(_refresh);
    }
    if (oldWidget.locationLabel != widget.locationLabel && mounted) {
      setState(() => _promptIndex = 0);
    }
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    _countdownTimer?.cancel();
    unawaited(_voice.cancel(owner: this));
    widget.controller?.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _schedulePrompt() {
    _promptTimer?.cancel();
    _promptTimer = Timer(Duration(milliseconds: 6000 + _random.nextInt(2001)), () {
      if (!mounted) return;
      if (_showPrompt) {
        final prompts = _rotatingPrompts;
        var next = _random.nextInt(prompts.length);
        while (next == _promptIndex && prompts.length > 1) {
          next = _random.nextInt(prompts.length);
        }
        setState(() => _promptIndex = next);
      }
      _schedulePrompt();
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  void _beginCountdown() {
    if (!mounted || _submittingVoice) return;
    if ((widget.controller?.text.trim() ?? '').isEmpty) return;
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
        // Real speech during the visible countdown cancels auto-send. Keep the
        // threshold high enough that ordinary room noise does not reset it.
        if (_countdown != null && level > -24.0) _cancelCountdown();
        final normalized = ((level + 45) / 45).clamp(0.0, 1.0).toDouble();
        setState(() => _voiceLevel = normalized);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _voiceActive = false;
          _voiceLevel = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  void _submitSearch(String raw) {
    final input = raw.trim();
    // Never open Intel Core because Enter/arrow was pressed on an empty field.
    if (input.isEmpty) return;

    if (!_runDirectSearch(input)) {
      unawaited(_runInlineAi(input));
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
                'Answer in 1-3 short sentences. Be useful and direct. Preserve useful '
                'SWIPESS action tags when needed.',
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
    if (question == null || question.isEmpty) return;
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

  String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _runDirectSearch(String raw) {
    final q = _normalize(raw);
    if (q.isEmpty) return false;

    final isQuestion = q.contains('?') ||
        RegExp(r'^(what|how|why|can|could|would|who|where|when|is|are|do|does)\b')
            .hasMatch(q);
    if (isQuestion && q.split(' ').length > 2) return false;

    bool has(String pattern) => RegExp(pattern).hasMatch(q);

    if (has(r'\b(events?|party|parties|nightlife|concert|festival|happening|tonight)\b')) {
      context.go(AppPaths.exploreEvents);
    } else if (has(r'\b(documents?|document vault|vault|paperwork|files?|pdfs?|passport files?|ids?)\b')) {
      context.go(AppPaths.documents);
    } else if (has(r'\b(legal|lawyer|lawyers|attorney|contract|contracts|lease|leases|fideicomiso|escrow|police help|legal help)\b')) {
      context.go(AppPaths.clientLegalServices);
    } else if (has(r'\b(workers?|hire|services?|maintenance|plumber|cleaner|cleaning|maid|chef|cook|driver|chauffeur|nanny|electrician|handyman|gardener|mechanic|contractor|painter|carpenter|welder|technician)\b')) {
      context.go(AppPaths.clientServices);
    } else if (has(r'\b(people|persons?|profiles?|users?|roommates?|seekers?|friends?|buyers?|renters?|gente|personas|amigos?)\b')) {
      context.go(AppPaths.exploreSeekers);
    } else if (has(r'\b(messages?|chat|inbox)\b')) {
      context.go(AppPaths.messages);
    } else if (has(r'\b(map|maps|near me|nearby|gps|passport|location|city|ciudad|zona|area)\b')) {
      context.go(AppPaths.map);
    } else if (has(r'\b(yachts?|boats?|catamarans?|sailboats?|yates?|barcos?)\b')) {
      openClientSwipeDeck(context, categoryId: 'yacht', categoryTitle: 'YACHTS');
    } else if (has(r'\b(motorcycles?|motorbikes?|motos?|scooters?|vespas?|motocicletas?)\b')) {
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
    } else if (has(r'\b(properties?|property|listings?|homes?|houses?|apartments?|rooms?|studios?|villas?|condos?|rentals?|rent|buy|sale|renta|casas?|departamentos?)\b')) {
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

  Widget _micButton({required bool isLight, required Color blue}) {
    final pulse = 1.0 + (_voiceLevel * .08);
    return Semantics(
      button: true,
      label: _voiceActive ? 'Stop recording' : 'Start voice search',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleVoice,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _voiceActive ? pulse : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _voiceActive ? blue : blue.withAlpha(isLight ? 18 : 34),
              shape: BoxShape.circle,
              border: Border.all(
                color: _voiceActive ? blue : blue.withAlpha(90),
              ),
              boxShadow: _voiceActive
                  ? [
                      BoxShadow(
                        color: blue.withAlpha(58),
                        blurRadius: 11 + (_voiceLevel * 9),
                        spreadRadius: _voiceLevel * 1.3,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (_voiceActive)
                  BreathingWidget(
                    duration: const Duration(milliseconds: 1050),
                    minOpacity: .55,
                    maxOpacity: 1,
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                else
                  Icon(Icons.mic_rounded, color: blue, size: 18),
                if (_countdown != null)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: blue, width: 1.3),
                      ),
                      child: Text(
                        '$_countdown',
                        style: GoogleFonts.plusJakartaSans(
                          color: blue,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: blue),
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
                    Expanded(
                      child: Text(
                        'Answer stays on Dashboard',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink.withAlpha(120),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _continueInChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: blue.withAlpha(isLight ? 18 : 32),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: blue.withAlpha(75)),
                        ),
                        child: Text(
                          'Continue in chat',
                          style: GoogleFonts.plusJakartaSans(
                            color: blue,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
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
    final displayHint = prompts[_promptIndex % prompts.length];
    final voiceVisible = _voiceActive || _countdown != null;

    if (!_isEditableSearch) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            height: 44,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isLight ? Colors.white.withAlpha(205) : const Color(0xFF121822),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: blue.withAlpha(130)),
            ),
            child: Text(displayHint, style: GoogleFonts.plusJakartaSans(color: ink)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            padding: const EdgeInsets.fromLTRB(6, 0, 3, 0),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withAlpha(205)
                  : const Color(0xFF121822).withAlpha(230),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: voiceVisible ? blue : blue.withAlpha(isLight ? 125 : 145),
                width: voiceVisible ? 1.5 : .9,
              ),
              boxShadow: voiceVisible
                  ? [
                      BoxShadow(
                        color: blue.withAlpha(38),
                        blurRadius: 15 + (_voiceLevel * 8),
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                _micButton(isLight: isLight, blue: blue),
                const SizedBox(width: 7),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (_showPrompt)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 380),
                                child: Text(
                                  displayHint,
                                  key: ValueKey<String>(displayHint),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: ink.withAlpha(isLight ? 190 : 225),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
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
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                        cursorColor: blue,
                        decoration: InputDecoration(
                          hintText: _voiceActive &&
                                  (widget.controller?.text.trim().isEmpty ?? true)
                              ? 'Listening…'
                              : null,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: blue.withAlpha(210),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Send',
                  onPressed: () => _submitSearch(widget.controller?.text ?? ''),
                  icon: Icon(Icons.arrow_forward_rounded, size: 19, color: ink),
                ),
              ],
            ),
          ),
          if (voiceVisible) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _countdown != null
                    ? 'Sending in $_countdown · speak again to keep recording'
                    : 'Listening · your words appear above',
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
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(isLight ? 135 : 170),
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
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
