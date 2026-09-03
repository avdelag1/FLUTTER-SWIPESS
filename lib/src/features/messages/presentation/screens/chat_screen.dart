import 'package:flutter_swipes/src/features/ai/domain/voice_transcript_normalize.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_glass.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/voice_language_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_documents_sheet.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Premium Swipess peer-to-peer conversation surface.
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
  final _voice = LiveVoiceInput.instance;

  bool _sending = false;
  bool _showEmoji = false;
  bool _showSearch = false;
  bool _recording = false;
  bool _transcribing = false;
  int? _countdown;
  Timer? _countdownTimer;

  static const _emojis = [
    '👋',
    '😊',
    '😄',
    '😂',
    '🥰',
    '😍',
    '🤩',
    '😎',
    '🙏',
    '👍',
    '🔥',
    '❤️',
    '🎉',
    '✨',
    '💯',
    '🤝',
    '💪',
    '👏',
    '🥳',
    '😇',
    '🤗',
    '😁',
    '🌟',
    '📬',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _scroll.dispose();
    _search.dispose();
    _countdownTimer?.cancel();
    unawaited(_voice.cancel(owner: this));
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _cancelVoiceCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  void _beginVoiceCountdown() {
    if (!mounted ||
        !_recording ||
        _controller.text.trim().isEmpty ||
        _sending) {
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
      unawaited(_finishVoiceAndSend());
    });
  }

  Future<void> _finishVoiceAndSend() async {
    _cancelVoiceCountdown();
    if (_voice.isOwnedBy(this)) {
      await _voice.finish(owner: this);
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _transcribing = false;
    });
    if (_controller.text.trim().isNotEmpty) await _send();
  }

  Future<void> _toggleVoice() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_voice.isOwnedBy(this) || _recording) {
      await _finishVoiceAndSend();
      return;
    }

    unawaited(AppHaptics.voiceStart());
    try {
      // Every voice surface follows the one explicit app-level choice. This
      // prevents chat from using a different recognizer locale than dashboard,
      // Intel Core, or the AI listing creator.
      final lang = ref.read(voiceLanguageProvider).localeCode;
      final started = await _voice.start(
        owner: this,
        initialText: _controller.text,
        languageCode: lang,
        listenMode: ListenMode.dictation,
        onText: (text) {
          if (!mounted) return;
          if (_countdown != null &&
              !shouldCancelVoiceCountdownForText(
                incoming: text,
                locked: _controller.text,
              )) {
            // Keep counting, it was just a transcript re-evaluation
          } else {
            _cancelVoiceCountdown();
          }
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          if (!_recording) setState(() => _recording = true);
        },
        onSilence: _beginVoiceCountdown,
        onListeningChanged: (_) {
          if (!mounted) return;
          final active = _voice.isOwnedBy(this);
          if (_recording != active) setState(() => _recording = active);
        },
        onError: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        },
      );
      if (mounted) setState(() => _recording = started);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the microphone')),
        );
      }
    }
  }

  Future<void> _send([String? preset]) async {
    if (preset == null && (_voice.isOwnedBy(this) || _recording)) {
      _cancelVoiceCountdown();
      await _voice.finish(owner: this);
      if (mounted) setState(() => _recording = false);
    }
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
      ref.invalidate(conversationsProvider);
      ref.read(dailyQuestsProvider.notifier).increment('message');
      _scrollToEnd();
    } catch (_) {
      if (mounted && preset == null && _controller.text.isEmpty) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message not sent — try again')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _replyTo(ChatMessage msg) {
    final excerpt = msg.text.trim().replaceAll('\n', ' ');
    final short = excerpt.length > 80
        ? '${excerpt.substring(0, 80)}…'
        : excerpt;
    _controller.text = '↪ $short\n';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  Future<void> _unsend(ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unsend message?'),
        content: Text(
          'This removes the message from this conversation for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Unsend'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(messageRepositoryProvider)
          .unsendMessage(
            conversationId: widget.conversation.id,
            messageId: msg.id,
          );
      ref.invalidate(conversationMessagesProvider(widget.conversation.id));
      ref.invalidate(conversationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Message unsent')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unsend this message')),
        );
      }
    }
  }

  Future<void> _showMessageActions(
    ChatMessage msg, {
    required bool mine,
  }) async {
    AppHaptics.medium();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: SwipessGlassPanel(
            margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
            radius: 30,
            strong: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: SwipessGlassLook.faint(sheetContext).withAlpha(110),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final emoji in const [
                      '❤️',
                      '😂',
                      '👍',
                      '🔥',
                      '👏',
                      '🙏',
                    ])
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _send(emoji);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(emoji, style: TextStyle(fontSize: 25)),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 10),
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
    final q = _search.text.trim().toLowerCase();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: SwipessGlassLook.canvas(context),
      body: Stack(
        children: [
          const Positioned.fill(child: _ThreadAtmosphere()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _ChatHeader(
                  conversation: widget.conversation,
                  searchActive: _showSearch,
                  onBack: widget.onBack,
                  onShare: () => AppShare.profile(
                    id: widget.conversation.otherUserId,
                    name: widget.conversation.name,
                  ),
                  onSearch: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _search.clear();
                  }),
                ),
                if (_showSearch)
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: _ThreadSearch(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                Expanded(
                  child: messagesAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: SwipessGlassLook.accent,
                        strokeWidth: 2,
                      ),
                    ),
                    error: (_, _) => _ThreadEmpty(
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
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Start the conversation',
                          description: 'Say hello, ask a question or share a document securely.',
                        );
                      }
                      if (q.isNotEmpty && visible.isEmpty) {
                        return _ThreadEmpty(
                          icon: Icons.search_rounded,
                          title: 'No matches',
                          description:
                              'No messages contain “${_search.text.trim()}”',
                        );
                      }

                      return ListView.builder(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(14, 10, 14, 16),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final msg = visible[index];
                          final mine = msg.senderId == myId;
                          return _MessageRow(
                            message: msg,
                            mine: mine,
                            time: _relTime(msg.createdAt),
                            onActions: () =>
                                _showMessageActions(msg, mine: mine),
                          );
                        },
                      );
                    },
                  ),
                ),
                _Composer(
                  controller: _controller,
                  emojis: _emojis,
                  showEmoji: _showEmoji,
                  recording: _recording,
                  transcribing: _transcribing,
                  countdown: _countdown,
                  sending: _sending,
                  onToggleEmoji: () => setState(() => _showEmoji = !_showEmoji),
                  onVoice: _toggleVoice,
                  onDocument: () => showChatDocumentsSheet(
                    context,
                    conversationId: widget.conversation.id,
                    otherUserName: widget.conversation.name,
                    otherUserId: widget.conversation.otherUserId,
                  ),
                  onEmoji: (emoji) {
                    AppHaptics.selection();
                    _controller.text += emoji;
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                  },
                  onSend: () => _send(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadAtmosphere extends StatelessWidget {
  const _ThreadAtmosphere();

  @override
  Widget build(BuildContext context) {
    final light = SwipessGlassLook.isLight(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1.05, -1.05),
            radius: 1.5,
            colors: [
              (light ? const Color(0xFFFFF0F5) : const Color(0xFF20151C))
                  .withAlpha(light ? 215 : 130),
              SwipessGlassLook.canvas(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.conversation,
    required this.searchActive,
    required this.onBack,
    required this.onShare,
    required this.onSearch,
  });

  final ChatConversation conversation;
  final bool searchActive;
  final VoidCallback? onBack;
  final VoidCallback onShare;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final ink = SwipessGlassLook.ink(context);
    final muted = SwipessGlassLook.muted(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Row(
        children: [
          CapBackButton(onTap: onBack),
          SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: conversation.isOnline
                      ? const LinearGradient(
                          colors: [
                            SwipessGlassLook.accentWarm,
                            SwipessGlassLook.accent,
                          ],
                        )
                      : null,
                  color: conversation.isOnline
                      ? null
                      : SwipessGlassLook.hairline(context),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: SwipessGlassLook.field(context),
                  backgroundImage: conversation.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(conversation.avatarUrl!)
                      : null,
                  child: conversation.avatarUrl?.isNotEmpty == true
                      ? null
                      : Text(
                          conversation.name.isNotEmpty
                              ? conversation.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: 1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: conversation.isOnline
                        ? const Color(0xFF43D17A)
                        : SwipessGlassLook.faint(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SwipessGlassLook.canvas(context),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -.25,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  conversation.isOnline ? 'Active now' : 'Offline',
                  style: GoogleFonts.plusJakartaSans(
                    color: conversation.isOnline
                        ? const Color(0xFF43D17A)
                        : muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SwipessGlassIconButton(
            icon: Icons.ios_share_rounded,
            tooltip: 'Share profile',
            onTap: onShare,
          ),
          SizedBox(width: 6),
          SwipessGlassIconButton(
            icon: searchActive ? Icons.close_rounded : Icons.search_rounded,
            tooltip: 'Search chat',
            active: searchActive,
            onTap: onSearch,
          ),
        ],
      ),
    );
  }
}

class _ThreadSearch extends StatelessWidget {
  const _ThreadSearch({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwipessGlassPanel(
      radius: 22,
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: SwipessGlassLook.muted(context),
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                style: TextStyle(
                  color: SwipessGlassLook.ink(context),
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search in this chat…',
                  hintStyle: TextStyle(
                    color: SwipessGlassLook.muted(context),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.mine,
    required this.time,
    required this.onActions,
  });

  final ChatMessage message;
  final bool mine;
  final String time;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ink = SwipessGlassLook.ink(context);
    final muted = SwipessGlassLook.muted(context);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * .78),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: onActions,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: mine
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              SwipessGlassLook.accentWarm,
                              SwipessGlassLook.accent,
                            ],
                          )
                        : null,
                    color: mine ? null : SwipessGlassLook.panelStrong(context),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(23),
                      topRight: const Radius.circular(23),
                      bottomLeft: Radius.circular(mine ? 23 : 8),
                      bottomRight: Radius.circular(mine ? 8 : 23),
                    ),
                    border: Border.all(
                      color: mine
                          ? SwipessGlassLook.accent.withAlpha(65)
                          : SwipessGlassLook.hairline(context),
                    ),
                    boxShadow: mine ? SwipessGlassLook.shadow(context) : null,
                  ),
                  child: message.isDocument
                      ? _DocumentBubble(msg: message, mine: mine)
                      : Text(
                          message.text,
                          style: GoogleFonts.plusJakartaSans(
                            color: mine ? Colors.white : ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    GestureDetector(
                      onTap: onActions,
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: muted,
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
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.emojis,
    required this.showEmoji,
    required this.recording,
    required this.transcribing,
    required this.countdown,
    required this.sending,
    required this.onToggleEmoji,
    required this.onDocument,
    required this.onEmoji,
    required this.onSend,
    this.onVoice,
  });

  final TextEditingController controller;
  final List<String> emojis;
  final bool showEmoji;
  final bool recording;
  final bool transcribing;
  final int? countdown;
  final bool sending;
  final VoidCallback onToggleEmoji;
  final VoidCallback onDocument;
  final ValueChanged<String> onEmoji;
  final VoidCallback onSend;
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.text.trim().isNotEmpty && !sending;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 3, 10, 7),
        child: Column(
          children: [
            if (recording || transcribing || countdown != null)
              Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: recording
                            ? SwipessGlassLook.accent
                            : SwipessGlassLook.aiSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 7),
                    Text(
                      countdown != null
                          ? 'SILENCE · SENDING IN $countdown…'
                          : recording
                          ? 'LISTENING · SPEAK NATURALLY'
                          : 'TRANSCRIBING…',
                      style: GoogleFonts.plusJakartaSans(
                        color: SwipessGlassLook.muted(context),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .65,
                      ),
                    ),
                  ],
                ),
              ),
            if (showEmoji)
              SwipessGlassPanel(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(10),
                radius: 24,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final emoji in emojis)
                      GestureDetector(
                        onTap: () => onEmoji(emoji),
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: Center(
                            child: Text(emoji, style: TextStyle(fontSize: 21)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            SwipessGlassPanel(
              radius: 28,
              blur: 24,
              strong: true,
              padding: EdgeInsets.fromLTRB(6, 6, 5, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SwipessGlassIconButton(
                    icon: Icons.description_outlined,
                    tooltip: 'Documents',
                    size: 38,
                    iconSize: 18,
                    onTap: onDocument,
                  ),
                  SizedBox(width: 4),
                  SwipessGlassIconButton(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    tooltip: 'Emoji',
                    active: showEmoji,
                    size: 38,
                    iconSize: 18,
                    onTap: onToggleEmoji,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (enabled) onSend();
                      },
                      style: GoogleFonts.plusJakartaSans(
                        color: SwipessGlassLook.ink(context),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: TextStyle(
                          color: SwipessGlassLook.muted(context),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  SwipessGlassIconButton(
                    icon: recording
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    tooltip: countdown != null
                        ? 'Sending in $countdown'
                        : recording
                        ? 'Finish voice message now'
                        : 'Voice message',
                    active: recording || transcribing || countdown != null,
                    size: 38,
                    iconSize: 18,
                    onTap: onVoice ?? () {},
                  ),
                  SizedBox(width: 5),
                  SwipessSendButton(
                    enabled: enabled,
                    loading: sending,
                    size: 48,
                    onTap: onSend,
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final color = destructive
        ? const Color(0xFFFF6B6B)
        : SwipessGlassLook.ink(context);
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
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                gradient: LinearGradient(
                  colors: [
                    SwipessGlassLook.accentWarm.withAlpha(40),
                    SwipessGlassLook.accent.withAlpha(26),
                  ],
                ),
                border: Border.all(color: SwipessGlassLook.hairline(context)),
              ),
              child: Icon(icon, color: SwipessGlassLook.ink(context), size: 31),
            ),
            SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: SwipessGlassLook.ink(context),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 9),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: SwipessGlassLook.muted(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentBubble extends StatelessWidget {
  const _DocumentBubble({required this.msg, required this.mine});

  final ChatMessage msg;
  final bool mine;

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
    final ink = mine ? Colors.white : SwipessGlassLook.ink(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final doc in docs)
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_rounded, color: ink, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    doc.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
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
            color: ink.withAlpha(180),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
