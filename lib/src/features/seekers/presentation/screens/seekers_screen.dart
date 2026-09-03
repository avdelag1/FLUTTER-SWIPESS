import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_request.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_worker_categories.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/providers/seekers_provider.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/widgets/seeker_request_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SeekersScreen extends ConsumerStatefulWidget {
  const SeekersScreen({super.key});
  @override
  ConsumerState<SeekersScreen> createState() => _SeekersScreenState();
}

class _SeekersScreenState extends ConsumerState<SeekersScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(seekersProvider);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return NeoNaiveScaffold(
      body: async.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: ink, strokeWidth: 2),
        ),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.read(seekersProvider.notifier).refresh(),
            child: Text(
              'Could not load requests — retry',
              style: GoogleFonts.plusJakartaSans(color: ink),
            ),
          ),
        ),
        data: (requests) {
          final cats = <String>{for (final r in requests) r.category}
            ..removeWhere((id) => id.isEmpty);
          final filtered = _category == null
              ? requests
              : requests.where((r) => r.category == _category).toList();
          return ListView(
            // DashboardShell already reserves the real top bar/back row/dock.
            // Do not add a second giant frame of dead space inside the page.
            padding: EdgeInsets.fromLTRB(20, 10, 20, 36),
            children: [
              Text(
                'REQUESTS',
                style: AppTheme.displayItalic.copyWith(
                  fontSize: 27,
                  height: 1,
                  color: ink,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Post and browse requests for workers, taskers and local help nearby',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 13),
              GestureDetector(
                onTap: () {
                  AppHaptics.medium();
                  showSeekerRequestSheet(context, ref);
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2D6F), Color(0xFF9B5CFF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D6F).withAlpha(48),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Post a request',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 13),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CatChip(
                      label: 'All',
                      color: const Color(0xFFE4007C),
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 7),
                      child: _CatChip(
                        label: 'Roommates',
                        color: const Color(0xFF7C3AED),
                        selected: false,
                        onTap: () => context.push(AppPaths.exploreRoommates),
                      ),
                    ),
                    for (final id in cats)
                      Padding(
                        padding: EdgeInsets.only(left: 7),
                        child: _CatChip(
                          label: _labelFor(id),
                          color: seekerCategoryColor(id),
                          selected: _category == id,
                          onTap: () => setState(
                            () => _category = _category == id ? null : id,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              if (filtered.isEmpty)
                _SeekersEmptyState(
                  description: _category == null
                      ? 'No open requests nearby yet. Post one so workers can find you, or open Roommates above.'
                      : 'No ${_labelFor(_category!).toLowerCase()} requests right now.',
                  onPost: () => showSeekerRequestSheet(context, ref),
                )
              else
                for (final req in filtered) ...[
                  _SeekerCard(
                    request: req,
                    onPass: () {
                      AppHaptics.light();
                      ref.read(seekersProvider.notifier).dismiss(req.id);
                    },
                    onInterested: () => _interested(req),
                  ),
                  SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }

  String _labelFor(String id) {
    for (final c in seekerWorkerCategories) {
      if (c.id == id) return c.label;
    }
    return id[0].toUpperCase() + id.substring(1);
  }

  Future<void> _interested(SeekerRequest req) async {
    AppHaptics.medium();
    final ownerId = req.ownerId;
    if (ownerId != null) {
      final convoId = await SwipeRepository().startConversation(
        ownerId: ownerId,
        listingId: req.id,
      );
      if (mounted && convoId != null) {
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
    ref.read(seekersProvider.notifier).dismiss(req.id);
  }
}

class _SeekersEmptyState extends StatelessWidget {
  const _SeekersEmptyState({required this.description, required this.onPost});

  final String description;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 46, 10, 24),
      child: Column(
        children: [
          Icon(Icons.groups_rounded, size: 44, color: const Color(0xFFFF2D6F).withAlpha(190)),
          SizedBox(height: 14),
          Text(
            'No open requests',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPost,
            icon: Icon(Icons.add_rounded),
            label: Text('Post a request'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D6F),
              foregroundColor: Colors.white,
              minimumSize: const Size(190, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : MatteSurface.hairline(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : ink,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final accent = seekerCategoryColor(request.category);
    final label = () {
      for (final c in seekerWorkerCategories) {
        if (c.id == request.category) return c.label;
      }
      return request.category;
    }();
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FunAvatar(
                seed: request.ownerId ?? request.seekerName,
                imageUrl: request.seekerAvatar,
                size: 44,
                semanticLabel: '${request.seekerName} profile avatar',
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.seekerName,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      request.location,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 11),
          Text(
            request.title,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (request.description != null &&
              request.description!.trim().isNotEmpty) ...[
            SizedBox(height: 5),
            Text(
              request.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                height: 1.35,
                fontSize: 12,
              ),
            ),
          ],
          SizedBox(height: 8),
          Text(
            request.priceLabel,
            style: GoogleFonts.plusJakartaSans(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPass,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: ink,
                    side: BorderSide(color: MatteSurface.hairline(context)),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('SKIP'),
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        Color.lerp(accent, const Color(0xFFEB4898), .55) ??
                            accent,
                      ],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: onInterested,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('INTERESTED'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
