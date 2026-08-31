import 'package:flutter_swipes/src/features/ai/presentation/providers/ai_persona_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/voice_language_provider.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/voice_language_selector.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/domain/local_brain_relevance.dart';
import 'package:flutter_swipes/src/features/ai/domain/voice_transcript_normalize.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_result_cards.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/paywall_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dashboard AI field — live voice with 3-2-1 auto-send on silence.
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

class _GlowSearchBarState extends ConsumerState<GlowSearchBar>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Bright coral-red reads as active/recording without the harsh blood-red UI.
  static const _recordRed = Color(0xFFFF4D6D);
  static const _recordRedDeep = Color(0xFFE11D48);

  final _random = math.Random();

  final LiveVoiceInput _voice = LiveVoiceInput.instance;
  late final DeckAudioNotifier _audioNotifier;
  Timer? _countdownTimer;
  int? _countdown;
  Timer? _idleTimeoutTimer;
  Timer? _routeCheckTimer;
  bool _micSessionActive = false;
  String _liveTranscript = '';
  String? _pendingVoiceSubmit;
  bool _voiceSubmitting = false;

  // Adaptive voice activity guard. One noisy microphone spike is never enough
  // to cancel auto-send, but sustained energy while 3 -> 2 -> 1 is visible is
  // treated as the user talking again. Recognition stays alive so the next
  // transcript continues in the same field instead of cutting the user off.
  int _voiceActivitySamples = 0;
  double _voiceNoiseFloor = .08;
  bool _speechResumedWithoutText = false;
  String _speechResumeBaseline = '';

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
  List<Map<String, dynamic>> _inlineLocalBrain = const [];
  List<Map<String, dynamic>> _inlineProfiles = const [];
  List<Map<String, dynamic>> _inlineListings = const [];

  late final AnimationController _micPopCtrl;
  late final Animation<double> _micPopScale;
  late final AnimationController _micBreathCtrl;
  late final Animation<double> _micBreathScale;

  VoiceLanguage get _voiceLanguage => ref.read(voiceLanguageProvider);
  String get _voiceLocale => _voiceLanguage.localeCode;

  bool get _isListeningSession =>
      _micSessionActive && (_voiceActive || _voice.isOwnedBy(this));

  bool get _isRecordingGlow =>
      _isListeningSession && _countdown == null && !_transcribing;

  bool get _isEditableSearch => widget.controller != null;

  bool get _showPrompt =>
      _isEditableSearch &&
      (widget.controller?.text.trim().isEmpty ?? true) &&
      !_focusNode.hasFocus &&
      !_micSessionActive &&
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
    _audioNotifier = ref.read(deckSoundOnProvider.notifier);
    _micPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _micPopScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.84,
          end: 1.28,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.28,
          end: 0.99,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.99,
          end: 1.07,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 24,
      ),
    ]).animate(_micPopCtrl);
    _micBreathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
    _micBreathScale = Tween<double>(begin: 1.0, end: 1.045).animate(
      CurvedAnimation(parent: _micBreathCtrl, curve: Curves.easeInOutCubic),
    );
    _focusNode.addListener(_refresh);
    widget.controller?.addListener(_refresh);
    _schedulePrompt();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _idleTimeoutTimer?.cancel();
    _routeCheckTimer?.cancel();
    _promptTimer?.cancel();
    _countdownTimer?.cancel();
    _micPopCtrl.dispose();
    _micBreathCtrl.dispose();
    unawaited(_voice.cancel(owner: this));
    _restoreVoiceAudio();
    widget.controller?.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_micSessionActive || _voiceActive || _voice.isOwnedBy(this)) {
        _endContinuousSession();
      }
    }
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _triggerMicPop() {
    unawaited(_micPopCtrl.forward(from: 0));
    if (!_micBreathCtrl.isAnimating) _micBreathCtrl.repeat(reverse: true);
  }

  void _stopMicBreathing() {
    if (_micBreathCtrl.isAnimating) {
      _micBreathCtrl.stop();
      _micBreathCtrl.value = 0;
    }
    if (_micPopCtrl.value > 0) {
      unawaited(
        _micPopCtrl.animateBack(
          0,
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Future<void> _endContinuousSession() async {
    _cancelVoiceCountdown();
    _idleTimeoutTimer?.cancel();
    _routeCheckTimer?.cancel();
    _micSessionActive = false;
    _voiceActivitySamples = 0;
    _voiceNoiseFloor = .08;
    _speechResumedWithoutText = false;
    _speechResumeBaseline = '';
    _stopMicBreathing();
    await _voice.cancel(owner: this);
    if (!mounted) return;
    setState(() {
      _voiceActive = false;
      _transcribing = false;
      _voiceLevel = 0;
      _liveTranscript = '';
    });
    _restoreVoiceAudio();
  }

  void _handleVoiceLevel(double normalized) {
    if (!mounted) return;
    final level = normalized.clamp(0.0, 1.0).toDouble();

    if (_countdown == null && level < .55) {
      _voiceNoiseFloor = (_voiceNoiseFloor * .92) + (level * .08);
    }

    if (_countdown != null && _micSessionActive) {
      final activityThreshold = (_voiceNoiseFloor + .16).clamp(.24, .62);
      if (level >= activityThreshold) {
        _voiceActivitySamples += 1;
      } else {
        _voiceActivitySamples = 0;
      }

      // Three consecutive samples avoid cancelling on the brief energy spike
      // native recognizers can emit when a speech segment restarts.
      if (_voiceActivitySamples >= 3) {
        final controllerText = widget.controller?.text.trim() ?? '';
        final baseline = (_pendingVoiceSubmit?.trim().isNotEmpty ?? false)
            ? _pendingVoiceSubmit!.trim()
            : controllerText.isNotEmpty
            ? controllerText
            : _liveTranscript.trim();
        _voiceActivitySamples = 0;
        _speechResumedWithoutText = baseline.isNotEmpty;
        _speechResumeBaseline = baseline;
        _pendingVoiceSubmit = null;
        _cancelVoiceCountdown();
        _resetIdleTimeout();
        _startRouteCheck();
        setState(() {
          _voiceActive = true;
          _transcribing = false;
        });
      }
    }

    if ((_voiceLevel - level).abs() > .01) {
      setState(() => _voiceLevel = level);
    }
  }

  Future<void> _finalizeVoiceBeforeSubmit() async {
    _idleTimeoutTimer?.cancel();
    _routeCheckTimer?.cancel();
    _cancelVoiceCountdown();
    if (_voice.isOwnedBy(this) || _voiceActive || _micSessionActive) {
      try {
        await _voice.finish(owner: this);
      } catch (_) {
        await _voice.cancel(owner: this);
      }
    }
    _micSessionActive = false;
    _voiceActivitySamples = 0;
    _speechResumedWithoutText = false;
    _speechResumeBaseline = '';
    _stopMicBreathing();
    if (!mounted) return;
    setState(() {
      _voiceActive = false;
      _transcribing = false;
      _voiceLevel = 0;
    });
    _restoreVoiceAudio();
  }

  Future<void> _resumeListeningAfterSend() async {
    if (!_micSessionActive || !mounted) return;
    _liveTranscript = '';
    _pendingVoiceSubmit = null;
    _cancelVoiceCountdown();
    await _voice.cancel(owner: this);
    if (!mounted || !_micSessionActive) return;
    await _startLiveListening(animatePop: false);
  }

  void _resetIdleTimeout() {
    _idleTimeoutTimer?.cancel();
    _routeCheckTimer?.cancel();
    if (!_micSessionActive) return;
    _idleTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_micSessionActive) return;
      _endContinuousSession();
    });
  }

  void _startRouteCheck() {
    _routeCheckTimer?.cancel();
    _routeCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) {
        if (_micSessionActive || _voiceActive || _voice.isOwnedBy(this)) {
          _endContinuousSession();
        }
      }
    });
  }

  void _cancelVoiceCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _voiceActivitySamples = 0;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  void _beginVoiceCountdown() {
    if (!mounted ||
        _inlineAiLoading ||
        _countdown != null ||
        _voiceSubmitting ||
        !_micSessionActive) {
      return;
    }

    final controllerText = widget.controller?.text.trim() ?? '';
    final captured = controllerText.isNotEmpty
        ? controllerText
        : _liveTranscript.trim();
    if (captured.isEmpty) return;

    // If voice energy cancelled the previous countdown but the recognizer has
    // not produced additional words yet, keep listening instead of submitting
    // the old frozen phrase.
    if (_speechResumedWithoutText &&
        !shouldCancelVoiceCountdownForText(
          incoming: captured,
          locked: _speechResumeBaseline,
        )) {
      return;
    }
    _speechResumedWithoutText = false;
    _speechResumeBaseline = '';

    _pendingVoiceSubmit = captured;
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
      _voiceActive = true;
      _transcribing = false;
    });
    unawaited(AppHaptics.countdownTick(3));

    // Keep the recognizer alive during 3 -> 2 -> 1. If the user speaks again,
    // sustained voice activity or genuinely new transcript cancels this timer
    // and dictation continues instead of sending a chopped sentence.
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
      unawaited(AppHaptics.voiceCommit());
      unawaited(_submitCapturedVoice());
    });
  }

  Future<void> _submitCapturedVoice() async {
    if (_voiceSubmitting) return;
    _voiceSubmitting = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    try {
      final controllerText = widget.controller?.text.trim() ?? '';
      final text = (_pendingVoiceSubmit?.trim().isNotEmpty ?? false)
          ? _pendingVoiceSubmit!.trim()
          : controllerText.isNotEmpty
          ? controllerText
          : _liveTranscript.trim();

      _pendingVoiceSubmit = null;
      _speechResumedWithoutText = false;
      _speechResumeBaseline = '';
      if (!mounted) return;
      setState(() {
        _countdown = null;
        _transcribing = false;
        _voiceLevel = 0;
      });

      if (text.isEmpty) {
        _showVoiceError('I did not catch that. Please try speaking again.');
        if (_micSessionActive) await _resumeListeningAfterSend();
        return;
      }

      if (_inlineAiLoading) {
        _dismissInlineAi();
      }

      final controller = widget.controller;
      if (controller != null) {
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }

      await _finalizeVoiceBeforeSubmit();
      if (!mounted) return;
      _micSessionActive = false;
      await _submitSearch(text);
    } finally {
      _voiceSubmitting = false;
    }
  }

  Future<void> _toggleVoice() async {
    if (!_isEditableSearch) {
      widget.onTap?.call();
      return;
    }
    if (_inlineAiLoading) return;

    if (_micSessionActive || _voiceActive || _voice.isOwnedBy(this)) {
      await _endContinuousSession();
      return;
    }

    _micSessionActive = true;
    await _startLiveListening(animatePop: true);
  }

  Future<void> _startLiveListening({bool animatePop = true}) async {
    if (animatePop) unawaited(AppHaptics.voiceStart());
    FocusManager.instance.primaryFocus?.unfocus();
    _suppressVoiceAudio();
    if (animatePop) {
      _liveTranscript = widget.controller?.text.trim() ?? '';
      _pendingVoiceSubmit = null;
      _speechResumedWithoutText = false;
      _speechResumeBaseline = '';
      _voiceActivitySamples = 0;
      _voiceNoiseFloor = .08;
      _cancelVoiceCountdown();
      _triggerMicPop();
    }

    setState(() {
      _transcribing = true;
      _voiceLevel = 0;
      _micSessionActive = true;
    });
    _resetIdleTimeout();
    _startRouteCheck();

    final controller = widget.controller;
    final started = await _voice.start(
      languageCode: _voiceLocale,
      owner: this,
      initialText: controller?.text ?? '',
      restartAfterSilence: true,
      onText: (text) {
        if (!mounted || _voiceSubmitting) return;
        _resetIdleTimeout();
        _startRouteCheck();

        if (_speechResumedWithoutText &&
            shouldCancelVoiceCountdownForText(
              incoming: text,
              locked: _speechResumeBaseline,
            )) {
          _speechResumedWithoutText = false;
          _speechResumeBaseline = '';
        }

        if (_countdown != null) {
          final locked = _pendingVoiceSubmit ?? '';
          if (!shouldCancelVoiceCountdownForText(
            incoming: text,
            locked: locked,
          )) {
            return;
          }
          _pendingVoiceSubmit = null;
          _cancelVoiceCountdown();
        }
        _liveTranscript = text;

        if (controller != null) {
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          widget.onChanged?.call(text);
        }
        setState(() {
          _voiceActive = true;
          _transcribing = false;
        });
      },
      onSilence: _beginVoiceCountdown,
      onListeningChanged: (listening) {
        if (!mounted) return;
        if (listening) {
          if (!_voiceActive || _transcribing) {
            setState(() {
              _voiceActive = true;
              _transcribing = false;
            });
          }
          return;
        }
        if (_micSessionActive && _voice.isOwnedBy(this)) return;
        setState(() {
          _voiceActive = false;
          _transcribing = false;
          _voiceLevel = 0;
        });
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        final normalized = ((level + 45) / 45).clamp(0.0, 1.0).toDouble();
        _handleVoiceLevel(normalized);
      },
      onError: (message) {
        if (!mounted) return;
        final countdownOwnsCapturedText =
            _countdown != null &&
            (_pendingVoiceSubmit?.trim().isNotEmpty ?? false);
        if (countdownOwnsCapturedText) {
          setState(() {
            _voiceActive = false;
            _transcribing = false;
            _voiceLevel = 0;
          });
          return;
        }
        _cancelVoiceCountdown();
        unawaited(_voice.cancel(owner: this));
        _micSessionActive = false;
        setState(() {
          _voiceActive = false;
          _transcribing = false;
          _voiceLevel = 0;
        });
        _stopMicBreathing();
        _restoreVoiceAudio();
        _showVoiceError(message);
      },
    );

    if (!mounted) return;
    setState(() {
      _transcribing = false;
      _voiceActive = started && _voice.isOwnedBy(this) && _voice.active;
      if (!_voiceActive) _voiceLevel = 0;
    });
    if (!started) {
      _micSessionActive = false;
      _stopMicBreathing();
      _restoreVoiceAudio();
    }
  }

  Future<void> _submitSearch(String raw) async {
    _cancelVoiceCountdown();
    final input = normalizeVoiceTranscript(raw.trim());
    if (input.isEmpty) return;

    if (_micSessionActive || _voice.isOwnedBy(this) || _voiceActive) {
      await _finalizeVoiceBeforeSubmit();
      if (!mounted) return;
    }

    if (wantsExplicitNavigation(input) && _runDirectSearch(input)) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    await _runInlineAi(input);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  bool _wantsDirectoryContact(String raw) {
    final q = _normalize(normalizeVoiceTranscript(raw));
    if (q.isEmpty) return false;
    return directoryContactIntent.hasMatch(q) ||
        personDescriptorIntent.hasMatch(q);
  }

  bool _isSpecificPersonSearch(String raw) => isSpecificPersonSearch(raw);

  Future<void> _runInlineAi(String input) async {
    if (_inlineAiLoading) return;

    final subscription = ref.read(subscriptionProvider).value;
    if (subscription != null && subscription.effectiveTier.canUseAI != true) {
      if (!mounted) return;
      showPaywall(context, featureName: 'Google Gemini');
      return;
    }

    final loc = ref.read(discoveryLocationProvider);
    setState(() {
      _inlineAiLoading = true;
      _inlineQuestion = input;
      _inlineAnswer = null;
      _inlineLocalBrain = const [];
      _inlineProfiles = const [];
      _inlineListings = const [];
      _liveTranscript = '';
    });

    final contactQuery = _wantsDirectoryContact(input);
    final specificPersonQuery = _isSpecificPersonSearch(input);
    final character = ref.read(aiPersonaProvider).value ?? 'default';
    try {
      final reply = await ref
          .read(aiEdgeRepositoryProvider)
          .chatConcierge(
            character: character == 'default' ? null : character,
            messages: [
              const AiChatMessage(
                role: 'system',
                content:
                    'You answer inside the SWIPESS dashboard search bar. '
                    'Keep replies to 1-3 short sentences. Be direct and useful.\n\n'
                    'STAY ON DASHBOARD: never include [NAV:...] unless the user '
                    'explicitly asks to open another page or section.\n\n'
                    'CONTACT REQUESTS: only when the user explicitly asks for a person, worker, '
                    'business, recommendation, or contact, return trusted Local Brain matches. '
                    'For ordinary conversation, questions, greetings, or checks like are you there, '
                    'never return Local Brain/profile/contact cards. Keep the answer on Dashboard.\n\n'
                    'If the user asks to create a listing or event, tell them to '
                    'tap the + icon in the top right menu.',
              ),
              AiChatMessage(role: 'user', content: input),
            ],
            preferredIntent: contactQuery ? 'profiles' : null,
            locationContext: {
              'passportMode': false,
              'passportLabel': loc.label,
              'userLatitude': loc.latitude,
              'userLongitude': loc.longitude,
              'radiusKm': loc.radiusKm,
              'compactDashboard': true,
              'specificPersonSearch': specificPersonQuery,
              'responseLanguage': ref.read(voiceLanguageProvider).displayName,
            },
            stream: false,
          );
      if (!mounted) return;
      final parsed = ConciergeParse.of(reply);
      final clean = parsed.cleanContent.trim();
      final fallback = reply.trim();
      final declined = aiDeclinedContactMatch(clean.isNotEmpty ? clean : fallback);
      final filteredBrain = filterLocalBrainMatches(
        parsed.localBrain,
        input,
        specificPerson: specificPersonQuery,
      );
      final brain = specificPersonQuery
          ? filteredBrain.take(1).toList(growable: false)
          : filteredBrain.take(3).toList(growable: false);
      var answer = clean.isNotEmpty
          ? clean
          : fallback.isNotEmpty
          ? fallback
          : 'I heard you. Try asking in a different way or tap Continue in chat.';
      if (brain.isNotEmpty && declined) {
        final name = brain.first['name']?.toString().trim();
        answer = name != null && name.isNotEmpty
            ? 'Best match: $name.'
            : 'I found a trusted local contact for you.';
      }
      setState(() {
        _inlineAiLoading = false;
        _inlineAnswer = answer;
        _inlineLocalBrain = brain;
        _inlineProfiles = specificPersonQuery
            ? const <Map<String, dynamic>>[]
            : parsed.profiles;
        _inlineListings = parsed.listings;
      });
    } on AiUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineAiLoading = false;
        _inlineAnswer = error.message;
      });
    } catch (error, stackTrace) {
      debugPrint('Dashboard inline AI failed: $error\n$stackTrace');
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
      _inlineLocalBrain = const [];
      _inlineProfiles = const [];
      _inlineListings = const [];
      _inlineAiLoading = false;
    });
  }

  String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _runDirectSearch(String raw) {
    final q = _normalize(normalizeVoiceTranscript(raw));
    if (q.isEmpty) return false;

    bool has(String pattern) => RegExp(pattern).hasMatch(q);

    if (has(r'\b(events?|party|parties|nightlife|concert|festival)\b')) {
      context.go(AppPaths.exploreEvents);
    } else if (has(r'\b(documents?|document vault|vault)\b')) {
      context.go(AppPaths.documents);
    } else if (has(r'\b(legal|lawyers?|attorney)\b')) {
      context.go(AppPaths.clientLegalServices);
    } else if (has(r'\b(seekers?|people page)\b')) {
      context.go(AppPaths.exploreSeekers);
    } else if (has(r'\b(messages?|chat|inbox)\b')) {
      context.go(AppPaths.messages);
    } else if (has(r'\b(map|maps)\b')) {
      ref.read(overlayModalsProvider.notifier).openPassportMap();
    } else if (has(r'\b(yachts?|boats?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'yacht',
        categoryTitle: 'YACHTS',
      );
    } else if (has(r'\b(motorcycles?|motos?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'motorcycle',
        categoryTitle: 'MOTORCYCLES',
      );
    } else if (has(r'\b(bicycles?|bikes?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'bicycle',
        categoryTitle: 'BICYCLES',
      );
    } else if (has(r'\b(properties?|listings?|homes?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'property',
        categoryTitle: 'PROPERTIES',
      );
    } else if (has(r'\b(workers?|services?)\b')) {
      context.go(AppPaths.clientServices);
    } else {
      return false;
    }

    _dismissInlineAi();
    return true;
  }

  Widget _micButton({required bool isLight, required Color blue}) {
    final sessionActive = _micSessionActive;
    final glow = sessionActive ? _recordRed : blue;
    final deepGlow = sessionActive ? _recordRedDeep : blue;
    final pulse = 1.0 + (_voiceLevel * .035);
    final diameter = sessionActive ? 31.0 : 28.0;

    return Semantics(
      button: true,
      label: _countdown != null
          ? 'Voice search sends in $_countdown'
          : sessionActive
          ? 'Stop voice search'
          : 'Start voice search',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleVoice,
        child: AnimatedBuilder(
          animation: Listenable.merge([_micPopCtrl, _micBreathCtrl]),
          builder: (context, child) {
            final pop = _micPopCtrl.isAnimating || _micPopCtrl.value > 0
                ? _micPopScale.value
                : 1.0;
            final breath = _isRecordingGlow ? _micBreathScale.value : 1.0;
            final scale = pop * breath * (sessionActive ? pulse : 1.0);

            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  color: sessionActive
                      ? glow.withAlpha(245)
                      : blue.withAlpha(isLight ? 18 : 34),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sessionActive
                        ? Colors.white.withAlpha(78)
                        : blue.withAlpha(90),
                    width: sessionActive ? 1.1 : 1,
                  ),
                  boxShadow: sessionActive
                      ? [
                          BoxShadow(
                            color: glow.withAlpha(100),
                            blurRadius: 15 + (_voiceLevel * 9),
                            spreadRadius: .5 + (_voiceLevel * 1.2),
                          ),
                          BoxShadow(
                            color: deepGlow.withAlpha(48),
                            blurRadius: 27 + (_voiceLevel * 7),
                            spreadRadius: -4,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: _transcribing
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : _countdown != null
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Text(
                          '$_countdown',
                          key: ValueKey<int>(_countdown!),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16.5,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : sessionActive
                    ? const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 17,
                      )
                    : Icon(Icons.mic_none_rounded, color: blue, size: 16),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openContactInChat(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['full_name'] ?? data['title'])
        ?.toString()
        .trim();
    if (name == null || name.isEmpty) return;
    AppHaptics.selection();
    final encoded = base64UrlEncode(utf8.encode(jsonEncode(data)));
    _dismissInlineAi();
    widget.onSubmitted?.call('__swipess_contact__:$encoded');
  }

  Widget _inlineAiPanel({
    required bool isLight,
    required Color ink,
    required Color blue,
  }) {
    final answer = _inlineAnswer;
    final specificPerson = _isSpecificPersonSearch(_inlineQuestion ?? '');
    final brain = specificPerson
        ? _inlineLocalBrain.take(1).toList(growable: false)
        : _inlineLocalBrain.take(3).toList(growable: false);
    final profileSlots = specificPerson || brain.isNotEmpty
        ? 0
        : math.max(0, 3 - brain.length).toInt();
    final profiles = _inlineProfiles.take(profileSlots).toList(growable: false);
    final listings = _inlineListings.take(2).toList(growable: false);
    final hasResults =
        brain.isNotEmpty || profiles.isNotEmpty || listings.isNotEmpty;
    final hasQuestion = (_inlineQuestion?.trim().isNotEmpty ?? false);
    if (!_inlineAiLoading &&
        !hasQuestion &&
        (answer == null || answer.trim().isEmpty) &&
        !hasResults) {
      return const SizedBox.shrink();
    }

    final maxPanelHeight = math.min(
      360.0,
      MediaQuery.sizeOf(context).height * .42,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: isLight ? blue.withAlpha(10) : blue.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: blue.withAlpha(isLight ? 70 : 90)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isLight ? 10 : 34),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
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
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              child: SingleChildScrollView(
                primary: false,
                physics: const BouncingScrollPhysics(),
                child: Column(
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
                    if (answer != null && answer.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        answer,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (hasResults) ...[
                      if (answer != null && answer.trim().isNotEmpty)
                        const SizedBox(height: 9),
                      for (final entry in brain)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _DashboardContactPreview(
                            data: entry,
                            isLight: isLight,
                            accent: blue,
                            onTap: () => _openContactInChat(entry),
                          ),
                        ),
                      for (final profile in profiles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _DashboardContactPreview(
                            data: profile,
                            isLight: isLight,
                            accent: blue,
                            onTap: () => _openContactInChat(profile),
                          ),
                        ),
                      for (final listing in listings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IntelListingCard(data: listing),
                        ),
                    ],
                    const SizedBox(height: 5),
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
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navTabProvider, (prev, next) {
      if (prev != next) {
        if (_micSessionActive || _voiceActive || _voice.isOwnedBy(this)) {
          _endContinuousSession();
        }
      }
    });
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final blue = isLight ? const Color(0xFF2563EB) : const Color(0xFF60A5FA);
    final prompts = _rotatingPrompts;
    final displayHint = prompts[_promptIndex % prompts.length];
    final voiceVisible =
        _micSessionActive || _transcribing || _countdown != null;
    final sessionGlow = _micSessionActive ? _recordRed : blue;
    final sessionGlowDeep = _micSessionActive ? _recordRedDeep : blue;

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
            duration: Duration(milliseconds: voiceVisible ? 360 : 220),
            curve: voiceVisible ? Curves.easeOutBack : Curves.easeOutCubic,
            height: voiceVisible ? 48 : 44,
            padding: const EdgeInsets.fromLTRB(6, 0, 3, 0),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withAlpha(205)
                  : const Color(0xFF121822).withAlpha(230),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: voiceVisible
                    ? sessionGlow.withAlpha(210)
                    : blue.withAlpha(isLight ? 125 : 145),
                width: voiceVisible ? 1.35 : .9,
              ),
              boxShadow: voiceVisible
                  ? [
                      BoxShadow(
                        color: sessionGlow.withAlpha(52),
                        blurRadius: 20 + (_voiceLevel * 8),
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: sessionGlowDeep.withAlpha(28),
                        blurRadius: 34 + (_voiceLevel * 5),
                        spreadRadius: -7,
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
                          hintText: _transcribing
                              ? 'Transcribing your voice…'
                              : _voiceActive &&
                                    (widget.controller?.text.trim().isEmpty ??
                                        true)
                              ? 'Listening… speak naturally'
                              : null,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: sessionGlow.withAlpha(205),
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
                const SizedBox(width: 4),
                VoiceLanguageSelector(isLight: isLight),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Send',
                  onPressed: () {
                    final typed = widget.controller?.text.trim() ?? '';
                    _submitSearch(typed.isNotEmpty ? typed : _liveTranscript);
                  },
                  icon: Icon(Icons.arrow_forward_rounded, size: 19, color: ink),
                ),
              ],
            ),
          ),
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

class _DashboardContactPreview extends StatelessWidget {
  const _DashboardContactPreview({
    required this.data,
    required this.isLight,
    required this.accent,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final bool isLight;
  final Color accent;
  final VoidCallback onTap;

  String _first(List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final name = _first(['name', 'full_name', 'title']);
    final category = _first(['category', 'active_mode']);
    final city = _first(['city', 'location']);
    final description = _first(['recommendation_note', 'description']);
    final image = _first([
      'card_image_url',
      'photo_url',
      'avatar_url',
      'image',
    ]);
    final channels = <String>[
      if (_first(['whatsapp']).isNotEmpty) 'WhatsApp',
      if (_first(['instagram']).isNotEmpty) 'Instagram',
    ];
    final subtitle = [
      if (category.isNotEmpty) category,
      if (city.isNotEmpty && city.toLowerCase() != 'global') city,
    ].join(' · ');

    return Material(
      color: isLight ? Colors.white.withAlpha(180) : Colors.white.withAlpha(7),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(9, 9, 8, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: accent.withAlpha(isLight ? 34 : 48)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 39,
                height: 39,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: accent.withAlpha(isLight ? 16 : 28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        cacheWidth: 150,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.person_rounded, color: accent, size: 20),
                      )
                    : Icon(Icons.person_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Contact' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink.withAlpha(170),
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (channels.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          channels.join(' · '),
                          style: GoogleFonts.plusJakartaSans(
                            color: ink.withAlpha(115),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: ink.withAlpha(95),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
