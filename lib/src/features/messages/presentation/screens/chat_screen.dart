import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
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

/// Swipess thread with native chat actions and live message stream.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversation, this.onBack});

  final ChatConversation conversation;
  final VoidCallback? onBack;

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
    _controller.addListener(_composerChanged);
  }

  void _composerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_composerChanged);
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
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
    AppHaptics.selection();
    setState(() {
      _sending = true;
      _showEmoji = false;
    });
    if (preset == null) _controller.clear();
    try {
      await ref
          .read(messageRepositoryProvider)
          .sendMessage(conversationId: widget.conversation.id, text: text);
      ref.invalidate(conversationMessagesProvider(widget.conversation.id));
      ref.read(dailyQuestsProvider.notifier).increment('message');
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _replyTo(ChatMessage msg) {
    final excerpt = msg.text.trim().replaceAll('\n', ' ');
    final short = excerpt.length > 80 ? '${excerpt.substring(0, 80)}…' : excerpt;
    _controller.text = '↪ $short\n';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  Future<void> _unsend(ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsend message?'),
        content: const Text(
          'This removes the message from this conversation for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(messageRepositoryProvider).unsendMessage(
            conversationId: widget.conversation.id,
            messageId: msg.id,
          );
      ref.invalidate(conversationMessagesProvider(widget.conversation.id));
      ref.invalidate(conversationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message unsent')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unsend this message')),
        );
      }
    }
  }

  Future<void> _showMessageActions(ChatMessage msg, {required bool mine}) async {
    AppHaptics.medium();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xF516171C),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final emoji in const ['❤️', '😂', '👍', '🔥', '👏', '🙏'])
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _send(emoji);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(emoji, style: const TextStyle(fontSize: 25)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _replyTo(msg);
                  },
                ),
                _ActionTile(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Clipboard.setData(ClipboardData(text: msg.text));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message copied')),
                      );
                    }
                  },
                ),
                _ActionTile(
                  icon: Icons.refresh_rounded,
                  label: 'Send again',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _send(msg.text);
                  },
                ),
                _ActionTile(
                  icon: Icons.forward_to_inbox_rounded,
                  label: 'Forward / share',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    AppShare.text(msg.text, subject: 'Shared from Swipess');
                  },
                ),
                if (mine)
                  _ActionTile(
                    icon: Icons.undo_rounded,
                    label: 'Unsend for everyone',
                    destructive: true,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _unsend(msg);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _relTime(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat.MMMd().format(time);
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.conversation.id),
    );
    ref.listen(conversationMessagesProvider(widget.conversation.id), (_, next) {
      next.whenData((_) => _scrollToEnd());
    });

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final online = widget.conversation.isOnline;
    final q = _search.text.trim().toLowerCase();
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1015),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 8, 8, 8),
            child: Row(
              children: [
                CapBackButton(onTap: widget.onBack),
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
                              backgroundImage: widget.conversation.avatarUrl != null
                                  ? NetworkImage(widget.conversation.avatarUrl!)
                                  : null,
                              child: widget.conversation.avatarUrl == null
                                  ? Text(
                                      widget.conversation.name.isNotEmpty
                                          ? widget.conversation.name[0].toUpperCase()
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
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              online ? 'ACTIVE NOW' : 'OFFLINE',
                              style: GoogleFonts.plusJakartaSans(
                                color: online
                                    ? const Color(0xFFA78BFA)
                                    : Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundIcon(
                  icon: Icons.ios_share_rounded,
                  onTap: () => AppShare.profile(
                    id: widget.conversation.otherUserId,
                    name: widget.conversation.name,
                  ),
                ),
                const SizedBox(width: 6),
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
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: _orange, size: 18),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: Colors.white.withAlpha(25)),
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
                description: 'The connection stalled. Check your network and try again.',
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
                    description: 'Initialize the connection stream with a greeting',
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
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final msg = visible[index];
                    final mine = msg.senderId == myId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
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
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onLongPress: () => _showMessageActions(msg, mine: mine),
                                child: Container(
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
                                    color: mine ? null : const Color(0xFF16161C),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(24),
                                      topRight: const Radius.circular(24),
                                      bottomLeft: Radius.circular(mine ? 24 : 6),
                                      bottomRight: Radius.circular(mine ? 6 : 24),
                                    ),
                                    boxShadow: mine
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x3DEB4898),
                                              blurRadius: 14,
                                              offset: Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: msg.isDocument
                                      ? _DocumentBubble(msg: msg)
                                      : Text(
                                          msg.text,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            height: 1.4,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _relTime(msg.createdAt),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white30,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _showMessageActions(msg, mine: mine),
                                      child: const Icon(
                                        Icons.more_horiz_rounded,
                                        color: Colors.white30,
                                        size: 14,
                                      ),
                                    ),
                                  ],
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
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final e in _emojis)
                            GestureDetector(
                              onTap: () {
                                AppHaptics.selection();
                                _controller.text += e;
                                _controller.selection = TextSelection.collapsed(
                                  offset: _controller.text.length,
                                );
                              },
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: Text(e, style: const TextStyle(fontSize: 22)),
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
                          otherUserName: widget.conversation.name,
                          otherUserId: widget.conversation.otherUserId,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _RoundIcon(
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        active: _showEmoji,
                        onTap: () => setState(() => _showEmoji = !_showEmoji),
                      ),
                      const SizedBox(width: 6),
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
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withAlpha(10),
                            contentPadding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Color(0x66EB4898)),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _RoundIcon(
                        icon: _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                        active: _recording || _transcribing,
                        onTap: _transcribing ? () {} : _toggleVoice,
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _sending || _controller.text.trim().isEmpty
                            ? null
                            : () => _send(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _controller.text.trim().isNotEmpty
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                                  )
                                : null,
                            color: _controller.text.trim().isEmpty
                                ? Colors.white.withAlpha(28)
                                : null,
                          ),
                          child: const Icon(
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFFF6B6B) : Colors.white;
    return ListTile(
      dense: true,
      minLeadingWidth: 28,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: color, size: 21),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
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
        AppHaptics.light();
        onTap();
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? const Color(0x26F43F5E) : Colors.white.withAlpha(14),
          border: Border.all(
            color: active
                ? const Color(0x66F43F5E)
                : Colors.white.withAlpha(26),
          ),
        ),
        child: Icon(
          icon,
          color: active ? const Color(0xFFFB7185) : Colors.white,
          size: 19,
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0x33F43F5E), Color(0x337C3AED)],
                ),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentBubble extends StatelessWidget {
  const _DocumentBubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final docs = msg.attachments.isEmpty
        ? [
            DocumentAttachment(
              id: msg.id,
              title: msg.text.isEmpty ? 'Document' : msg.text,
            ),
          ]
        : msg.attachments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final doc in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    doc.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          docs.first.status.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}