import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Receiver-side consent screen for a priority Direct Request.
/// Accepting consumes one token from the sender and opens chat. Declining never
/// costs the sender a token.
class DirectRequestDecisionScreen extends ConsumerStatefulWidget {
  const DirectRequestDecisionScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<DirectRequestDecisionScreen> createState() =>
      _DirectRequestDecisionScreenState();
}

class _DirectRequestDecisionScreenState
    extends ConsumerState<DirectRequestDecisionScreen> {
  Map<String, dynamic>? _request;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await ref
          .read(directRequestRepositoryProvider)
          .fetchById(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = row;
        _loading = false;
        _error = row == null ? 'This Direct Request is no longer available.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this Direct Request.';
      });
    }
  }

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(directRequestRepositoryProvider).respond(
            requestId: widget.requestId,
            accept: accept,
          );
      ref.invalidate(directRequestBalanceProvider);
      if (!mounted) return;

      if (!accept) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Declined. Their token was returned.')),
        );
        Navigator.of(context).pop();
        return;
      }

      final senderId = _request?['sender_id']?.toString();
      final conversationId = result.conversationId;
      if (senderId != null && conversationId != null) {
        await showChatPopup(
          context,
          isNewConversation: true,
          conversation: ChatConversation(
            id: conversationId,
            otherUserId: senderId,
            name: 'Direct Request',
            lastMessage: _request?['message']?.toString() ?? '',
            timestamp: 'now',
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: AmbientPageBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: TextStyle(color: ink)))
                  : Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close_rounded, color: ink),
                          ),
                          const Spacer(),
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppTheme.brandPrimary.withAlpha(24),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.bolt_rounded,
                              size: 34,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'DIRECT REQUEST',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.brandPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'They chose to skip the wait.',
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontSize: 28,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Accept only if you want to talk. Their token is spent only if you accept.',
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              height: 1.4,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if ((_request?['message']?.toString() ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: ink.withAlpha(30)),
                              ),
                              child: Text(
                                _request!['message'].toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink,
                                  fontSize: 15,
                                  height: 1.45,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy ? null : () => _respond(false),
                                  child: const Text('DECLINE'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _busy ? null : () => _respond(true),
                                  icon: const Icon(Icons.chat_bubble_rounded),
                                  label: Text(_busy ? 'OPENING…' : 'ACCEPT & CHAT'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
