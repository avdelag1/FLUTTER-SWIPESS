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
import 'package:cached_network_image/cached_network_image.dart';

class LocalIntelScreen extends ConsumerStatefulWidget {
  const LocalIntelScreen({super.key});

  @override
  ConsumerState<LocalIntelScreen> createState() => _LocalIntelScreenState();
}

class _LocalIntelScreenState extends ConsumerState<LocalIntelScreen> {
  String _category = 'all';

  static const _categories = {
    'all': 'Latest',
    'infrastructure': 'Urban',
    'events': 'Social',
    'coworking': 'Work',
    'dining': 'Gastro',
    'safety': 'Safety',
    'general': 'General',
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
                  CapBackButton(onTap: () => Navigator.of(context).pop()),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCAL INTEL',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          'Verified neighborhood updates',
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 11,
                            letterSpacing: 0.6,
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
            SizedBox(height: 8),
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
                    onPressed: () => ref.invalidate(localIntelProvider),
                    child: Text('Could not load intel — retry'),
                  ),
                ),
                data: (posts) {
                  final filtered = _category == 'all'
                      ? posts
                      : posts.where((p) => p.category == _category).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No intel posts yet.',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _IntelCard(post: filtered[index]),
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
        : DateFormat.MMMd().add_jm().format(post.publishedAt!.toLocal());

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
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
  imageUrl: post.imageUrl!, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.category.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  post.title,
                  style: TextStyle(
                    color: MatteSurface.ink(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (post.content.isNotEmpty) ...[
                  SizedBox(height: 8),
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
                SizedBox(height: 10),
                Row(
                  children: [
                    if (post.neighborhood != null)
                      Text(
                        post.neighborhood!,
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                          fontSize: 11,
                        ),
                      ),
                    Spacer(),
                    if (when != null)
                      Text(
                        when,
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.faint(context),
                          fontSize: 11,
                        ),
                      ),
                    if (post.sourceUrl != null) ...[
                      SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
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
}
