import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/likes/data/repositories/likes_repository.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor OwnerInterestedClients — applicants who liked my listings.
class OwnerInterestedClientsScreen extends ConsumerWidget {
  const OwnerInterestedClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(interestedClientsProvider);

    return NeoNaiveScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  _Back(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INTERESTED CLIENTS',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          'People who liked your listings',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.read(interestedClientsProvider.notifier).refresh(),
                    icon: const Icon(Icons.sync_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref
                        .read(interestedClientsProvider.notifier)
                        .refresh(),
                    child: const Text('Could not load — retry'),
                  ),
                ),
                data: (clients) {
                  if (clients.isEmpty) {
                    return Center(
                      child: Text(
                        'No interested clients yet.',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: clients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return _ClientCard(
                        client: client,
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProfileDetailScreen(userId: client.userId),
                            ),
                          );
                        },
                        onMessage: () async {
                          HapticFeedback.mediumImpact();
                          final convoId = await SwipeRepository()
                              .startConversation(ownerId: client.userId);
                          if (!context.mounted || convoId == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversation: ChatConversation(
                                  id: convoId,
                                  otherUserId: client.userId,
                                  name: client.name,
                                  lastMessage: '',
                                  timestamp: 'now',
                                  avatarUrl: client.primaryImage,
                                  listingTag: client.likedListingTitle,
                                ),
                              ),
                            ),
                          );
                        },
                        onDismiss: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF14141A),
                              title: const Text('Dismiss client?',
                                  style: TextStyle(color: Colors.white)),
                              content: Text(
                                'Remove ${client.name} from interested clients?',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            ref
                                .read(interestedClientsProvider.notifier)
                                .dismiss(client.userId);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onOpen,
    required this.onMessage,
    required this.onDismiss,
  });

  final InterestedClient client;
  final VoidCallback onOpen;
  final VoidCallback onMessage;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white12,
                backgroundImage: client.primaryImage != null
                    ? NetworkImage(client.primaryImage!)
                    : null,
                child: client.primaryImage == null
                    ? const Icon(Icons.person_rounded, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    if (client.likedListingTitle != null)
                      Text(
                        'Liked: ${client.likedListingTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (client.occupation != null || client.age != null)
                      Text(
                        [
                          if (client.occupation != null) client.occupation!,
                          if (client.age != null) '${client.age}',
                        ].join(' · '),
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline_rounded,
                    color: AppTheme.brandPrimary),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.transparent),
        ),
        child: const Center(
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
