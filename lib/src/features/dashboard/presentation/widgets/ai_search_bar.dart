import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/breathing_widget.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/live_audio_waveform.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/search_frame_shine.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dashboard AI search + compact concierge response.
///
/// Voice contract: mic stays on the LEFT, words and waveform stay in this field,
/// 4 seconds of silence starts a visible 3 -> 2 -> 1 countdown, then the query
/// is answered on the dashboard. Intel Core only opens from the explicit
/// Continue button.
class AiSearchBar extends ConsumerStatefulWidget {
  const AiSearchBar({super.key});

  @override
  ConsumerState<AiSearchBar> createState() => _AiSearchBarState();
}

class _AiSearchBarState extends ConsumerState<AiSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _voice = LiveVoiceInput.instance;
  final _ai = AiEdgeRepository();

  bool _voiceActive = false;
  double _voiceLevel = 0;
  int? _countdown;
  Timer? _countdownTimer;
  bool _submitting = false;
  bool _inlineLoading = false;
  String? _inlineQuestion;
  String? _inlineAnswer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    unawaited(_voice.cancel(owner: this));
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  void _beginCountdown() {
    if (!mounted || _controller.text.trim().isEmpty || _submitting) return;
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
      unawaited(_runSearch());
    });
  }

  Future<void> _toggleVoice() async {
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
    _focus.requestFocus();
    final started = await _voice.start(
      owner: this,
      initialText: _controller.text,
      onText: (text) {
        if (!mounted) return;
        _cancelCountdown();
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
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
        if (_countdown != null && level > -30.0) {
          _cancelCountdown();
        }
        final normalized = ((level + 45) / 45).clamp(0.0, 1.0).toDouble();
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

  Future<void> _runSearch() async {
    if (_submitting) return;
    _submitting = true;
    _cancelCountdown();
    await _voice.finish(owner: this);
    if (mounted) {
      setState(() {
        _voiceActive = false;
        _voiceLevel = 0;
      });
    }

    final q = _controller.text.trim();
    _focus.unfocus();
    if (q.isEmpty) {
      _submitting = false;
      return;
    }

    AppHaptics.selection();
    try {
      if (_routeKeyword(q)) {
        _controller.clear();
        return;
      }
      await _runInlineAi(q);
    } finally {
      _submitting = false;
    }
  }

  Future<void> _runInlineAi(String input) async {
    if (!mounted || _inlineLoading) return;
    setState(() {
      _inlineLoading = true;
      _inlineQuestion = input;
      _inlineAnswer = '';
    });
    _controller.clear();

    final messages = <AiChatMessage>[
      const AiChatMessage(
        role: 'system',
        content:
            'This answer is displayed directly on the SWIPESS dashboard. '
            'Answer quickly in 1-3 useful sentences. Be direct and concise. '
            'Preserve useful SWIPESS action tags when needed.',
      ),
      AiChatMessage(role: 'user', content: input),
    ];

    String reply = '';
    try {
      await for (final delta in _ai.chatConciergeTokens(
        messages: messages,
        locationContext: const {
          'passportMode': true,
          'radiusKm': 50,
        },
      )) {
        if (!mounted) return;
        reply += delta;
        final parsed = ConciergeParse.of(reply);
        final visible = parsed.cleanContent.trim();
        setState(() {
          _inlineAnswer = visible.isNotEmpty ? visible : reply.trim();
        });
      }

      if (reply.trim().isEmpty) {
        reply = await _ai.chatConcierge(
          messages: messages,
          locationContext: const {
            'passportMode': true,
            'radiusKm': 50,
          },
          stream: false,
        );
      }

      if (!mounted) return;
      final parsed = ConciergeParse.of(reply);
      final clean = parsed.cleanContent.trim();
      setState(() {
        _inlineLoading = false;
        _inlineAnswer = clean.isNotEmpty ? clean : reply.trim();
      });
    } on AiUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineLoading = false;
        _inlineAnswer = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineLoading = false;
        _inlineAnswer = 'AI is temporarily unavailable. Try again.';
      });
    }
  }

  void _continueInChat() {
    final question = _inlineQuestion?.trim();
    if (question == null || question.isEmpty) return;
    unawaited(showIntelCoreSheet(context, initialQuery: question));
  }

  void _dismissInline() {
    if (!mounted) return;
    setState(() {
      _inlineLoading = false;
      _inlineQuestion = null;
      _inlineAnswer = null;
    });
  }

  bool _routeKeyword(String input) {
    final q = _normalize(input);
    bool has(String pattern) => RegExp(pattern).hasMatch(q);

    if (has(r'\b(legal admin|lawyer admin|admin legal)\b')) {
      context.go(AppPaths.legalAdminDashboard);
      return true;
    }
    if (has(r'\b(admin|back office|control panel|dashboard admin)\b')) {
      context.go(AppPaths.adminDashboard);
      return true;
    }
    if (has(r'\b(business|owner dashboard|owner side|landlord|host dashboard)\b')) {
      context.go(AppPaths.ownerDashboard);
      return true;
    }
    if (has(r'\b(documents?|document vault|vault|paperwork|files?|pdfs?|passport files?|ids?)\b')) {
      context.go(AppPaths.documents);
      return true;
    }
    if (has(r'\b(map|maps|near me|nearby|gps|passport|location|city|ciudad|zona|area)\b')) {
      ref.read(overlayModalsProvider.notifier).openPassportMap();
      return true;
    }
    if (has(r'\b(events?|party|parties|nightlife|concert|festival|happening|tonight)\b')) {
      context.go(AppPaths.exploreEvents);
      return true;
    }
    if (has(r'\b(legal|lawyer|lawyers|attorney|contract|contracts|fideicomiso|escrow|police help|legal help)\b')) {
      context.go(AppPaths.clientLegalServices);
      return true;
    }
    if (has(r'\b(workers?|hire|services?|maintenance|plumber|cleaner|cleaning|maid|chef|cook|driver|chauffeur|nanny|electrician|handyman|gardener|mechanic|contractor|painter|carpenter|welder|technician)\b')) {
      context.go(AppPaths.clientServices);
      return true;
    }
    if (has(r'\b(people|persons?|profiles?|users?|roommates?|seekers?|friends?|buyers?|renters?|gente|personas|amigos?)\b')) {
      context.go(AppPaths.exploreSeekers);
      return true;
    }
    if (has(r'\b(yachts?|boats?|catamarans?|sailboats?|yates?|barcos?)\b')) {
      openClientSwipeDeck(context, categoryId: 'yacht', categoryTitle: 'YACHTS');
      return true;
    }
    if (has(r'\b(motorcycles?|motorbikes?|motos?|scooters?|vespas?|motocicletas?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'motorcycle',
        categoryTitle: 'MOTORCYCLES',
      );
      return true;
    }
    if (has(r'\b(bicycles?|bikes?|bicis?|bicicletas?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'bicycle',
        categoryTitle: 'BICYCLES',
      );
      return true;
    }
    if (has(r'\b(properties?|property|listings?|homes?|houses?|apartments?|rooms?|studios?|villas?|condos?|rentals?|rent|buy|sale|renta|casas?|departamentos?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'property',
        categoryTitle: 'PROPERTIES',
      );
      return true;
    }
    if (has(r'\b(filters?|filter search|search filters)\b')) {
      context.go(AppPaths.clientFilters);
      return true;
    }
    return false;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _micButton({required bool isLight, required Color glow}) {
    final pulseScale = 1.0 + (_voiceLevel * .08);
    return Semantics(
      button: true,
      label: _voiceActive ? 'Stop recording' : 'Start voice search',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleVoice,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _voiceActive ? pulseScale : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _voiceActive
                  ? glow
                  : glow.withAlpha(isLight ? 18 : 30),
              shape: BoxShape.circle,
              border: Border.all(
                color: _voiceActive ? glow : glow.withAlpha(100),
              ),
              boxShadow: _voiceActive
                  ? [
                      BoxShadow(
                        color: glow.withAlpha(75),
                        blurRadius: 14 + (_voiceLevel * 12),
                        spreadRadius: _voiceLevel * 2,
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
                    duration: const Duration(milliseconds: 1100),
                    minOpacity: .55,
                    maxOpacity: 1,
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                else
                  Icon(Icons.mic_rounded, color: glow, size: 21),
                if (_countdown != null)
                  Positioned(
                    right: -5,
                    top: -6,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: glow, width: 1.4),
                      ),
                      child: Text(
                        '$_countdown',
                        style: GoogleFonts.plusJakartaSans(
                          color: glow,
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

  Widget _inlinePanel({required bool isLight, required Color ink, required Color glow}) {
    final answer = _inlineAnswer;
    if (!_inlineLoading && (answer == null || answer.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: isLight ? glow.withAlpha(10) : glow.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: glow.withAlpha(70)),
      ),
      child: _inlineLoading && (answer == null || answer.isEmpty)
          ? Row(
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: glow),
                ),
                const SizedBox(width: 8),
                Text(
                  'Swipess AI is thinking…',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink.withAlpha(180),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: glow, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      _inlineLoading ? 'SWIPESS AI · ANSWERING' : 'SWIPESS AI',
                      style: GoogleFonts.plusJakartaSans(
                        color: glow,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: .8,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _dismissInline,
                      child: Icon(Icons.close_rounded, size: 16, color: ink.withAlpha(120)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  answer ?? '',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _continueInChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: glow.withAlpha(isLight ? 18 : 32),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: glow.withAlpha(75)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Continue in chat',
                            style: GoogleFonts.plusJakartaSans(
                              color: glow,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_outward_rounded, color: glow, size: 13),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(isLightThemeProvider);
    final glow = isLight ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD);
    final frame = isLight ? const Color(0xFF2563EB) : const Color(0xFF60A5FA);
    final fill = AppTheme.wellFor(isLight: isLight);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final voiceVisible = _voiceActive || _countdown != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SearchFrameShine(
          color: glow,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 56,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: voiceVisible ? glow : frame,
                width: voiceVisible ? 2 : 1.5,
              ),
              boxShadow: voiceVisible
                  ? [
                      BoxShadow(
                        color: glow.withAlpha(38),
                        blurRadius: 18 + (_voiceLevel * 10),
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                _micButton(isLight: isLight, glow: glow),
                if (_voiceActive) ...[
                  const SizedBox(width: 7),
                  LiveAudioWaveform(
                    active: true,
                    level: _voiceLevel,
                    color: glow,
                    width: 66,
                    height: 22,
                    samples: 22,
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.1,
                    ),
                    cursorColor: glow,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: _voiceActive
                          ? (_countdown != null
                                ? 'Sending in $_countdown…'
                                : 'Listening… your words appear here')
                          : 'Search properties, workers, people, events...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: _voiceActive ? glow : ink.withAlpha(140),
                        fontWeight: _voiceActive
                            ? FontWeight.w800
                            : FontWeight.w500,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                    onChanged: (_) => _cancelCountdown(),
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                IconButton(
                  onPressed: _submitting ? null : _runSearch,
                  tooltip: 'Send',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: glow.withAlpha(230),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
        if (voiceVisible) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _countdown != null
                  ? 'Silence detected · sending in $_countdown'
                  : 'Listening · stop speaking for 4 seconds to send',
              style: GoogleFonts.plusJakartaSans(
                color: glow,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        _inlinePanel(isLight: isLight, ink: ink, glow: glow),
      ],
    );
  }
}
