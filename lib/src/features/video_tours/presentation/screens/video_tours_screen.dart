import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:flutter_swipes/src/features/video_tours/presentation/providers/video_tours_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

/// Cap VideoTours — vertical immersive feed with share / like / mute / details.
class VideoToursScreen extends ConsumerStatefulWidget {
  const VideoToursScreen({super.key});

  @override
  ConsumerState<VideoToursScreen> createState() => _VideoToursScreenState();
}

class _VideoToursScreenState extends ConsumerState<VideoToursScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(videoToursProvider);

    return Scaffold(
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(videoToursProvider),
            child: const Text('Could not load video tours — retry'),
          ),
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.videocam_off_outlined,
                    size: 56,
                    color: Colors.transparent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NO TOURS AVAILABLE',
                    style: AppTheme.displayItalic.copyWith(fontSize: 22),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 8,
                    ),
                    child: Text(
                      'Property video tours appear here as owners upload walkthroughs.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            );
          }

          return PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            onPageChanged: (index) {
              AppHaptics.selection();
              setState(() => _index = index);
            },
            itemCount: listings.length,
            itemBuilder: (context, index) {
              return _TourPage(
                listing: listings[index],
                active: index == _index,
                shouldLoadVideo: (index - _index).abs() <= 1,
              );
            },
          );
        },
      ),
    );
  }
}

class _TourPage extends StatefulWidget {
  const _TourPage({
    required this.listing,
    required this.active,
    required this.shouldLoadVideo,
  });

  final Listing listing;
  final bool active;
  final bool shouldLoadVideo;

  @override
  State<_TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<_TourPage> {
  VideoPlayerController? _player;
  bool _muted = true;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    if (widget.shouldLoadVideo) {
      unawaited(_bindVideo());
    }
  }

  @override
  void didUpdateWidget(covariant _TourPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shouldLoadVideo && _player == null) {
      unawaited(_bindVideo());
    } else if (!widget.shouldLoadVideo && _player != null) {
      unawaited(_player?.dispose());
      _player = null;
    }

    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    if (widget.active) {
      unawaited(player.play());
    } else {
      unawaited(player.pause());
    }
  }

  Future<void> _bindVideo() async {
    final url = widget.listing.videoUrl?.trim();
    if (url == null || url.isEmpty) return;

    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = next;
    try {
      await next.initialize();
      await next.setLooping(true);
      await next.setVolume(_muted ? 0 : 1);
      if (widget.active) await next.play();
      if (mounted && identical(_player, next)) setState(() {});
    } catch (_) {
      try {
        await next.dispose();
      } catch (_) {}
      if (identical(_player, next)) _player = null;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    await AppShare.listing(
      id: widget.listing.id,
      title: widget.listing.title,
    );
  }

  Future<void> _like() async {
    AppHaptics.medium();
    setState(() => _liked = true);
    try {
      await SwipeRepository().likeListing(widget.listing.id);
    } catch (_) {}
  }

  int _posterCacheWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 2).round().clamp(640, 1800);

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final ready = _player != null && _player!.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          RepaintBoundary(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _player!.value.size.width,
                height: _player!.value.size.height,
                child: VideoPlayer(_player!),
              ),
            ),
          )
        else if (listing.primaryImage != null)
          Image.network(
            listing.primaryImage!,
            fit: BoxFit.cover,
            cacheWidth: _posterCacheWidth(context),
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF16161C)),
          )
        else
          const ColoredBox(color: Color(0xFF16161C)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x99000000),
                Colors.transparent,
                Color(0xE6000000),
              ],
              stops: [0, 0.4, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'IMMERSIVE',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.4,
                            ),
                          ),
                          Text(
                            'VIDEO TOURS',
                            style: AppTheme.displayItalic.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _share,
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.formattedPrice,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                            ),
                          ),
                          Text(
                            listing.title ?? 'Listing',
                            style: AppTheme.displayItalic.copyWith(
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            listing.formattedLocation,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ListingDetailScreen(
                                      listingData: listing,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text(
                                'OPEN LISTING',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        _SideAction(
                          icon: _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: _liked ? 'Liked' : 'Like',
                          color: _liked
                              ? const Color(0xFFFC567E)
                              : Colors.white,
                          onTap: _liked ? null : _like,
                        ),
                        const SizedBox(height: 14),
                        _SideAction(
                          icon: _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          label: _muted ? 'Muted' : 'Live',
                          onTap: _player == null
                              ? null
                              : () async {
                                  setState(() => _muted = !_muted);
                                  await _player!.setVolume(_muted ? 0 : 1);
                                },
                        ),
                        const SizedBox(height: 14),
                        _SideAction(
                          icon: Icons.info_outline_rounded,
                          label: 'Details',
                          color: AppTheme.brandPrimary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ListingDetailScreen(listingData: listing),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(120),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
