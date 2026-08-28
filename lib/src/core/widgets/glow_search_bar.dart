import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/voice_language_provider.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/voice_language_selector.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';

/// Dashboard AI field.
///
/// Dashboard voice records the actual microphone audio and sends it to the
/// high-accuracy Whisper transcription backend. The amplitude stream keeps the
/// UI reactive while the user speaks; silence starts the existing 3 -> 2 -> 1
/// countdown, and speaking again cancels the countdown before transcription.
class GlowSearchBar extends ConsumerStatefulWidget {
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
  ConsumerState<GlowSearchBar> createState() => _GlowSearchBarState();
}

class _GlowSearchBarState extends ConsumerState<GlowSearchBar> {
  static final _directoryIntent = RegExp(
    r'\b(people|person|persons|users|profiles|seekers|roommate|roommates|workers|professionals|friends|contacts?|someone|somebody|alguien|persona|personas|contacto|contactos|expert|experts|specialist|specialists|who can help|need help|looking for someone|busco a|busco alguien|necesito alguien|quien me puede ayudar|quién me puede ayudar|gente|jeweler|jewellery|jewelry|joyeria|joyería|plumber|plomero|electrician|electricista|mechanic|mecanico|mecánico|cleaner|limpieza|chef|driver|chauffeur|nanny|handyman|gardener|contractor|painter|carpenter|welder|technician|lawyer|abogado|attorney|doctor|dentist|stylist|barber|massage|masaje|hire|contratar|recommend|recomienda|recomendar|numero|número|whatsapp|phone|call|trusted|local help|directory|directorio)\b',
    caseSensitive: false,
  );

  final _random = math.Random();

  late final VoiceTranscribeRepository _voiceRecorder;
  late final DeckAudioNotifier _audioNotifier;
  StreamSubscription<Amplitude>? _voiceAmplitudeSub;
  Timer? _voiceSilenceTimer;
  Timer? _countdownTimer;
  int? _countdown;
  bool _voiceHasSpeech = false;
  String _voiceInitialText = '';

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
  int _promptIndex = 0;
  double _voiceLevel = 0;
  bool _voiceActive = false;
  bool _transcribing = false;
  bool _voiceAudioSuppressed = false;
  bool _inlineAiLoading = false;
  String? _inlineQuestion;
  String? _inlineAnswer;

  bool get _isEditableSearch => widget.controller != null;

