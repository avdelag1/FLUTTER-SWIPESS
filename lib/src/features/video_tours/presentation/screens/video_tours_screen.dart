import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:flutter_swipes/src/features/video_tours/presentation/providers/video_tours_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class VideoToursScreen extends ConsumerWidget {
  const VideoToursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(videoToursProvider);

    return Scaffold(
      backgroundColor: Colors.black,
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.videocam_off_outlined, size: 56, color: Colors.white.withAlpha(70)),
                  const SizedBox(height: 12),
                  Text(
                    'NO TOURS AVAILABLE',
                    style: AppTheme.displayItalic.copyWith(fontSize: 22),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                    child: Text(
                      'Property video tours appear here as owners upload walkthroughs.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            );
          }

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: listings.length,
            itemBuilder: (context, index) {
              return _TourPage(listing: listings[index]);
            },
          );
        },
      ),
    );
  }
}

class _TourPage extends StatefulWidget {
  const _TourPage({required this.listing});
  final Listing listing;

  @override
  State<_TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<_TourPage> {
  VideoPlayerController? _player;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    final url = widget.listing.videoUrl;
    if (url != null && url.trim().isNotEmpty) {
      final player = VideoPlayerController.networkUrl(Uri.parse(url));
      _player = player;
      player.initialize().then((_) async {
        await player.setLooping(true);
        await player.setVolume(0);
        await player.play();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final ready = _player != null && _player!.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _player!.value.size.width,
              height: _player!.value.size.height,
              child: VideoPlayer(_player!),
            ),
          )
        else if (listing.primaryImage != null)
          Image.network(listing.primaryImage!, fit: BoxFit.cover)
        else
          const ColoredBox(color: Color(0xFF16161C)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Colors.transparent, Color(0xCC000000)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    const Spacer(),
                    if (_player != null)
                      IconButton(
                        onPressed: () async {
                          setState(() => _muted = !_muted);
                          await _player!.setVolume(_muted ? 0 : 1);
                        },
                        icon: Icon(
                          _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
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
                  style: AppTheme.displayItalic.copyWith(fontSize: 22),
                ),
                Text(
                  listing.formattedLocation,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(listingData: listing),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'OPEN LISTING',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
