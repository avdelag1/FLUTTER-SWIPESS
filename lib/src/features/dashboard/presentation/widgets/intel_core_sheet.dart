import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/ai_providers.dart';
import 'package:flutter_swipes/src/features/ai/presentation/widgets/memory_drawer.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor Intel Core — chats via Supabase `ai-concierge` edge function.
Future<void> showIntelCoreSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xF20A0A0C),
    builder: (context) => const _IntelCoreSheet(),
  );
}

class _ChatBubble {
  const _ChatBubble({required this.role, required this.content});
  final String role;
  final String content;
}

class _IntelCoreSheet extends ConsumerStatefulWidget {
  const _IntelCoreSheet();

  @override
  ConsumerState<_IntelCoreSheet> createState() => _IntelCoreSheetState();
}

class _IntelCoreSheetState extends ConsumerState<_IntelCoreSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatBubble>[];
  bool _showHistory = false;
  bool _loading = false;

  static const _starters = [
    'Find people looking to buy houses',
    'Find maintenance workers',
    'Show me all rental properties',
    'Show me available houses',
  ];

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

    final lower = q.toLowerCase();
    if (_tryQuickNav(lower)) return;

    final edgeReady = ref.read(aiEdgeReadyProvider);
    setState(() {
      _messages.add(_ChatBubble(role: 'user', content: q));
      _loading = true;
    });
    _scrollToEnd();

    if (!edgeReady) {
      setState(() {
        _messages.add(
          const _ChatBubble(
            role: 'assistant',
            content: 'Sign in to chat with Intel Core — AI runs on Supabase Edge Functions.',
          ),
        );
        _loading = false;
      });
      _scrollToEnd();
      return;
    }

    final history = [
      for (final m in _messages)
        AiChatMessage(role: m.role, content: m.content),
    ];
    final reply = await ref.read(aiEdgeRepositoryProvider).chatConcierge(
          messages: history,
        );
    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatBubble(
          role: 'assistant',
          content: reply?.trim().isNotEmpty == true
              ? reply!.trim()
              : 'AI is temporarily unavailable. Try again in a moment.',
        ),
      );
      _loading = false;
    });
    _scrollToEnd();
  }

  bool _tryQuickNav(String q) {
    if (q.contains('seeker') ||
        q.contains('worker') ||
        q.contains('hire') ||
        q.contains('maintenance')) {
      Navigator.pop(context);
      ref.read(navTabProvider.notifier).set(NavTab.seekers);
      return true;
    }
    if (q.contains('filter')) {
      Navigator.pop(context);
      ref.read(navTabProvider.notifier).set(NavTab.dashboard);
      return true;
    }
    return false;
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _showHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.92;
    final edgeReady = ref.watch(aiEdgeReadyProvider);
    return SizedBox(
      height: height,
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
                          edgeReady ? 'ONLINE · EDGE AI' : 'SIGN IN FOR AI',
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
                        'Ask for properties, workers, seekers, or filters. Open AI Memory to teach Bolt/Brain. Answers come from Supabase Edge Functions (Groq + fallbacks).',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ActionPill(
                        label: 'AI MEMORY · BRAIN',
                        onTap: () {
                          Navigator.pop(context);
                          showMemoryDrawer(context);
                        },
                      ),
                      const SizedBox(height: 10),
                      _ActionPill(
                        label: 'SWIPE DECK',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ClientSwipeContainer(
                                categoryId: 'property',
                                categoryTitle: 'PROPERTIES',
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _ActionPill(
                        label: 'APPLYING SEARCH FILTERS',
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(navTabProvider.notifier).set(NavTab.dashboard);
                        },
                      ),
                      const SizedBox(height: 10),
                      _ActionPill(
                        label: 'OPEN SEEKERS',
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(navTabProvider.notifier).set(NavTab.seekers);
                        },
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
                        ),
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

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.brandPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
