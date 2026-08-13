import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/genie_panel.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/ai_providers.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_result_cards.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/memory_drawer.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap ConciergeChat overlay — genie panel from the dock.
class ConciergeOverlay extends StatelessWidget {
  const ConciergeOverlay({
    super.key,
    this.initialQuery = '',
    required this.onClose,
  });

  final String initialQuery;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GeniePanel(
      onDismissed: onClose,
      builder: (context, dismiss) {
        return _IntelCoreSheet(
          initialQuery: initialQuery,
          onClose: dismiss,
        );
      },
    );
  }
}

/// Capacitor Intel Core — chats via Supabase `ai-concierge` edge function.
Future<void> showIntelCoreSheet(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withAlpha(50),
    useRootNavigator: true,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _IntelCoreSheet(initialQuery: initialQuery),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

class _ChatBubble {
  const _ChatBubble({required this.role, required this.content});
  final String role;
  final String content;
}

class _IntelCoreSheet extends ConsumerStatefulWidget {
  const _IntelCoreSheet({this.initialQuery = '', this.onClose});

  final String initialQuery;
  final VoidCallback? onClose;

  @override
  ConsumerState<_IntelCoreSheet> createState() => _IntelCoreSheetState();
}

class _IntelCoreSheetState extends ConsumerState<_IntelCoreSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatBubble>[];
  bool _showHistory = false;
  bool _loading = false;
  bool _bootstrapped = false;
  bool _recording = false;
  bool _transcribing = false;
  bool _privacyAccepted = false;
  String _character = 'default';
  final _tts = FlutterTts();

  static const _personas = <(String, String)>[
    ('default', 'Swipess AI'),
    ('kyle', 'Kyle'),
    ('beaugosse', 'Beau Gosse'),
    ('donajkiin', "Don Aj K'iin"),
    ('botbetter', 'Bot Better'),
    ('lunashanti', 'Luna Shanti'),
    ('ezriyah', 'Ezriyah'),
  ];

  static const _starters = [
    'Find people looking to buy houses',
    'Find maintenance workers',
    'Show me all rental properties',
    'Show me available houses',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
    final seed = widget.initialQuery.trim();
    if (seed.isNotEmpty) _privacyAccepted = true;
    if (seed.isNotEmpty) {
      _controller.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _bootstrapped) return;
        _bootstrapped = true;
        _submit(seed);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = prefs.getString('Swipess_ai_privacy') == 'true' ||
        widget.initialQuery.trim().isNotEmpty;
    if (mounted) setState(() => _privacyAccepted = ok);
  }

  Future<void> _acceptPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('Swipess_ai_privacy', 'true');
    setState(() => _privacyAccepted = true);
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage(
        ref.read(appLocaleProvider).isEs ? 'es-MX' : 'en-US',
      );
      await _tts.setSpeechRate(0.48);
      await _tts.speak(text.replaceAll(RegExp(r'\[[^\]]+\]'), ''));
    } catch (_) {}
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('Swipess-ai-conversations');
      final list = <Map<String, dynamic>>[];
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final row in decoded) {
            if (row is Map) {
              list.add(Map<String, dynamic>.from(row));
            }
          }
        }
      }
      list.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _messages.firstOrNull?.content ?? 'Chat',
        'messages': [
          for (final m in _messages.take(50))
            {'role': m.role, 'content': m.content},
        ],
      });
      await prefs.setString(
        'Swipess-ai-conversations',
        jsonEncode(list.take(20).toList()),
      );
    } catch (_) {}
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleVoice() async {
    final repo = ref.read(voiceTranscribeRepositoryProvider);
    if (_recording) {
      setState(() {
        _recording = false;
        _transcribing = true;
      });
      try {
        final lang = ref.read(appLocaleProvider).isEs ? 'es-MX' : 'en-US';
        final text = await repo.stop(language: lang);
        if (text.trim().isNotEmpty && mounted) {
          await _submit(text.trim());
        }
      } on VoiceTranscribeException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(ref, 'flutter.voiceFailed', 'Voice transcription failed'))),
          );
        }
      } finally {
        if (mounted) setState(() => _transcribing = false);
      }
      return;
    }
    final ok = await repo.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(ref, 'flutter.micDenied', 'Microphone permission denied'))),
        );
      }
      return;
    }
    setState(() => _recording = true);
  }

  Future<void> _submit([String? preset]) async {
    final q = (preset ?? _controller.text).trim();
    if (q.isEmpty || _loading) return;
    HapticFeedback.selectionClick();
    _controller.clear();

    setState(() {
      _messages.add(_ChatBubble(role: 'user', content: q));
      _loading = true;
    });
    _scrollToEnd();

    final loc = ref.read(discoveryLocationProvider);
    final history = [
      for (final m in _messages)
        AiChatMessage(role: m.role, content: m.content),
    ];
    String reply = '';
    try {
      setState(() {
        _messages.add(const _ChatBubble(role: 'assistant', content: ''));
      });
      await for (final delta in ref.read(aiEdgeRepositoryProvider).chatConciergeTokens(
            messages: history,
            character: _character == 'default' ? null : _character,
            locationContext: {
              'passportMode': false,
              'passportLabel': loc.label,
              'userLatitude': loc.latitude,
              'userLongitude': loc.longitude,
              'radiusKm': loc.radiusKm,
            },
          )) {
        if (!mounted) return;
        reply += delta;
        setState(() {
          _messages[_messages.length - 1] =
              _ChatBubble(role: 'assistant', content: reply);
        });
        _scrollToEnd();
      }
      if (reply.trim().isEmpty) {
        reply = await ref.read(aiEdgeRepositoryProvider).chatConcierge(
              messages: history,
              character: _character == 'default' ? null : _character,
              locationContext: {
                'passportMode': false,
                'passportLabel': loc.label,
                'userLatitude': loc.latitude,
                'userLongitude': loc.longitude,
                'radiusKm': loc.radiusKm,
              },
              stream: false,
            );
        if (mounted) {
          setState(() {
            _messages[_messages.length - 1] =
                _ChatBubble(role: 'assistant', content: reply);
          });
        }
      }
    } on AiUnavailableException catch (e) {
      reply = e.message;
      if (mounted) {
        setState(() {
          _messages[_messages.length - 1] =
              _ChatBubble(role: 'assistant', content: reply);
        });
      }
    } catch (_) {
      reply = 'AI is temporarily unavailable. Try again in a moment.';
      if (mounted) {
        setState(() {
          _messages[_messages.length - 1] =
              _ChatBubble(role: 'assistant', content: reply);
        });
      }
    }
    if (!mounted) return;
    final parsed = ConciergeParse.of(reply);
    if (parsed.passportCity != null && parsed.passportCity!.trim().isNotEmpty) {
      ref.read(discoveryLocationProvider.notifier).setCity(parsed.passportCity!.trim());
    }
    if (parsed.filterAction != null) {
      _applyConciergeFilter(parsed.filterAction!);
    }
    setState(() {
      _loading = false;
    });
    _scrollToEnd();
    _persistHistory();
  }

  void _dismiss() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.of(context).canPop()) {
      _dismiss();
    }
  }

  /// Cap-style curated routing — follow-up chips after Intel Core replies.
  void _openIntent(String q) {
    // Map / location / city
    if (RegExp(r'\b(map|near me|nearby|gps|passport|location|ciudad|city|zona|area)\b')
        .hasMatch(q)) {
      _dismiss();
      ref.read(overlayModalsProvider.notifier).openPassportMap();
      return;
    }

    // People / seekers / profiles / users
    if (RegExp(
          r'\b(people|person|user|users|profile|profiles|roommate|roommates|seeker|seekers|who.?s looking|looking for)\b',
        ).hasMatch(q)) {
      _dismiss();
      context.go(AppPaths.exploreSeekers);
      return;
    }

    // Workers / services / maintenance
    if (RegExp(r'\b(worker|workers|hire|service|services|maintenance|plumber|cleaner)\b')
        .hasMatch(q)) {
      _dismiss();
      context.push(AppPaths.clientServices);
      return;
    }

    // Events
    if (RegExp(r'\b(event|events|party|nightlife|concert)\b').hasMatch(q)) {
      _dismiss();
      context.go(AppPaths.exploreEvents);
      return;
    }

    // Listings / homes / rent / buy
    if (RegExp(
          r'\b(listing|listings|property|properties|home|homes|house|houses|apartment|rent|rental|buy|sale|yacht|moto|motorcycle|bike|bicycle)\b',
        ).hasMatch(q)) {
      String category = 'property';
      String title = 'PROPERTIES';
      if (q.contains('yacht')) {
        category = 'yacht';
        title = 'YACHTS';
      } else if (q.contains('moto') || q.contains('motorcycle')) {
        category = 'motorcycle';
        title = 'MOTORCYCLES';
      } else if (q.contains('bike') || q.contains('bicycle')) {
        category = 'bicycle';
        title = 'BICYCLES';
      } else if (q.contains('worker') || q.contains('service')) {
        category = 'worker';
        title = 'WORKERS';
      }
      _dismiss();
      openClientSwipeDeck(
        context,
        categoryId: category,
        categoryTitle: title,
      );
      return;
    }

    if (q.contains('filter') || q.contains('filters')) {
      _dismiss();
      context.go(AppPaths.clientFilters);
    }
  }

  List<({String label, VoidCallback onTap})> _followUps() {
    final lastAssistant = _messages.reversed
        .where((m) => m.role == 'assistant')
        .map((m) => m.content)
        .firstOrNull;
    if (lastAssistant != null) {
      final parsed = ConciergeParse.of(lastAssistant);
      final chips = <({String label, VoidCallback onTap})>[
        for (final path in parsed.navPaths)
          if (path != '/radio')
            (
              label: ConciergeParse.navLabels[path] ?? 'Open',
              onTap: () => _openPath(path),
            ),
        if (parsed.filterAction != null)
          (
            label: 'Applying Search Filters',
            onTap: () => _applyConciergeFilter(parsed.filterAction!),
          ),
        if (parsed.passportCity != null && parsed.passportCity!.trim().isNotEmpty)
          (
            label: 'Explore ${parsed.passportCity}',
            onTap: () {
              ref
                  .read(discoveryLocationProvider.notifier)
                  .setCity(parsed.passportCity!.trim());
              _dismiss();
              ref.read(overlayModalsProvider.notifier).openPassportMap();
            },
          ),
      ];
      if (chips.isNotEmpty) return chips;
    }
    final lastUser = _messages.reversed
        .where((m) => m.role == 'user')
        .map((m) => m.content.toLowerCase())
        .firstOrNull;
    if (lastUser == null) return const [];
    final out = <({String label, VoidCallback onTap})>[];
    if (RegExp(r'\b(people|person|seeker|roommate|who.?s looking)\b')
        .hasMatch(lastUser)) {
      out.add((label: 'Open Seekers', onTap: () => _openIntent(lastUser)));
    }
    if (RegExp(r'\b(worker|hire|maintenance|plumber|cleaner)\b')
        .hasMatch(lastUser)) {
      out.add((label: 'Open Workers', onTap: () => _openIntent(lastUser)));
    }
    if (RegExp(r'\b(event|party|nightlife|concert)\b').hasMatch(lastUser)) {
      out.add((label: 'Open Events', onTap: () => _openIntent(lastUser)));
    }
    if (RegExp(r'\b(map|near me|nearby|gps|location|city)\b').hasMatch(lastUser)) {
      out.add((label: 'Open Map', onTap: () => _openIntent(lastUser)));
    }
    if (RegExp(
          r'\b(listing|property|home|house|apartment|rent|rental|buy|yacht|moto|bike)\b',
        ).hasMatch(lastUser)) {
      out.add((label: 'Open Listings', onTap: () => _openIntent(lastUser)));
    }
    return out;
  }

  void _openPath(String path) {
    _dismiss();
    if (path.contains('liked')) {
      context.go(AppPaths.clientLikedProperties);
      return;
    }
    if (path.contains('filter')) {
      context.go(AppPaths.clientFilters);
      return;
    }
    if (path.contains('events')) {
      context.go(AppPaths.exploreEvents);
      return;
    }
    if (path.contains('seeker')) {
      context.go(AppPaths.exploreSeekers);
      return;
    }
    if (path.contains('map')) {
      ref.read(overlayModalsProvider.notifier).openPassportMap();
      return;
    }
    if (path.contains('subscription')) {
      context.go(AppPaths.subscriptionPackages);
      return;
    }
    if (path.contains('legal')) {
      context.go(AppPaths.legal);
      return;
    }
    if (path.contains('profile')) {
      context.go(AppPaths.clientProfile);
      return;
    }
    if (path.contains('settings')) {
      context.go(AppPaths.clientSettings);
      return;
    }
    if (path.contains('listings') || path.contains('properties')) {
      context.go(AppPaths.ownerProperties);
      return;
    }
    context.go(AppPaths.clientDashboard);
  }

  /// Cap `applyConciergeFilters` — [FILTER:] tags update the swipe deck.
  void _applyConciergeFilter(Map<String, dynamic> filters) {
    final n = ref.read(swipeFilterProvider.notifier);
    final cat = filters['activeCategory']?.toString();
    if (cat != null && cat.isNotEmpty) n.setCategory(cat);
    final type = filters['listingType']?.toString();
    if (type != null && type.isNotEmpty) n.setInterestType(type);
    final range = filters['priceRange'];
    if (range is List && range.length >= 2) {
      n.setPriceRange(
        (range[0] as num?)?.toDouble(),
        (range[1] as num?)?.toDouble(),
      );
    }
    final radius = filters['radiusKm'];
    if (radius is num) {
      n.setRadiusKm(radius.toDouble());
      ref.read(discoveryLocationProvider.notifier).setRadiusKm(radius.toInt());
    }
    final city = (filters['passportCity'] ?? filters['city'])?.toString();
    if (city != null && city.trim().isNotEmpty) {
      n.setCity(city.trim());
      ref.read(discoveryLocationProvider.notifier).setCity(city.trim());
    }
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _showHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final edgeReady = ref.watch(aiEdgeReadyProvider);
    final topPadding = MediaQuery.paddingOf(context).top;
    
    return Container(
      height: MediaQuery.sizeOf(context).height,
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: const Color(0xF20A0A0C).withAlpha(180),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    _RoundIcon(
                      icon: Icons.menu_rounded,
                      onTap: () => setState(() => _showHistory = !_showHistory),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Choose persona',
                      initialValue: _character,
                      color: const Color(0xFF14141A),
                      onSelected: (value) =>
                          setState(() => _character = value),
                      itemBuilder: (context) => [
                        for (final persona in _personas)
                          PopupMenuItem(
                            value: persona.$1,
                            child: Text(
                              persona.$2,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: persona.$1 == _character
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                      child: Column(
                        children: [
                          Text(
                            'INTEL CORE',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.brandPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '$_personaLabel · ${edgeReady ? 'ONLINE' : 'OFFLINE'}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _RoundIcon(
                      icon: Icons.record_voice_over_rounded,
                      color: const Color(0xFFA78BFA),
                      onTap: () {
                        final last = _messages.reversed
                            .where((m) => m.role == 'assistant')
                            .map((m) => m.content)
                            .firstOrNull;
                        if (last != null) _speak(last);
                      },
                    ),
                    const SizedBox(width: 8),
                    _RoundIcon(
                      icon: Icons.psychology_rounded,
                      color: const Color(0xFF22D3EE),
                      onTap: () {
                        showMemoryDrawer(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    _RoundIcon(
                      icon: Icons.auto_awesome_rounded,
                      color: AppTheme.brandPrimary,
                      onTap: _newChat,
                    ),
                    const SizedBox(width: 8),
                    _RoundIcon(
                      icon: Icons.close_rounded,
                      onTap: _dismiss,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !_privacyAccepted
                    ? _privacyPortal()
                    : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (_messages.isEmpty) ...[
                      Text(
                        capCopy(
                          ref,
                          'Type what you need — people, listings, a city on the map, workers, events. Or ask Intel Core anything.',
                          'Escribe lo que necesitas — personas, listings, una ciudad en el mapa, workers, eventos. O pregunta a Intel Core.',
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in _starters)
                            ActionChip(
                              label: Text(
                                item,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: _loading ? null : () => _submit(item),
                            ),
                        ],
                      ),
                    ] else ...[
                      for (final m in _messages) _Bubble(message: m),
                      if (_loading &&
                          (_messages.isEmpty ||
                              _messages.last.content.trim().isEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            t(ref, 'flutter.thinking', 'Thinking…'),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else if (_followUps().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final chip in _followUps())
                              ActionChip(
                                label: Text(
                                  chip.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: chip.onTap,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                child: Column(
                  children: [
                    Text(
                      '✨ ${t(ref, 'flutter.aiDisclaimer', 'AI-powered · Answers are generated by AI. AI can make mistakes. Consider verifying important information.')}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14141A),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    color: Colors.white.withAlpha(120), size: 20),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: (_loading || _transcribing) ? null : _toggleVoice,
                                  child: Icon(
                                    _recording
                                        ? Icons.mic_rounded
                                        : Icons.mic_none_rounded,
                                    color: _recording
                                        ? AppTheme.brandPrimary
                                        : Colors.white.withAlpha(120),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    enabled: !_loading,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: _recording
                                          ? t(ref, 'flutter.listening', 'Listening…')
                                          : _transcribing
                                              ? t(ref, 'flutter.transcribing', 'Transcribing…')
                                              : t(ref, 'flutter.askAnything', 'Ask anything...'),
                                      hintStyle: TextStyle(
                                        color: Colors.white.withAlpha(100),
                                      ),
                                    ),
                                    onSubmitted: (_) => _submit(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _loading ? null : () => _submit(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: _loading
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showHistory)
            Positioned.fill(
              child: Row(
                children: [
                  Container(
                    width: MediaQuery.sizeOf(context).width * 0.78,
                    color: const Color(0xF214141A),
                    child: SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Text(
                                'HISTORY',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                edgeReady ? 'CORE ONLINE' : 'OFFLINE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.brandPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _showHistory = false),
                                icon: const Icon(Icons.close, color: Colors.white70),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _newChat,
                            child: Text(
                              '+ NEW CHAT',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.brandPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          for (final item in _starters)
                            GestureDetector(
                              onTap: () {
                                setState(() => _showHistory = false);
                                _submit(item);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  item,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showHistory = false),
                      child: Container(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String get _personaLabel {
    for (final persona in _personas) {
      if (persona.$1 == _character) return persona.$2.toUpperCase();
    }
    return 'SWIPESS AI';
  }

  Widget _privacyPortal() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            'INTEL CORE PRIVACY',
            style: AppTheme.displayItalic.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 12),
          Text(
            'Chats run through Swipess AI edge functions. Do not share passwords or payment numbers. You can delete history anytime.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _acceptPrivacy,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'I UNDERSTAND — CONTINUE',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _ChatBubble message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final parsed = isUser ? null : ConciergeParse.of(message.content);
    final text = parsed?.cleanContent.isNotEmpty == true
        ? parsed!.cleanContent
        : message.content;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.brandPrimary.withAlpha(40)
                    : Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
            if (!isUser) ...[
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 10, color: AppTheme.brandPrimary.withAlpha(180)),
                    const SizedBox(width: 4),
                    Text(
                      'POWERED BY GROQ · LLAMA 3.3',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (parsed != null) ...[
                for (final listing in parsed.listings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IntelListingCard(data: listing),
                  ),
                for (final profile in parsed.profiles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IntelProfileCard(data: profile),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 18),
      ),
    );
  }
}
