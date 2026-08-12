import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/conversation.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/message_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final Conversation conversation;

  const ChatRoomScreen({
    super.key,
    required this.conversation,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final repo = ref.read(messageRepositoryProvider);
      await repo.sendMessage(widget.conversation.id, text);
      _textController.clear();
      // Refresh messages
      ref.invalidate(chatMessagesProvider(widget.conversation.id));
      
      // Scroll to bottom after a delay to allow list to rebuild
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // Since we usually want to show newest at bottom, but if reversed=true, it's 0
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.conversation.id));
    final name = widget.conversation.clientProfile?.displayName ?? widget.conversation.ownerProfile?.displayName ?? 'Unknown';
    final avatarUrl = widget.conversation.clientProfile?.avatarUrl ?? widget.conversation.ownerProfile?.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          backgroundColor: AppTheme.dashElevated,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary)),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.textPrimary))),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hi to $name!',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    ),
                  );
                }
                final sortedMessages = List.of(messages)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  reverse: true,
                  itemCount: sortedMessages.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final msg = sortedMessages[index];
                    final isMe = msg.senderId == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(
                                  colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                                )
                              : null,
                          color: isMe ? null : AppTheme.dashWell,
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
                          ),
                          border: isMe ? null : Border.all(color: AppTheme.dashGlassBorder),
                        ),
                        child: Text(
                          msg.messageText ?? '',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.dashElevated,
              border: Border(top: BorderSide(color: AppTheme.dashGlassBorder, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.dashWell,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.dashGlassBorder, width: 1),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
                            border: InputBorder.none,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                        ),
                      ),
                      child: _isSending
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
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