  bool get _showPrompt =>
      _isEditableSearch &&
      (widget.controller?.text.trim().isEmpty ?? true) &&
      !_focusNode.hasFocus &&
      !_voiceActive &&
      !_transcribing &&
      _countdown == null &&
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
    _voiceRecorder = ref.read(voiceTranscribeRepositoryProvider);
    _audioNotifier = ref.read(deckSoundOnProvider.notifier);
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
    _voiceSilenceTimer?.cancel();
    unawaited(_voiceAmplitudeSub?.cancel());
    unawaited(_voiceRecorder.cancel());
    _restoreVoiceAudio();
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
    _promptTimer = Timer(
      Duration(milliseconds: 6000 + _random.nextInt(2001)),
      () {
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
      },
    );
  }

  void _suppressVoiceAudio() {
    if (_voiceAudioSuppressed) return;
    _voiceAudioSuppressed = true;
    _audioNotifier.suspendTemporarily();
  }

  void _restoreVoiceAudio() {
    if (!_voiceAudioSuppressed) return;
    _voiceAudioSuppressed = false;
    _audioNotifier.resumeTemporarySound();
  }

  void _showVoiceError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _cancelVoiceCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  void _beginVoiceCountdown() {
    if (!mounted || !_voiceActive || !_voiceHasSpeech || _inlineAiLoading) {
      return;
    }
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    unawaited(AppHaptics.countdownTick(3));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _countdown ?? 0;
      if (current > 1) {
        final next = current - 1;
        setState(() => _countdown = next);
        unawaited(AppHaptics.countdownTick(next));
        return;
      }
      timer.cancel();
      _countdownTimer = null;
      setState(() => _countdown = null);
      unawaited(AppHaptics.voiceCommit());
      unawaited(_finishVoiceAndSubmit());
    });
  }

  Future<void> _finishVoiceAndSubmit() async {
    _cancelVoiceCountdown();
    _voiceSilenceTimer?.cancel();
    _voiceSilenceTimer = null;
    await _voiceAmplitudeSub?.cancel();
    _voiceAmplitudeSub = null;

    if (!_voiceActive) return;
    _voiceActive = false;
    if (mounted) {
      setState(() {
        _transcribing = true;
        _voiceLevel = 0;
      });
    }

    String transcript = '';
    String? voiceError;
    try {
      final language = ref.read(voiceLanguageProvider);
      transcript = await _voiceRecorder.stop(language: language.localeCode);
    } on VoiceTranscribeException catch (error) {
      voiceError = error.message;
    } catch (_) {
      voiceError = 'Could not transcribe that audio. Please try again.';
    }

    if (!mounted) {
      _restoreVoiceAudio();
      return;
    }

    setState(() {
      _transcribing = false;
      _voiceLevel = 0;
      _voiceHasSpeech = false;
    });
    _restoreVoiceAudio();

    if (voiceError != null) {
      _showVoiceError(voiceError);
      return;
    }

    final spoken = transcript.trim();
    if (spoken.isEmpty) {
      _showVoiceError('I did not catch that. Please try speaking again.');
      return;
    }

    final text = [_voiceInitialText.trim(), spoken]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
    _voiceInitialText = '';

    final controller = widget.controller;
    if (controller != null) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      widget.onChanged?.call(text);
    }
    _submitSearch(text);
  }

  Future<void> _toggleVoice() async {
    if (!_isEditableSearch) {
      widget.onTap?.call();
      return;
    }
    if (_inlineAiLoading || _transcribing) return;

    if (_voiceActive) {
      await _finishVoiceAndSubmit();
      return;
    }

    unawaited(AppHaptics.voiceStart());
    FocusManager.instance.primaryFocus?.unfocus();
    _suppressVoiceAudio();
    _voiceInitialText = widget.controller?.text.trim() ?? '';
    _voiceHasSpeech = false;

    setState(() {
      _transcribing = true;
      _voiceLevel = 0;
    });

    try {
      final started = await _voiceRecorder.start();
      if (!mounted) return;
      if (!started) {
        setState(() {
          _transcribing = false;
          _voiceActive = false;
          _voiceLevel = 0;
        });
        _restoreVoiceAudio();
        _showVoiceError(
          'Voice search could not start. Check microphone permission in Settings.',
        );
        return;
      }

      setState(() {
        _transcribing = false;
        _voiceActive = true;
        _voiceLevel = 0;
      });

      await _voiceAmplitudeSub?.cancel();
      _voiceAmplitudeSub = _voiceRecorder
          .amplitudeStream(interval: const Duration(milliseconds: 80))
          .listen((amplitude) {
            if (!mounted || !_voiceActive) return;
            final raw = amplitude.current;
            final normalized = raw.isFinite
                ? ((raw + 60) / 60).clamp(0.0, 1.0).toDouble()
                : 0.0;
            if ((_voiceLevel - normalized).abs() > .01) {
              setState(() => _voiceLevel = normalized);
            }

            // Typical speech is comfortably above -48 dBFS. Only arm silence
            // after actual voice energy so an open mic never auto-submits noise.
            if (raw.isFinite && raw > -48) {
              _voiceHasSpeech = true;
              _cancelVoiceCountdown();
              _voiceSilenceTimer?.cancel();
              _voiceSilenceTimer = Timer(
                const Duration(milliseconds: 2800),
                _beginVoiceCountdown,
              );
            }
          });
    } catch (_) {
      try {
        await _voiceRecorder.cancel();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _voiceActive = false;
        _voiceLevel = 0;
        _voiceHasSpeech = false;
      });
      _restoreVoiceAudio();
      _showVoiceError('Could not start voice search. Please try again.');
    }
  }

  void _submitSearch(String raw) {
    if (_voiceActive) {
      unawaited(_finishVoiceAndSubmit());
      return;
    }
    _cancelVoiceCountdown();
    final input = _normalizeVoiceTranscript(raw.trim());
    if (input.isEmpty || _inlineAiLoading) return;

    if (_wantsDirectoryContact(input)) {
      widget.controller?.clear();
      _dismissInlineAi();
      ref.read(overlayModalsProvider.notifier).openConcierge(input);
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    if (!_runDirectSearch(input)) {
      unawaited(_runInlineAi(input));
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  String _normalizeVoiceTranscript(String raw) {
    var text = raw;
    const fixes = <(String, String)>[
      ('context', 'contact'),
      ('contacts info', 'contact'),
      ('con tact', 'contact'),
      ('whats app', 'whatsapp'),
      ("what's app", 'whatsapp'),
    ];
    for (final (from, to) in fixes) {
      text = text.replaceAll(RegExp(from, caseSensitive: false), to);
    }
    return text;
  }

  bool _wantsDirectoryContact(String raw) {
    final q = _normalize(_normalizeVoiceTranscript(raw));
    if (q.isEmpty) return false;
    return _directoryIntent.hasMatch(q);
  }

  void _openDirectoryConcierge(String query) {
    widget.controller?.clear();
    _dismissInlineAi();
    ref.read(overlayModalsProvider.notifier).openConcierge(query);
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
      final reply = await ref
          .read(aiEdgeRepositoryProvider)
          .chatConcierge(
            messages: [
              const AiChatMessage(
                role: 'system',
                content:
                    'This reply is shown in the compact SWIPESS dashboard search area. '
                    'Answer in 1-3 short sentences. Be useful and direct. Preserve useful '
                    'SWIPESS action tags when needed.\n\n'
                    'IMPORTANT: If the user asks to add or create a listing, property, or event, '
                    'gently explain that they must tap the "+" icon in the top right menu, '
                    'or say "I can only help you browse from here! Please tap the + icon in the top right menu to create a listing."',
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
      if (parsed.localBrain.isNotEmpty ||
          parsed.profiles.isNotEmpty ||
          parsed.navPaths.any((path) => path.contains('seekers'))) {
        setState(() {
          _inlineAiLoading = false;
          _inlineQuestion = null;
          _inlineAnswer = null;
        });
        _openDirectoryConcierge(input);
        return;
      }
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

    final isQuestion =
        q.contains('?') ||
        RegExp(
          r'^(what|how|why|can|could|would|who|where|when|is|are|do|does)\b',
        ).hasMatch(q);
    if (isQuestion && q.split(' ').length > 2) return false;

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
    } else if (has(r'\b(messages?|chat|inbox)\b')) {
      context.go(AppPaths.messages);
    } else if (has(
      r'\b(map|maps|near me|nearby|gps|passport|location|city|ciudad|zona|area)\b',
    )) {
      ref.read(overlayModalsProvider.notifier).openPassportMap();
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

  Widget _micButton({required bool isLight, required Color blue}) {
    final pulse = 1.0 + (_voiceLevel * .08);
    return Semantics(
      button: true,
      label: _countdown != null
          ? 'Voice search sends in $_countdown'
          : _voiceActive
          ? 'Finish voice search now'
          : 'Start voice search',
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
            child: _countdown != null
                ? Text(
                    '$_countdown',
                    key: ValueKey<int>(_countdown!),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  )
                : _transcribing
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: blue,
                    ),
                  )
                : _voiceActive
                ? BreathingWidget(
                    duration: const Duration(milliseconds: 1050),
                    minOpacity: .55,
                    maxOpacity: 1,
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                : Icon(Icons.mic_rounded, color: blue, size: 18),
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
                  'Google Gemini is thinking…',
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
                      'GOOGLE GEMINI',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
    final voiceVisible = _voiceActive || _transcribing || _countdown != null;

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
              color: isLight
                  ? Colors.white.withAlpha(205)
                  : const Color(0xFF121822),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: blue.withAlpha(130)),
            ),
            child: Text(
              displayHint,
              style: GoogleFonts.plusJakartaSans(color: ink),
            ),
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
                color: voiceVisible
                    ? blue
                    : blue.withAlpha(isLight ? 125 : 145),
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
                if (_voiceActive) ...[
                  const SizedBox(width: 4),
                  VoiceLanguageSelector(isLight: isLight),
                ],
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
                                layoutBuilder:
                                    (currentChild, previousChildren) {
                                      return Stack(
                                        alignment: Alignment.centerLeft,
                                        children: <Widget>[
                                          ...previousChildren,
                                          if (currentChild != null)
                                            currentChild,
                                        ],
                                      );
                                    },
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
                        onChanged: widget.onChanged,
                        onSubmitted: _submitSearch,
                        textInputAction: TextInputAction.search,
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                        cursorColor: blue,
                        decoration: InputDecoration(
                          hintText: _countdown != null
                              ? 'Sending in $_countdown…'
                              : _voiceActive &&
                                    (widget.controller?.text.trim().isEmpty ??
                                        true)
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
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
                    ? 'Silence detected · sending in $_countdown…'
                    : 'Listening… speak naturally',
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
              'Google Gemini · can make mistakes.',
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
