import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/likes/domain/profile_like.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/who_liked_you_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:google_fonts/google_fonts.dart';

class WhoLikedYouScreen extends ConsumerWidget {
  const WhoLikedYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(whoLikedYouProvider);

    return Scaffold(
      backgroundColor: Colors.black,
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
                        Text('WHO LIKED YOU', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                        Text(
                          'People who swiped right on your profile',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.read(whoLikedYouProvider.notifier).refresh(),
                    child: const Text('Could not load — retry'),
                  ),
                ),
                data: (people) {
                  if (people.isEmpty) {
                    return Center(
                      child: Text(
                        'No profile likes yet.',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: people.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return _PersonCard(
                        person: person,
                        onOpen: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProfileDetailScreen(userId: person.userId),
                            ),
                          );
                        },
                        onMessage: () async {
                          HapticFeedback.mediumImpact();
                          final convoId = await SwipeRepository()
                              .startConversation(ownerId: person.userId);
                          if (!context.mounted || convoId == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversation: ChatConversation(
                                  id: convoId,
                                  otherUserId: person.userId,
                                  name: person.name,
                                  lastMessage: '',
                                  timestamp: 'now',
                                  avatarUrl: person.primaryImage,
                                ),
                              ),
                            ),
                          );
                        },
                        onDismiss: () => ref
                            .read(whoLikedYouProvider.notifier)
                            .dismiss(person.userId),
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

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.onOpen,
    required this.onMessage,
    required this.onDismiss,
  });

  final ProfileLike person;
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
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white12,
                backgroundImage: person.primaryImage != null
                    ? NetworkImage(person.primaryImage!)
                    : null,
                child: person.primaryImage == null
                    ? const Icon(Icons.person_rounded, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (person.occupation != null) person.occupation!,
                        if (person.age != null) '${person.age}',
                      ].join(' · '),
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54, fontSize: 12),
                    ),
                    if (person.bio != null && person.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        person.bio!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
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
          color: Colors.white.withAlpha(20),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: const Center(
          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
