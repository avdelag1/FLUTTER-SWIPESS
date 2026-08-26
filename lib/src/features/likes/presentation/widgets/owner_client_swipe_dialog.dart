import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/liquid_glass.dart';
import 'package:flutter_swipes/src/features/likes/data/repositories/likes_repository.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Cap `OwnerClientSwipeDialog` — Discover Potential Clients deck.
Future<void> showOwnerClientSwipeDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(160),
    builder: (_) => const OwnerClientSwipeDialog(),
  );
}

class OwnerClientSwipeDialog extends ConsumerStatefulWidget {
  const OwnerClientSwipeDialog({super.key});

  @override
  ConsumerState<OwnerClientSwipeDialog> createState() =>
      _OwnerClientSwipeDialogState();
}

class _OwnerClientSwipeDialogState
    extends ConsumerState<OwnerClientSwipeDialog> {
  int _index = 0;

  Future<void> _message(InterestedClient client) async {
    AppHaptics.medium();
    final convoId = await SwipeRepository().startConversation(
      ownerId: client.userId,
    );
    if (!mounted || convoId == null) return;
    Navigator.of(context).pop();
    await showChatPopup(
      context,
      isNewConversation: true,
      conversation: ChatConversation(
        id: convoId,
        otherUserId: client.userId,
        name: client.name,
        lastMessage: '',
        timestamp: 'now',
        avatarUrl: client.primaryImage,
      ),
    );
  }

  void _pass(InterestedClient client) {
    AppHaptics.selection();
    setState(() => _index++);
  }

  void _like(InterestedClient client) {
    AppHaptics.medium();
    setState(() => _index++);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Interested in ${client.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(interestedClientsProvider);

    return LiquidGlassSheet(
      heightFactor: 0.92,
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () =>
                ref.read(interestedClientsProvider.notifier).refresh(),
            child: const Text('Could not load clients — retry'),
          ),
        ),
        data: (clients) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discover Potential Clients',
                            style: AppTheme.displayItalic.copyWith(
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            'Swipe through people who matched your listings',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: clients.isEmpty || _index >= clients.length
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LiquidGlassPanel(
                                borderRadius: 24,
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.people_outline_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'NO MORE CLIENTS',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Check Interested Clients later, or refresh the deck.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  setState(() => _index = 0);
                                  ref
                                      .read(interestedClientsProvider.notifier)
                                      .refresh();
                                },
                                child: const Text('Reload deck'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _Deck(
                        client: clients[_index],
                        remaining: clients.length - _index,
                        onPass: () => _pass(clients[_index]),
                        onLike: () => _like(clients[_index]),
                        onMessage: () => _message(clients[_index]),
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfileDetailScreen(
                                userId: clients[_index].userId,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Deck extends StatelessWidget {
  const _Deck({
    required this.client,
    required this.remaining,
    required this.onPass,
    required this.onLike,
    required this.onMessage,
    required this.onOpen,
  });

  final InterestedClient client;
  final int remaining;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onMessage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (client.occupation != null) client.occupation!,
      if (client.age != null) '${client.age}',
    ].where((e) => e.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: LiquidGlassPill(
              child: Text(
                '$remaining LEFT',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            // Cap `SimpleOwnerSwipeCard` — full-bleed photo + glass side rail.
            child: GestureDetector(
              onTap: onOpen,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (client.primaryImage != null &&
                        client.primaryImage!.isNotEmpty)
                      CachedNetworkImage(
  imageUrl: client.primaryImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFF16161C),
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white24,
                            size: 64,
                          ),
                        ),
                      )
                    else
                      const ColoredBox(
                        color: Color(0xFF16161C),
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white24,
                          size: 64,
                        ),
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.45, 0.72, 1],
                          colors: [
                            Colors.transparent,
                            Color(0x99000000),
                            Color(0xE6000000),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 72,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (client.likedListingTitle != null) ...[
                            const SizedBox(height: 10),
                            LiquidGlassPill(
                              child: Text(
                                'Liked: ${client.likedListingTitle}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 22,
                      child: LiquidGlassPanel(
                        borderRadius: 999,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RailBtn(icon: Icons.close_rounded, onTap: onPass),
                            const SizedBox(height: 10),
                            _RailBtn(
                              icon: Icons.chat_bubble_outline_rounded,
                              onTap: onMessage,
                              accent: const Color(0xFF00E5FF), // Vibrant Neon Cyan
                            ),
                            const SizedBox(height: 10),
                            _RailBtn(
                              icon: Icons.favorite_rounded,
                              onTap: onLike,
                              accent: const Color(0xFFEB4898),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailBtn extends StatelessWidget {
  const _RailBtn({required this.icon, required this.onTap, this.accent});

  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: accent ?? Colors.white, size: 22),
      ),
    );
  }
}
