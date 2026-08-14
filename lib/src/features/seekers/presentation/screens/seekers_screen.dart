import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_request.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/providers/seekers_provider.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/widgets/seeker_request_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:google_fonts/google_fonts.dart';

class SeekersScreen extends ConsumerWidget {
  const SeekersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(seekersProvider);
    final top = MediaQuery.paddingOf(context).top;

    return NeoNaiveScaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSeekerRequestSheet(context, ref),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label: Text('Post request'),
      ),
      body: async.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                  color: MatteSurface.ink(context), strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: TextButton(
                onPressed: () => ref.read(seekersProvider.notifier).refresh(),
                child: const Text('Could not load seekers — retry'),
              ),
            ),
            data: (requests) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, top + 16, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEEKER\nREQUESTS',
                          style: AppTheme.displayItalic
                              .copyWith(fontSize: 28, height: 1.05),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'People looking for workers & help nearby',
                          style: GoogleFonts.plusJakartaSans(
                              color: MatteSurface.muted(context), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: requests.isEmpty
                        ? Center(
                            child: Text(
                              'No open seeker requests right now.',
                              style: GoogleFonts.plusJakartaSans(
                                  color: MatteSurface.muted(context)),
                            ),
                          )
                        : PageView.builder(
                            controller: PageController(viewportFraction: 0.92),
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final req = requests[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(4, 8, 4, 120),
                                child: _SeekerCard(
                                  request: req,
                                  onPass: () {
                                    AppHaptics.light();
                                    ref
                                        .read(seekersProvider.notifier)
                                        .dismiss(req.id);
                                  },
                                  onInterested: () async {
                                    AppHaptics.medium();
                                    final ownerId = req.ownerId;
                                    if (ownerId != null) {
                                      final convoId = await SwipeRepository()
                                          .startConversation(
                                              ownerId: ownerId,
                                              listingId: req.id);
                                      if (context.mounted && convoId != null) {
                                        await showChatPopup(
                                          context,
                                          isNewConversation: true,
                                          conversation: ChatConversation(
                                            id: convoId,
                                            otherUserId: ownerId,
                                            name: req.seekerName,
                                            lastMessage: '',
                                            timestamp: 'now',
                                            avatarUrl: req.seekerAvatar,
                                            listingTag: req.title,
                                          ),
                                        );
                                      }
                                    }
                                    ref
                                        .read(seekersProvider.notifier)
                                        .dismiss(req.id);
                                  },
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

class _SeekerCard extends StatelessWidget {
  const _SeekerCard({
    required this.request,
    required this.onPass,
    required this.onInterested,
  });

  final SeekerRequest request;
  final VoidCallback onPass;
  final VoidCallback onInterested;

  Color get _accent {
    switch (request.category) {
      case 'cleaning':
        return const Color(0xFF3B82F6);
      case 'plumbing':
        return const Color(0xFF06B6D4);
      case 'electrical':
        return const Color(0xFFF59E0B);
      case 'driving':
        return const Color(0xFF10B981);
      case 'chef':
        return const Color(0xFFF97316);
      case 'fitness':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.brandPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF0A0A0D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MatteSurface.ink(context), width: 1.0),
        image: request.seekerAvatar != null
            ? DecorationImage(
                image: NetworkImage(request.seekerAvatar!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withAlpha(180),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _accent.withAlpha(50),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _accent.withAlpha(120)),
              ),
              child: Text(
                request.category.toUpperCase(),
                style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Spacer(),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: request.seekerAvatar != null
                      ? NetworkImage(request.seekerAvatar!)
                      : null,
                  child: request.seekerAvatar == null
                      ? Text(request.initials, style: TextStyle(color: MatteSurface.ink(context), fontWeight: FontWeight.w900))
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.seekerName, style: TextStyle(color: MatteSurface.ink(context), fontWeight: FontWeight.w900)),
                      Text(request.location, style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              request.title,
              style: TextStyle(
                color: MatteSurface.ink(context),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            if (request.description != null) ...[
              const SizedBox(height: 8),
              Text(
                request.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withAlpha(180), height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              request.priceLabel,
              style: TextStyle(color: _accent, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPass,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('SKIP'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onInterested,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('INTERESTED'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
