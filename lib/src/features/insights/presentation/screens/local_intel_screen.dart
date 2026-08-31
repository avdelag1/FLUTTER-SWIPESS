import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/insights/domain/local_intel_post.dart';
import 'package:flutter_swipes/src/features/insights/presentation/providers/insights_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class LocalIntelScreen extends ConsumerStatefulWidget {
  const LocalIntelScreen({super.key});

  @override
  ConsumerState<LocalIntelScreen> createState() => _LocalIntelScreenState();
}

class _LocalIntelScreenState extends ConsumerState<LocalIntelScreen> {
  String _category = 'all';

  static const _categories = {
    'all': 'Latest',
    'dining': 'Food',
    'coworking': 'Work',
    'events': 'Social',
    'safety': 'Safety',
    'infrastructure': 'Useful',
    'general': 'More',
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(localIntelProvider);

    return NeoNaiveScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const CapBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCAL INTEL',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          'Live local picks from the Swipess Local Brain',
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final entry in _categories.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: NeoNaiveChip(
                        label: entry.value,
                        selected: _category == entry.key,
                        onSelected: () => setState(() => _category = entry.key),
                        selectedColor: AppTheme.brandPrimary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: MatteSurface.ink(context),
                    strokeWidth: 2,
                  ),
                ),
                error: (_, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Local Intel could not load.',
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.ink(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(localIntelProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (posts) {
                  final filtered = _category == 'all'
                      ? posts
                      : posts.where((p) => p.category == _category).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No local entries in this category yet.',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppTheme.brandPrimary,
                    onRefresh: () async {
                      ref.invalidate(localIntelProvider);
                      await ref.read(localIntelProvider.future);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _IntelCard(post: filtered[index]),
                    ),
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

class _IntelCard extends StatelessWidget {
  const _IntelCard({required this.post});
  final LocalIntelPost post;

  @override
  Widget build(BuildContext context) {
    final when = post.publishedAt == null
        ? null
        : DateFormat.MMMd().format(post.publishedAt!.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categoryLabel(post.category),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.title,
                  style: TextStyle(
                    color: MatteSurface.ink(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (post.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.content,
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.muted(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if ((post.neighborhood ?? '').trim().isNotEmpty)
                      Expanded(
                        child: Text(
                          post.neighborhood!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 11,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (when != null)
                      Text(
                        when,
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.faint(context),
                          fontSize: 11,
                        ),
                      ),
                    if ((post.sourceUrl ?? '').trim().isNotEmpty) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Open source',
                        onPressed: () async {
                          final uri = Uri.tryParse(post.sourceUrl!);
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: Icon(
                          Icons.open_in_new_rounded,
                          color: MatteSurface.muted(context),
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'dining':
        return 'FOOD & DRINK';
      case 'coworking':
        return 'WORK';
      case 'events':
        return 'SOCIAL';
      case 'safety':
        return 'SAFETY';
      case 'infrastructure':
        return 'USEFUL LOCAL';
      default:
        return 'LOCAL';
    }
  }
}
