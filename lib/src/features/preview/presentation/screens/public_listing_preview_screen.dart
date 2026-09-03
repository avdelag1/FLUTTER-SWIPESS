import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/cap_empty_state.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_controls.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

/// Guest-friendly listing deep link.
///
/// Signed-in users are handed straight to the real listing route so a shared
/// link behaves like an in-app deep link. Signed-out visitors keep this public
/// preview instead of being forced into a store or login screen.
class PublicListingPreviewScreen extends ConsumerWidget {
  const PublicListingPreviewScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/listing/$listingId');
      });
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CapLoadingState(label: 'Opening listing', compact: true),
      );
    }

    final async = ref.watch(listingByIdProvider(listingId));

    return Scaffold(
      body: async.when(
        loading: () => const CapLoadingState(label: 'Loading listing'),
        error: (_, _) => CapErrorState(
          title: 'Could not load listing',
          description: 'We couldn’t load this shared listing right now.',
          onRetry: () => ref.invalidate(listingByIdProvider(listingId)),
        ),
        data: (listing) {
          if (listing == null) {
            return const CapEmptyState(
              title: 'Listing not found',
              description: 'This listing may have been removed or is no longer available.',
              icon: Icons.home_work_outlined,
            );
          }
          final image = listing.primaryImage;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                leading: IconButton(
                  onPressed: () =>
                      NavBack.popOrGo(context, fallbackPath: '/welcome'),
                  icon: Icon(Icons.close_rounded),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Share listing',
                    onPressed: () =>
                        AppShare.listing(id: listing.id, title: listing.title),
                    icon: Icon(Icons.ios_share_rounded),
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
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (listing.title ?? 'Listing').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.ink(context),
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          fontSize: 28,
                          letterSpacing: -0.8,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        listing.formattedPrice,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        listing.formattedLocation,
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        listing.description?.trim().isNotEmpty == true
                            ? listing.description!
                            : 'Discover this listing on Swipess.',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 28),
                      SwipessButton(
                        label: 'Join Swipess to message',
                        // Going to the protected destination intentionally
                        // lets AppRedirect remember it. After sign-in the
                        // user resumes this exact listing, not the dashboard.
                        onPressed: () => context.go('/listing/${listing.id}'),
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
