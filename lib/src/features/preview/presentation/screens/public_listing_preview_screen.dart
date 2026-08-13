import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

/// Cap PublicListingPreview — guest-friendly listing deep link.
class PublicListingPreviewScreen extends ConsumerWidget {
  const PublicListingPreviewScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(listingByIdProvider(listingId));

    return Scaffold(
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text('Could not load listing\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
        ),
        data: (listing) {
          if (listing == null) {
            return const Center(
              child: Text('Listing not found',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          final image = listing.primaryImage;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                leading: IconButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/welcome');
                    }
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
                actions: [
                  IconButton(
                    onPressed: () async {
                      final url =
                          'https://www.swipess.com/listing/${listing.id}';
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.share_rounded),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: image == null
                      ? const ColoredBox(color: Color(0xFF16161C))
                      : Image.network(image, fit: BoxFit.cover),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (listing.title ?? 'Listing').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          fontSize: 28,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        listing.formattedPrice,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        listing.formattedLocation,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        listing.description?.trim().isNotEmpty == true
                            ? listing.description!
                            : 'Discover this listing on Swipess.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: () => context.go('/welcome'),
                          style: FilledButton.styleFrom(
                          ),
                          child: Text(
                            'JOIN SWIPESS TO MESSAGE',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
