import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _BackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LOCAL INTEL', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                        Text(
                          'Verified neighborhood updates',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
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
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _category == entry.key,
                        onSelected: (_) => setState(() => _category = entry.key),
                        selectedColor: AppTheme.brandPrimary,
                        backgroundColor: Colors.transparent,
                        labelStyle: TextStyle(
                          color: _category == entry.key ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                        side: BorderSide(color: Colors.transparent),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(localIntelProvider),
                    child: const Text('Could not load intel — retry'),
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
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _IntelCard(post: filtered[index]),
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
        border: Border.all(color: Colors.transparent),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(post.imageUrl!, fit: BoxFit.cover),
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
                const SizedBox(height: 6),
                Text(
                  post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (post.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.content,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (post.neighborhood != null)
                      Text(
                        post.neighborhood!,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
                      ),
                    const Spacer(),
                    if (when != null)
                      Text(
                        when,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11),
                      ),
                    if (post.sourceUrl != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final uri = Uri.tryParse(post.sourceUrl!);
                          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white54, size: 18),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
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
          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
