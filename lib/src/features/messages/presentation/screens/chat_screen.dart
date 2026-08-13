import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_documents_sheet.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/voice_transcribe_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap `MessagingInterface` — thread chrome, pink bubbles, empty Swipes Stream.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  bool _sending = false;
  bool _showEmoji = false;
  bool _showSearch = false;
  bool _recording = false;
  bool _transcribing = false;

  static const _orange = AppTheme.brandPrimary;
  static const _emojis = [
    '👋', '😊', '😄', '😂', '🥰', '😍', '🤩', '😎',
    '🙏', '👍', '🔥', '❤️', '🎉', '✨', '💯', '🤝',
    '💪', '👏', '🥳', '😇', '🤗', '😁', '🌟', '📬',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _search.dispose();
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
          _controller.text = text.trim();
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
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

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.selectionClick();
    setState(() {
      _sending = true;
      _showEmoji = false;
    });
    _controller.clear();
    try {
      await ref.read(messageRepositoryProvider).sendMessage(
            conversationId: widget.conversation.id,
            text: text,
          );
      ref.invalidate(conversationMessagesProvider(widget.conversation.id));
      ref.read(dailyQuestsProvider.notifier).increment('message');
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _relTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat.MMMd().format(t);
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(conversationMessagesProvider(widget.conversation.id));
    ref.listen(conversationMessagesProvider(widget.conversation.id), (_, next) {
      next.whenData((_) => _scrollToEnd());
    });
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final online = widget.conversation.isOnline;
    final q = _search.text.trim().toLowerCase();
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 8, 8, 8),
            child: Row(
              children: [
                const CapBackButton(),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF60A5FA),
                                  Color(0xFF7C3AED),
                                  Color(0xFFF43F5E),
                                ],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF121212),
                              backgroundImage:
                                  widget.conversation.avatarUrl != null
                                      ? NetworkImage(
                                          widget.conversation.avatarUrl!,
                                        )
                                      : null,
                              child: widget.conversation.avatarUrl == null
                                  ? Text(
                                      widget.conversation.name.isNotEmpty
                                          ? widget.conversation.name[0]
                                              .toUpperCase()
                                          : '?',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: online
                                    ? const Color(0xFFA78BFA)
                                    : const Color(0xFF64748B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.dashBg,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.conversation.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: online
                                        ? const Color(0xFFA78BFA)
                                        : const Color(0xFF64748B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  online ? 'ACTIVE NOW' : 'OFFLINE',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: online
                                        ? const Color(0xFFA78BFA)
                                        : Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundIcon(
                  icon: Icons.search_rounded,
                  active: _showSearch,
                  onTap: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _search.clear();
                  }),
                ),
              ],
            ),
          ),
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _search,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search in this chat…',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  prefixIcon: const Icon(Icons.search, color: _orange, size: 18),
                  filled: true,
                  fillColor: Colors.white.withAlpha(12),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: Colors.white.withAlpha(24)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: Colors.white.withAlpha(24)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    borderSide: BorderSide(color: Color(0x66EB4898)),
                  ),
                ),
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) => _ThreadEmpty(
                icon: Icons.shield_outlined,
                title: "Couldn't load messages",
                description:
                    'The connection stalled. Check your network and try again.',
                actionLabel: 'RETRY',
                onAction: () => ref.invalidate(
                  conversationMessagesProvider(widget.conversation.id),
                ),
              ),
              data: (messages) {
                final visible = q.isEmpty
                    ? messages
                    : messages
                        .where((m) => m.text.toLowerCase().contains(q))
                        .toList();
                if (messages.isEmpty) {
                  return const _ThreadEmpty(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Swipes Stream',
                    description:
                        'Initialize the connection stream with a greeting',
                  );
                }
                if (q.isNotEmpty && visible.isEmpty) {
                  return _ThreadEmpty(
                    icon: Icons.search_rounded,
                    title: 'No matches',
                    description: 'No messages contain “${_search.text.trim()}”',
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final msg = visible[index];
                    final mine = msg.senderId == myId;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: mine
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [_orange, Color(0xFFC0392B)],
                                        )
                                      : null,
                                  color: mine
                                      ? null
                                      : const Color(0xFF16161C),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(24),
                                    topRight: const Radius.circular(24),
                                    bottomLeft: Radius.circular(mine ? 24 : 6),
                                    bottomRight: Radius.circular(mine ? 6 : 24),
                                  ),
                                  border: mine
                                      ? null
                                      : Border.all(
                                          color: Colors.white.withAlpha(20),
                                        ),
                                  boxShadow: mine
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x4DEB4898),
                                            blurRadius: 20,
                                            offset: Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  msg.text,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  _relTime(msg.createdAt),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white30,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Column(
                children: [
                  if (_showEmoji)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xE6121214),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final e in _emojis)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _controller.text += e;
                                _controller.selection =
                                    TextSelection.collapsed(
                                  offset: _controller.text.length,
                                );
                                setState(() => _showEmoji = false);
                              },
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: Text(
                                    e,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _RoundIcon(
                        icon: Icons.description_outlined,
                        onTap: () => showChatDocumentsSheet(
                          context,
                          conversationId: widget.conversation.id,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundIcon(
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        active: _showEmoji,
                        onTap: () => setState(() => _showEmoji = !_showEmoji),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: capCopy(
                              ref,
                              'Type a message...',
                              'Escribe un mensaje...',
                            ),
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha(80),
                            ),
                            filled: true,
                            fillColor: Colors.white.withAlpha(12),
                            contentPadding: const EdgeInsets.fromLTRB(
                              20,
                              14,
                              16,
                              14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(24),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(24),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0x66EB4898),
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundIcon(
                        icon: _recording
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        active: _recording || _transcribing,
                        onTap: _transcribing ? () {} : _toggleVoice,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sending || _controller.text.trim().isEmpty
                            ? null
                            : () => _send(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _controller.text.trim().isNotEmpty
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [_orange, Color(0xFFFF4D00)],
                                  )
                                : null,
                            color: _controller.text.trim().isEmpty
                                ? Colors.white.withAlpha(38)
                                : null,
                            boxShadow: _controller.text.trim().isNotEmpty
                                ? const [
                                    BoxShadow(
                                      color: Color(0x80EB4898),
                                      blurRadius: 18,
                                      offset: Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? const Color(0x26F43F5E)
              : Colors.white.withAlpha(14),
          border: Border.all(
            color: active
                ? const Color(0x66F43F5E)
                : Colors.white.withAlpha(26),
          ),
        ),
        child: Icon(
          icon,
          color: active ? const Color(0xFFFB7185) : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _ThreadEmpty extends StatelessWidget {
  const _ThreadEmpty({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [
                    const Color(0x33F43F5E),
                    const Color(0x337C3AED),
                  ],
                ),
                border: Border.all(color: Colors.white.withAlpha(14)),
              ),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                description.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  height: 1.6,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEB4898), Color(0xFFFF4D00)],
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
