import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_empty_state.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_request.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_worker_categories.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/providers/seekers_provider.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/widgets/seeker_request_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Browse open seeker requests — theme-aware feed, not a dark leftover deck.
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
    final top = MediaQuery.paddingOf(context).top;
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
              'Could not load seekers — retry',
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
            // The app shell owns a shared back button directly below the
            // header. Reserve a full row for it so it can never cover SEEKERS.
            padding: EdgeInsets.fromLTRB(20, top + 64, 20, 140),
            children: [
              Text(
                'SEEKERS',
                style: AppTheme.displayItalic.copyWith(
                  fontSize: 32,
                  height: 1.05,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'People looking for workers & help nearby',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  AppHaptics.medium();
                  showSeekerRequestSheet(context, ref);
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D00).withAlpha(70),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Post a request',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CatChip(
                      label: 'All',
                      color: const Color(0xFFE4007C),
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final id in cats)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
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
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                CapEmptyState(
                  title: 'No open requests',
                  description: _category == null
                      ? 'Nobody is asking for help nearby yet. Post a request so workers can find you.'
                      : 'No ${_labelFor(_category!).toLowerCase()} requests right now.',
                  icon: Icons.groups_rounded,
                  actionLabel: 'Post a request',
                  onAction: () => showSeekerRequestSheet(context, ref),
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
                  const SizedBox(height: 12),
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : MatteSurface.hairline(context),
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : ink,
            fontWeight: FontWeight.w800,
            fontSize: 12,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: accent.withAlpha(40),
                backgroundImage: request.seekerAvatar != null
                    ? NetworkImage(request.seekerAvatar!)
                    : null,
                child: request.seekerAvatar == null
                    ? Text(
                        request.initials,
                        style: GoogleFonts.plusJakartaSans(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.seekerName,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.location,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withAlpha(32),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            request.title,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          if (request.description != null &&
              request.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              request.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            request.priceLabel,
            style: GoogleFonts.plusJakartaSans(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPass,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    side: BorderSide(color: MatteSurface.hairline(context)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('SKIP'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        Color.lerp(accent, const Color(0xFFEB4898), 0.55) ??
                            accent,
                      ],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: onInterested,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('INTERESTED'),
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
