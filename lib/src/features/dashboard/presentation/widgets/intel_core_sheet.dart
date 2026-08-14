import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/concierge_sheet_host.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';
import 'package:flutter_swipes/src/features/ai/domain/concierge_parse.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/ai_providers.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/ai_disclosure.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_message_bubble.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/intel_welcome_grid.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/memory_drawer.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap ConciergeChat overlay — bottom card covering the page.
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
    return ConciergeSheetHost(
      onClose: onClose,
      child: _IntelCoreSheet(
        initialQuery: initialQuery,
        onClose: onClose,
      ),
    );
  }
}

/// Opens Intel Core on the root overlay so header/dock can peek underneath.
Future<void> showIntelCoreSheet(
  BuildContext context, {
  String initialQuery = '',
}) async {
  ProviderScope.containerOf(context)
      .read(overlayModalsProvider.notifier)
      .openConcierge(initialQuery);
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
  final _messages = <IntelChatBubble>[];
  final _saved = <Map<String, dynamic>>[];
  bool _showHistory = false;
  bool _showPersona = false;
  bool _loading = false;
  bool _bootstrapped = false;
  bool _recording = false;
  bool _transcribing = false;
  bool _privacyAccepted = false;
  bool _autoSend = false;
  int? _countdown;
  Timer? _countdownTimer;
  String _character = 'default';
  String? _speakingId;
  final _tts = FlutterTts();

  static const _personas = <(String, String, String, Color)>[
    ('default', 'Swipess AI', 'Global Discovery', Color(0xFFFF3D00)),
    ('kyle', 'Kyle', 'Market Hustler', Color(0xFFFB923C)),
    ('beaugosse', 'Beau Gosse', 'Social Alpha', Color(0xFFA855F7)),
    ('donajkiin', "Don Aj K'iin", 'Mayan Wisdom', Color(0xFF10B981)),
    ('botbetter', 'Bot Better', 'Luxury Analyst', Color(0xFFEC4899)),
    ('lunashanti', 'Luna Shanti', 'Boho Spirit', Color(0xFFA78BFA)),
    ('ezriyah', 'Ezriyah', 'Integration Coach', Color(0xFF14B8A6)),
  ];

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
    _loadSaved();
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
    _countdownTimer?.cancel();
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

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('Swipess-ai-conversations');
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final list = <Map<String, dynamic>>[];
      for (final row in decoded) {
        if (row is Map) list.add(Map<String, dynamic>.from(row));
      }
      if (mounted) {
        setState(() {
          _saved
            ..clear()
            ..addAll(list);
        });
      }
    } catch (_) {}
  }

  Future<void> _acceptPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('Swipess_ai_privacy', 'true');
    setState(() => _privacyAccepted = true);
  }

  Future<void> _speak(IntelChatBubble message) async {
    try {
      if (_speakingId == message.id) {
        await _tts.stop();
        if (mounted) setState(() => _speakingId = null);
        return;
      }
      await _tts.setLanguage(
        ref.read(appLocaleProvider).isEs ? 'es-MX' : 'en-US',
      );
      await _tts.setSpeechRate(0.48);
      setState(() => _speakingId = message.id);
      await _tts.speak(message.content.replaceAll(RegExp(r'\[[^\]]+\]'), ''));
    } catch (_) {}
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = [..._saved];
      list.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _messages.firstOrNull?.content ?? 'Chat',
        'messages': [
          for (final m in _messages.take(50))
            {'role': m.role, 'content': m.content, 'provider': m.provider},
        ],
      });
      final trimmed = list.take(20).toList();
      await prefs.setString(
        'Swipess-ai-conversations',
        jsonEncode(trimmed),
      );
      if (mounted) {
        setState(() {
          _saved
            ..clear()
            ..addAll(trimmed);
        });
      }
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t(ref, 'flutter.voiceFailed', 'Voice transcription failed'),
              ),
            ),
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
          SnackBar(
            content: Text(
              t(ref, 'flutter.micDenied', 'Microphone permission denied'),
            ),
          ),
        );
      }
      return;
    }
    setState(() => _recording = true);
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _submit([String? preset]) async {
    _cancelCountdown();
    final q = (preset ?? _controller.text).trim();
    if (q.isEmpty || _loading) return;
    AppHaptics.selection();
    _controller.clear();

    setState(() {
      _messages.add(IntelChatBubble(id: _newId(), role: 'user', content: q));
      _loading = true;
    });
    _scrollToEnd();

    final loc = ref.read(discoveryLocationProvider);
    final history = [
      for (final m in _messages)
        AiChatMessage(role: m.role, content: m.content),
    ];
    String reply = '';
    final assistantId = _newId();
    try {
      setState(() {
        _messages.add(
          IntelChatBubble(id: assistantId, role: 'assistant', content: ''),
        );
      });
      await for (final delta
          in ref.read(aiEdgeRepositoryProvider).chatConciergeTokens(
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
              _messages.last.copyWith(content: reply);
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
                _messages.last.copyWith(content: reply);
          });
        }
      }
    } on AiUnavailableException catch (e) {
      reply = e.message;
      if (mounted) {
        setState(() {
          _messages[_messages.length - 1] =
              _messages.last.copyWith(content: reply);
        });
      }
    } catch (_) {
      reply = 'AI is temporarily unavailable. Try again in a moment.';
      if (mounted) {
        setState(() {
          _messages[_messages.length - 1] =
              _messages.last.copyWith(content: reply);
        });
      }
    }
    if (!mounted) return;
    final parsed = ConciergeParse.of(reply);
    if (parsed.passportCity != null && parsed.passportCity!.trim().isNotEmpty) {
      ref
          .read(discoveryLocationProvider.notifier)
          .setCity(parsed.passportCity!.trim());
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
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Keep the chat open and reveal header / dock so the user can navigate.
  void _peekChrome() {
    ref.read(chromeVisibilityProvider.notifier).show();
  }

  /// Cap-style curated routing — follow-up chips after Intel Core replies.
  void _openIntent(String q) {
    _peekChrome();
    if (RegExp(r'\b(map|near me|nearby|gps|passport|location|ciudad|city|zona|area)\b')
        .hasMatch(q)) {
      ref.read(overlayModalsProvider.notifier).openPassportMap();
      return;
    }

    if (RegExp(
          r'\b(people|person|user|users|profile|profiles|roommate|roommates|seeker|seekers|who.?s looking|looking for)\b',
        ).hasMatch(q)) {
      context.go(AppPaths.exploreSeekers);
      return;
    }

    if (RegExp(r'\b(worker|workers|hire|service|services|maintenance|plumber|cleaner)\b')
        .hasMatch(q)) {
      context.push(AppPaths.clientServices);
      return;
    }

    if (RegExp(r'\b(event|events|party|nightlife|concert)\b').hasMatch(q)) {
      context.go(AppPaths.exploreEvents);
      return;
    }

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
      openClientSwipeDeck(
        context,
        categoryId: category,
        categoryTitle: title,
      );
      return;
    }

    if (q.contains('filter') || q.contains('filters')) {
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
              _peekChrome();
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
    _peekChrome();
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
      _showPersona = false;
    });
  }

  void _restoreSaved(Map<String, dynamic> row) {
    final raw = row['messages'];
    final restored = <IntelChatBubble>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        restored.add(
          IntelChatBubble(
            id: _newId(),
            role: item['role']?.toString() ?? 'assistant',
            content: item['content']?.toString() ?? '',
            provider: item['provider']?.toString() ?? 'groq',
          ),
        );
      }
    }
    setState(() {
      _messages
        ..clear()
        ..addAll(restored);
      _showHistory = false;
    });
  }

  void _copy(IntelChatBubble m) {
    final parsed = m.isUser ? null : ConciergeParse.of(m.content);
    final text = parsed?.cleanContent.isNotEmpty == true
        ? parsed!.cleanContent
        : m.content;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Telemetry Copied')),
    );
  }

  void _delete(IntelChatBubble m) {
    setState(() {
      _messages.removeWhere((row) => row.id == m.id);
    });
  }

  void _edit(IntelChatBubble m) {
    _controller.text = m.content;
    _controller.selection = TextSelection.collapsed(offset: m.content.length);
  }

  void _resend(IntelChatBubble m) {
    if (m.isUser) {
      _submit(m.content);
      return;
    }
    final idx = _messages.indexWhere((row) => row.id == m.id);
    String? prompt;
    if (idx > 0) {
      for (var i = idx - 1; i >= 0; i--) {
        if (_messages[i].isUser) {
          prompt = _messages[i].content;
          break;
        }
      }
    }
    if (prompt == null) return;
    setState(() {
      _messages.removeWhere((row) => row.id == m.id);
    });
    _submit(prompt);
  }

  void _translate(IntelChatBubble m) {
    final parsed = ConciergeParse.of(m.content);
    final text = parsed.cleanContent.isNotEmpty ? parsed.cleanContent : m.content;
    _submit('Translate the following to Spanish:\n\n$text');
  }

  void _onComposerChanged(String value) {
    if (!_autoSend) return;
    if (value.trim().isEmpty) {
      _cancelCountdown();
      return;
    }
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = (_countdown ?? 1) - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() => _countdown = null);
        _submit();
      } else {
        setState(() => _countdown = next);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  (String, String, String, Color) get _activePersona {
    for (final p in _personas) {
      if (p.$1 == _character) return p;
    }
    return _personas.first;
  }

  @override
  Widget build(BuildContext context) {
    final edgeReady = ref.watch(aiEdgeReadyProvider);
    final isLight = ref.watch(isLightThemeProvider);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final canvas = isLight ? Colors.white : const Color(0xFF0A0A0C);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: canvas,
        child: Stack(
          children: [
            if (!_privacyAccepted)
              Positioned.fill(
                child: _privacyPortal(isLight: isLight, ink: ink),
              )
            else
              Positioned.fill(
                child: Column(
                  children: [
                    _header(isLight: isLight, ink: ink, online: edgeReady),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                      children: [
                        if (_messages.isEmpty)
                          IntelWelcomeGrid(
                            isLight: isLight,
                            onPick: (prompt) => _submit(prompt),
                          )
                        else ...[
                          for (final m in _messages)
                            IntelMessageBubble(
                              message: m,
                              isLight: isLight,
                              speaking: _speakingId == m.id,
                              onCopy: () => _copy(m),
                              onDelete: () => _delete(m),
                              onSpeak: () => _speak(m),
                              onEdit: m.isUser ? () => _edit(m) : null,
                              onResend: () => _resend(m),
                              onTranslate:
                                  m.isUser ? null : () => _translate(m),
                            ),
                          if (_loading &&
                              (_messages.isEmpty ||
                                  _messages.last.content.trim().isEmpty))
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text(
                                t(ref, 'flutter.thinking', 'Thinking…'),
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink.withAlpha(110),
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else if (_followUps().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final chip in _followUps())
                                  ActionChip(
                                    label: Text(
                                      chip.label,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: ink,
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
                  _composer(isLight: isLight, ink: ink),
                ],
              ),
            ),
            if (_showHistory) _historyDrawer(isLight: isLight, ink: ink, online: edgeReady),
            if (_showPersona) _personaSheet(isLight: isLight, ink: ink),
          ],
        ),
      ),
    );
  }

  Widget _header({
    required bool isLight,
    required Color ink,
    required bool online,
  }) {
    final persona = _activePersona;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ink.withAlpha(isLight ? 24 : 30)),
        ),
      ),
      child: Row(
        children: [
          _ChromeIcon(
            icon: Icons.menu_rounded,
            ink: ink,
            onTap: () => setState(() {
              _showPersona = false;
              _showHistory = !_showHistory;
            }),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INTEL CORE',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFFF3D00),
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                  letterSpacing: 2.4,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                online ? 'ONLINE' : 'OFFLINE',
                style: GoogleFonts.plusJakartaSans(
                  color: ink.withAlpha(90),
                  fontWeight: FontWeight.w800,
                  fontSize: 8,
                  letterSpacing: 1.6,
                  height: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _showHistory = false;
              _showPersona = !_showPersona;
            }),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      persona.$2.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.8,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      persona.$3.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(90),
                        fontWeight: FontWeight.w800,
                        fontSize: 7,
                        letterSpacing: 0.6,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: persona.$4.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: persona.$4, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _ChromeIcon(
            icon: Icons.close_rounded,
            ink: ink,
            onTap: _dismiss,
          ),
        ],
      ),
    );
  }

  Widget _composer({required bool isLight, required Color ink}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Column(
        children: [
          if (_countdown != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 14, color: AppTheme.brandPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'SEND IN',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.brandPrimary,
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _cancelCountdown,
                    icon: Icon(Icons.close_rounded, size: 16, color: ink),
                  ),
                ],
              ),
            ),
          AiDisclosure(isLight: isLight, showModelLine: true),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF4F4F7)
                        : const Color(0xFF14141A),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ink.withAlpha(isLight ? 40 : 200), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => _autoSend = !_autoSend);
                          if (!_autoSend) _cancelCountdown();
                        },
                        child: Icon(Icons.timer_outlined,
                            color: _autoSend
                                ? AppTheme.brandPrimary
                                : ink.withAlpha(120),
                            size: 20),
                      ),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap:
                            (_loading || _transcribing) ? null : _toggleVoice,
                        child: Icon(
                          _recording
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _recording
                              ? AppTheme.brandPrimary
                              : ink.withAlpha(120),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_loading,
                          style: TextStyle(color: ink, fontSize: 15),
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _recording
                                ? t(ref, 'flutter.listening', 'Listening…')
                                : _transcribing
                                    ? t(ref, 'flutter.transcribing',
                                        'Transcribing…')
                                    : t(ref, 'flutter.askAnything',
                                        'Ask anything...'),
                            hintStyle: TextStyle(color: ink.withAlpha(100)),
                          ),
                          onChanged: (value) {
                            setState(() {});
                            _onComposerChanged(value);
                          },
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _controller.text.trim().isEmpty || _loading
                        ? (isLight
                            ? const Color(0xFFE8E8EE)
                            : Colors.white.withAlpha(18))
                        : AppTheme.brandPrimary,
                  ),
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ink.withAlpha(160),
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward_rounded,
                          color: _controller.text.trim().isEmpty
                              ? ink.withAlpha(90)
                              : Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _privacyPortal({required bool isLight, required Color ink}) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.brandPrimary.withAlpha(24),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.brandPrimary.withAlpha(50)),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppTheme.brandPrimary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Swipess Intel',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start a private conversation with your AI concierge. Your messages are confidential and powered by well-known AI models.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: ink.withAlpha(140),
              height: 1.45,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          AiDisclosure(isLight: isLight, variant: AiDisclosureVariant.roomy),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _acceptPrivacy,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Start Session',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_return_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyDrawer({
    required bool isLight,
    required Color ink,
    required bool online,
  }) {
    final canvas = isLight ? Colors.white : const Color(0xF214141A);
    return Positioned.fill(
      child: Row(
        children: [
          Container(
            width: MediaQuery.sizeOf(context).width * 0.78,
            color: canvas,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Text(
                        'HISTORY',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        online ? 'CORE ONLINE' : 'OFFLINE',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() => _showHistory = false),
                        icon: Icon(Icons.close, color: ink.withAlpha(180)),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.psychology_rounded, color: ink),
                    title: Text(
                      'AI Memory',
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      setState(() => _showHistory = false);
                      showMemoryDrawer(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_saved.isEmpty)
                    Text(
                      'No saved chats yet.',
                      style: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(120),
                      ),
                    ),
                  for (final item in _saved)
                    GestureDetector(
                      onTap: () => _restoreSaved(item),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ink.withAlpha(40)),
                        ),
                        child: Text(
                          item['title']?.toString() ?? 'Chat',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: ink),
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
    );
  }

  Widget _personaSheet({required bool isLight, required Color ink}) {
    return Positioned(
      top: 60,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF14141A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ink.withAlpha(30)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Text(
                  'PERSONA',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink.withAlpha(110),
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              for (final p in _personas)
                ListTile(
                  dense: true,
                  onTap: () => setState(() {
                    _character = p.$1;
                    _showPersona = false;
                  }),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: p.$4.withAlpha(40),
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 14, color: p.$4),
                  ),
                  title: Text(
                    p.$2.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: p.$1 == _character
                          ? AppTheme.brandPrimary
                          : ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  subtitle: Text(
                    p.$3.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: ink.withAlpha(120),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: p.$1 == _character
                      ? const Icon(Icons.circle,
                          size: 8, color: AppTheme.brandPrimary)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChromeIcon extends StatelessWidget {
  const _ChromeIcon({
    required this.icon,
    required this.onTap,
    required this.ink,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: ink, size: 18),
      ),
    );
  }
}
