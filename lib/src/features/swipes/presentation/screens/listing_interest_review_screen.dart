import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_interest_repository.dart';
import 'package:google_fonts/google_fonts.dart';

class ListingInterestReviewScreen extends ConsumerStatefulWidget {
  const ListingInterestReviewScreen({
    super.key,
    required this.listingId,
    required this.likerId,
  });

  final String listingId;
  final String likerId;

  @override
  ConsumerState<ListingInterestReviewScreen> createState() =>
      _ListingInterestReviewScreenState();
}

class _ListingInterestReviewScreenState
    extends ConsumerState<ListingInterestReviewScreen> {
  bool _busy = false;

  Future<void> _accept(ListingInterest interest) async {
    if (_busy) return;
    setState(() => _busy = true);
    AppHaptics.medium();
    try {
      final conversationId = await ref
          .read(listingInterestRepositoryProvider)
          .accept(listingId: interest.listingId, likerId: interest.likerId);
      if (!mounted) return;
      await AppHaptics.success();
      if (conversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matched. Chat is now open for free.')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      await showChatPopup(
        context,
        isNewConversation: true,
        conversation: ChatConversation(
          id: conversationId,
          otherUserId: interest.likerId,
          name: interest.memberName,
          avatarUrl: interest.memberAvatar,
          lastMessage: '',
          timestamp: 'now',
          listingTag: interest.listingTitle,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept this interest. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ink,
        title: const Text('Interest'),
      ),
      body: FutureBuilder<ListingInterest?>(
        future: ref.read(listingInterestRepositoryProvider).fetch(
              listingId: widget.listingId,
              likerId: widget.likerId,
            ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final interest = snapshot.data;
          if (interest == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'This interest is no longer available.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 40),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppTheme.brandPrimary.withAlpha(26),
                  backgroundImage: interest.memberAvatar == null
                      ? null
                      : NetworkImage(interest.memberAvatar!),
                  child: interest.memberAvatar == null
                      ? Text(
                          _initials(interest.memberName),
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.brandPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                interest.isNeed ? 'THEY CAN HELP' : 'THEY’RE INTERESTED',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                interest.memberName,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                interest.isNeed
                    ? 'Responded to “${interest.listingTitle}”'
                    : 'Interested in “${interest.listingTitle}”',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.muted(context),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: ink.withAlpha(9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ink.withAlpha(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rule('❤️ Their interest was free.'),
                    _rule('🤝 Accepting creates a mutual match.'),
                    _rule('💬 Chat opens free for both of you.'),
                    _rule('🪙 No Direct Request token is used.'),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _accept(interest),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.favorite_rounded, size: 18),
                  label: const Text('MATCH & OPEN FREE CHAT'),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    side: BorderSide(color: ink.withAlpha(35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('NOT NOW'),
                ),
              ),
              const SizedBox(height: 11),
              Text(
                'Nobody can force a conversation. You choose who becomes a match.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.faint(context),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rule(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.ink(context),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      );

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return words.take(2).map((e) => e[0].toUpperCase()).join();
  }
}
