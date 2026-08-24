import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/intel_core_sheet.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/search_frame_shine.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Keyword-first dashboard search with hands-free live dictation.
///
/// Voice interaction contract:
/// tap mic → partial words appear immediately → 4 seconds of silence → visible
/// 3…2…1 → automatic submit. Any new recognized speech cancels the countdown;
/// Enter or the arrow submits immediately.
class AiSearchBar extends ConsumerStatefulWidget {
  const AiSearchBar({super.key});

  @override
  ConsumerState<AiSearchBar> createState() => _AiSearchBarState();
}

class _AiSearchBarState extends ConsumerState<AiSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _voice = LiveVoiceInput.instance;

  bool _voiceActive = false;
  double _voiceLevel = 0;
  int? _countdown;
  Timer? _countdownTimer;
  bool _submitting = false;

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
      if (mounted) setState(() => _voiceActive = false);
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
        if (mounted) setState(() => _voiceActive = listening);
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        final normalized = ((level + 45) / 45).clamp(0.0, 1.0);
        setState(() => _voiceLevel = normalized);
      },
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
    if (mounted) setState(() => _voiceActive = started);
  }

  Future<void> _runSearch() async {
    if (_submitting) return;
    _submitting = true;
    _cancelCountdown();
    await _voice.finish(owner: this);
    if (mounted) setState(() => _voiceActive = false);

    final q = _controller.text.trim();
    AppHaptics.selection();
    _focus.unfocus();

    try {
      if (q.isEmpty) {
        await showIntelCoreSheet(context);
        return;
      }

      if (_routeKeyword(q)) {
        _controller.clear();
        return;
      }

      await showIntelCoreSheet(context, initialQuery: q);
    } finally {
      _submitting = false;
    }
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

    if (has(
      r'\b(business|owner dashboard|owner side|landlord|host dashboard)\b',
    )) {
      context.go(AppPaths.ownerDashboard);
      return true;
    }

    if (has(
      r'\b(documents?|document vault|vault|paperwork|files?|pdfs?|passport files?|ids?)\b',
    )) {
      context.go(AppPaths.documents);
      return true;
    }

    if (has(
      r'\b(map|maps|near me|nearby|gps|passport|location|city|ciudad|zona|area)\b',
    )) {
      ref.read(overlayModalsProvider.notifier).openPassportMap();
      return true;
    }

    if (has(
      r'\b(events?|party|parties|nightlife|concert|festival|happening|tonight)\b',
    )) {
      context.go(AppPaths.exploreEvents);
      return true;
    }

    if (has(
      r'\b(legal|lawyer|lawyers|attorney|contract|contracts|fideicomiso|escrow|police help|legal help)\b',
    )) {
      context.go(AppPaths.clientLegalServices);
      return true;
    }

    if (has(
      r'\b(workers?|hire|services?|maintenance|plumber|cleaner|cleaning|maid|chef|cook|driver|chauffeur|nanny|electrician|handyman|gardener|mechanic|contractor|painter|carpenter|welder|technician)\b',
    )) {
      context.go(AppPaths.clientServices);
      return true;
    }

    if (has(
      r'\b(people|persons?|profiles?|users?|roommates?|seekers?|friends?|buyers?|renters?|gente|personas|amigos?)\b',
    )) {
      context.go(AppPaths.exploreSeekers);
      return true;
    }

    if (has(r'\b(yachts?|boats?|catamarans?|sailboats?|yates?|barcos?)\b')) {
      openClientSwipeDeck(
        context,
        categoryId: 'yacht',
        categoryTitle: 'YACHTS',
      );
      return true;
    }

    if (has(
      r'\b(motorcycles?|motorbikes?|motos?|scooters?|vespas?|motocicletas?)\b',
    )) {
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

    if (has(
      r'\b(properties?|property|listings?|homes?|houses?|apartments?|rooms?|studios?|villas?|condos?|rentals?|rent|buy|sale|renta|casas?|departamentos?)\b',
    )) {
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

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(isLightThemeProvider);
    final glow = isLight ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD);
    final frame = isLight ? const Color(0xFF2563EB) : const Color(0xFF60A5FA);
    final fill = AppTheme.wellFor(isLight: isLight);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final pulseScale = 1.0 + (_voiceLevel * .08);

    return SearchFrameShine(
      color: glow,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: frame, width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, color: glow.withAlpha(220), size: 20),
            const SizedBox(width: 10),
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
                      ? 'Listening…'
                      : 'Search properties, workers, people, events...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: _voiceActive ? glow : ink.withAlpha(140),
                    fontWeight:
                        _voiceActive ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 14,
                    letterSpacing: -0.1,
                  ),
                ),
                onChanged: (_) => _cancelCountdown(),
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            Tooltip(
              message: _voiceActive ? 'Stop listening' : 'Speak your search',
              child: GestureDetector(
                onTap: _toggleVoice,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 120),
                  scale: _voiceActive ? pulseScale : 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _voiceActive
                          ? glow.withAlpha(42)
                          : glow.withAlpha(16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _voiceActive
                            ? glow.withAlpha(210)
                            : glow.withAlpha(85),
                      ),
                      boxShadow: _voiceActive
                          ? [
                              BoxShadow(
                                color: glow.withAlpha(70),
                                blurRadius: 14 + (_voiceLevel * 12),
                                spreadRadius: _voiceLevel * 2,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      child: _countdown != null
                          ? Text(
                              '$_countdown',
                              key: ValueKey(_countdown),
                              style: GoogleFonts.plusJakartaSans(
                                color: glow,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : Icon(
                              _voiceActive
                                  ? Icons.graphic_eq_rounded
                                  : Icons.mic_none_rounded,
                              key: ValueKey(_voiceActive),
                              color: glow,
                              size: 19,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            IconButton(
              onPressed: _submitting ? null : _runSearch,
              tooltip: 'Search',
              icon: Icon(
                Icons.arrow_forward_rounded,
                color: glow.withAlpha(230),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
