import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/likes/data/repositories/likes_repository.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/likes_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/widgets/owner_client_swipe_dialog.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';

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
                  CapBackButton(onTap: () => Navigator.pop(context)),
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
                            color: MatteSurface.muted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Discover clients',
                    onPressed: () => showOwnerClientSwipeDialog(context),
                    icon: Icon(
                      Icons.swipe_rounded,
                      color: MatteSurface.muted(context),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.read(interestedClientsProvider.notifier).refresh(),
                    icon: Icon(
                      Icons.sync_rounded,
                      color: MatteSurface.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: MatteSurface.ink(context),
                    strokeWidth: 2,
                  ),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(interestedClientsProvider.notifier).refresh(),
                    child: Text('Could not load — retry'),
                  ),
                ),
                data: (clients) {
                  if (clients.isEmpty) {
                    return Center(
                      child: Text(
                        'No interested clients yet.',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                        ),
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
                          AppHaptics.medium();
                          final convoId = await SwipeRepository()
                              .startConversation(ownerId: client.userId);
                          if (!context.mounted || convoId == null) return;
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
                              listingTag: client.likedListingTitle,
                            ),
                          );
                        },
                        onDismiss: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                'Dismiss client?',
                                style: TextStyle(
                                  color: MatteSurface.ink(context),
                                ),
                              ),
                              content: Text(
                                'Remove ${client.name} from interested clients?',
                                style: TextStyle(
                                  color: MatteSurface.muted(context),
                                ),
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
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MatteSurface.ink(context), width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: client.primaryImage != null
                    ? NetworkImage(client.primaryImage!)
                    : null,
                child: client.primaryImage == null
                    ? Icon(
                        Icons.person_rounded,
                        color: MatteSurface.muted(context),
                      )
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: TextStyle(
                        color: MatteSurface.ink(context),
                        fontWeight: FontWeight.w800,
                      ),
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
                          color: MatteSurface.muted(context),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMessage,
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.brandPrimary,
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  color: MatteSurface.faint(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
