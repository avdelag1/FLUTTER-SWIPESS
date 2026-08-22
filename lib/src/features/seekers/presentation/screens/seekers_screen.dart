import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_empty_state.dart';
import 'package:flutter_swipes/src/features/needs/presentation/widgets/need_composer_sheet.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_request.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_worker_categories.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/providers/seekers_provider.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
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
            padding: EdgeInsets.fromLTRB(20, top + 50, 20, 130),
            children: [
              Text(
                'I NEED',
                style: AppTheme.displayItalic.copyWith(
                  fontSize: 27,
                  height: 1,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Real people asking for something nearby — respond with interest, not spam.',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 13),
              GestureDetector(
                onTap: () {
                  AppHaptics.medium();
                  showNeedComposerSheet(context);
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: AppTheme.brandPrimary,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 19),
                      const SizedBox(width: 7),
                      Text(
                        'POST WHAT YOU NEED',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CatChip(
                      label: 'All',
                      color: AppTheme.brandPrimary,
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final id in cats)
                      Padding(
                        padding: const EdgeInsets.only(left: 7),
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
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                CapEmptyState(
                  title: 'No open requests',
                  description: _category == null
                      ? 'Nobody is asking for something nearby yet. Post what you need and let Swipess find the supply.'
                      : 'No ${_labelFor(_category!).toLowerCase()} requests right now.',
                  icon: Icons.bolt_rounded,
                  actionLabel: 'Post I Need',
                  onAction: () => showNeedComposerSheet(context),
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
                  const SizedBox(height: 10),
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
    if (id.isEmpty) return 'Other';
    return id[0].toUpperCase() + id.substring(1);
  }

  /// Responding to demand is free interest. The requester must accept that
  /// interest before chat opens; Premium/tokens never bypass that consent.
  Future<void> _interested(SeekerRequest req) async {
    AppHaptics.medium();
    try {
      await SwipeRepository().likeListing(req.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❤️ Interest sent. If they choose you too, chat opens free.',
          ),
        ),
      );
      ref.read(seekersProvider.notifier).dismiss(req.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send interest. Try again.')),
      );
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : MatteSurface.hairline(context),
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
    var label = request.category;
    for (final c in seekerWorkerCategories) {
      if (c.id == request.category) label = c.label;
    }
    return Container(
      padding: const EdgeInsets.all(14),
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
              CircleAvatar(
                radius: 22,
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
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
          const SizedBox(height: 11),
          Text(
            request.title,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (request.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 5),
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
          const SizedBox(height: 8),
          Text(
            request.priceLabel,
            style: GoogleFonts.plusJakartaSans(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPass,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: ink,
                    side: BorderSide(color: MatteSurface.hairline(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('SKIP'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onInterested,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.favorite_rounded, size: 16),
                  label: const Text('INTERESTED'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
