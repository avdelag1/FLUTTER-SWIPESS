import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/swipes/data/interest_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Listing-owner response to a free right-swipe interest.
/// The owner never reads another user's raw like row; the secure RPC validates
/// ownership and returns only the payload required after acceptance.
class InterestDecisionScreen extends ConsumerStatefulWidget {
  const InterestDecisionScreen({super.key, required this.likeId});

  final String likeId;

  @override
  ConsumerState<InterestDecisionScreen> createState() =>
      _InterestDecisionScreenState();
}

class _InterestDecisionScreenState
    extends ConsumerState<InterestDecisionScreen> {
  bool _busy = false;

  Future<void> _match() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(interestRepositoryProvider)
          .accept(widget.likeId);
      if (!mounted) return;
      await showChatPopup(
        context,
        isNewConversation: true,
        conversation: ChatConversation(
          id: result.conversationId,
          otherUserId: result.interestedUserId,
          name: 'New Match',
          lastMessage: '',
          timestamp: 'now',
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create match: $e')),
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
          child: Padding(
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
                    Icons.favorite_rounded,
                    size: 30,
                    color: AppTheme.brandPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'SOMEONE IS INTERESTED',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Interested too?',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Match and your chat opens free for both of you. No token is used.',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('NOT NOW'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _match,
                        icon: const Icon(Icons.favorite_rounded),
                        label: Text(_busy ? 'MATCHING…' : 'MATCH & CHAT'),
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
