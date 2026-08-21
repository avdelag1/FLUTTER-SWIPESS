import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/direct_requests/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DirectRequestScreen extends StatefulWidget {
  const DirectRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<DirectRequestScreen> createState() => _DirectRequestScreenState();
}

class _DirectRequestScreenState extends State<DirectRequestScreen> {
  final _repo = DirectRequestRepository();
  DirectRequest? _request;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final request = await _repo.fetchById(widget.requestId);
      if (mounted) setState(() => _request = request);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    AppHaptics.medium();
    try {
      final result = await _repo.respond(
        requestId: widget.requestId,
        accept: accept,
      );
      if (!mounted) return;
      if (accept && result.status == 'accepted') {
        await AppHaptics.success();
        final request = _request;
        if (request != null && result.conversationId != null) {
          await showChatPopup(
            context,
            isNewConversation: true,
            conversation: ChatConversation(
              id: result.conversationId!,
              otherUserId: request.senderId,
              name: 'Direct Request',
              lastMessage: request.message,
              timestamp: 'now',
              listingTag: request.listingId,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Declined. The sender keeps their token.'),
          ),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this request.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.cancel(widget.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled. Your token is available again.')),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isReceiver = request?.receiverId == uid;
    final isSender = request?.senderId == uid;

    return Scaffold(
      backgroundColor: SwipessTokens.darkCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'DIRECT REQUEST',
          style: SwipessTokens.displayItalic(fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : request == null
          ? const Center(
              child: Text('Request unavailable', style: TextStyle(color: Colors.white70)),
            )
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withAlpha(24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              Text(
                                request.status.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            request.message.trim().isEmpty
                                ? 'Priority request — no extra message.'
                                : request.message,
                            style: SwipessTokens.bodyClean(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            request.isPending
                                ? 'One token is reserved. It is only spent if this request is accepted.'
                                : request.isAccepted
                                ? 'Accepted. The introduction is complete and chat is open.'
                                : 'No token was spent on this request.',
                            style: SwipessTokens.bodyClean(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (request.isPending && isReceiver) ...[
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _busy ? null : () => _respond(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'ACCEPT & OPEN CHAT',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _respond(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('DECLINE'),
                        ),
                      ),
                    ] else if (request.isPending && isSender)
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('CANCEL REQUEST'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Interest is free. Matches are free. Priority uses Direct Requests.',
                      textAlign: TextAlign.center,
                      style: SwipessTokens.bodyClean(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
