import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/ai_providers.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/memory_drawer.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor Intel Core — chats via Supabase `ai-concierge` edge function.
/// Pass [initialQuery] when the dashboard AI bar already has text (Cap openAIChat(q)).
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
  const _IntelCoreSheet({this.initialQuery = ''});

  final String initialQuery;

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

  static const _starters = [
    'Find people looking to buy houses',
    'Find maintenance workers',
    'Show me all rental properties',
    'Show me available houses',
  ];

  @override
  void initState() {
    super.initState();
    final seed = widget.initialQuery.trim();
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
    super.dispose();
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
    String reply;
    try {
      reply = await ref.read(aiEdgeRepositoryProvider).chatConcierge(
            messages: history,
            locationContext: {
              'passportMode': false,
              'passportLabel': loc.label,
              'userLatitude': loc.latitude,
              'userLongitude': loc.longitude,
              'radiusKm': loc.radiusKm,
            },
          );
    } on AiUnavailableException catch (e) {
      reply = e.message;
    } catch (_) {
      reply = 'AI is temporarily unavailable. Try again in a moment.';
    }
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatBubble(role: 'assistant', content: reply));
      _loading = false;
    });
    _scrollToEnd();
  }

  /// Cap-style curated routing — follow-up chips after Intel Core replies.
  void _openIntent(String q) {
    // Map / location / city
    if (RegExp(r'\b(map|near me|nearby|gps|passport|location|ciudad|city|zona|area)\b')
        .hasMatch(q)) {
      Navigator.pop(context);
      context.push(AppPaths.map);
      return;
    }

    // People / seekers / profiles / users
    if (RegExp(
          r'\b(people|person|user|users|profile|profiles|roommate|roommates|seeker|seekers|who.?s looking|looking for)\b',
        ).hasMatch(q)) {
      Navigator.pop(context);
      context.go(AppPaths.exploreSeekers);
      return;
    }

    // Workers / services / maintenance
    if (RegExp(r'\b(worker|workers|hire|service|services|maintenance|plumber|cleaner)\b')
        .hasMatch(q)) {
      Navigator.pop(context);
      context.push(AppPaths.clientServices);
      return;
    }

    // Events
    if (RegExp(r'\b(event|events|party|nightlife|concert)\b').hasMatch(q)) {
      Navigator.pop(context);
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
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientSwipeContainer(
            categoryId: category,
            categoryTitle: title,
          ),
        ),
      );
      return;
    }

    if (q.contains('filter') || q.contains('filters')) {
      Navigator.pop(context);
      context.go(AppPaths.clientFilters);
    }
  }

  List<({String label, String query})> _followUps() {
    final lastUser = _messages.reversed
        .where((m) => m.role == 'user')
        .map((m) => m.content.toLowerCase())
        .firstOrNull;
    if (lastUser == null) return const [];
    final out = <({String label, String query})>[];
    if (RegExp(r'\b(people|person|seeker|roommate|who.?s looking)\b')
        .hasMatch(lastUser)) {
      out.add((label: 'Open Seekers', query: lastUser));
    }
    if (RegExp(r'\b(worker|hire|maintenance|plumber|cleaner)\b')
        .hasMatch(lastUser)) {
      out.add((label: 'Open Workers', query: lastUser));
    }
    if (RegExp(r'\b(event|party|nightlife|concert)\b').hasMatch(lastUser)) {
      out.add((label: 'Open Events', query: lastUser));
    }
    if (RegExp(r'\b(map|near me|nearby|gps|location|city)\b').hasMatch(lastUser)) {
      out.add((label: 'Open Map', query: lastUser));
    }
    if (RegExp(
          r'\b(listing|property|home|house|apartment|rent|rental|buy|yacht|moto|bike)\b',
        ).hasMatch(lastUser)) {
      out.add((label: 'Open Listings', query: lastUser));
    }
    return out;
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
                    Column(
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
                          edgeReady ? 'ONLINE · EDGE AI' : 'OFFLINE',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _RoundIcon(
                      icon: Icons.psychology_rounded,
                      color: const Color(0xFF22D3EE),
                      onTap: () {
                        Navigator.pop(context);
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
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (_messages.isEmpty) ...[
                      Text(
                        'Type what you need — people, listings, a city on the map, workers, events. Or ask Intel Core anything.',
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
                              backgroundColor: Colors.white.withAlpha(14),
                              side: BorderSide(color: Colors.white.withAlpha(30)),
                              onPressed: _loading ? null : () => _submit(item),
                            ),
                        ],
                      ),
                    ] else ...[
                      for (final m in _messages) _Bubble(message: m),
                      if (_loading)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Thinking…',
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
                                backgroundColor: AppTheme.brandPrimary.withAlpha(40),
                                side: BorderSide(
                                  color: AppTheme.brandPrimary.withAlpha(90),
                                ),
                                onPressed: () => _openIntent(chip.query),
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
                      '✨ AI-powered · Answers are generated by AI. AI can make mistakes. Consider verifying important information.',
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
                              border: Border.all(color: Colors.white.withAlpha(50)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    color: Colors.white.withAlpha(120), size: 20),
                                const SizedBox(width: 8),
                                Icon(Icons.mic_none_rounded,
                                    color: Colors.white.withAlpha(120), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    enabled: !_loading,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Ask anything...',
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
                              color: Colors.white.withAlpha(20),
                              border: Border.all(color: Colors.white.withAlpha(40)),
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
                                  color: Colors.white.withAlpha(10),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(20),
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
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _ChatBubble message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.brandPrimary.withAlpha(40)
              : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withAlpha(24)),
        ),
        child: Text(
          message.content,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
          ),
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
          color: Colors.white.withAlpha(14),
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 18),
      ),
    );
  }
}
