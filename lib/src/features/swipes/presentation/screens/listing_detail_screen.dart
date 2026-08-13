import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_insights_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_report_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_share_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final listingByIdProvider = FutureProvider.family<Listing?, String>((ref, id) {
  return ref.read(listingRepositoryProvider).fetchById(id);
});

/// Capacitor ListingDetailPage — full card + Insights / Share / Report / Message.
class ListingDetailScreen extends ConsumerWidget {
  final Listing? listingData;
  final String? listingId;

  const ListingDetailScreen({
    super.key,
    this.listingData,
    this.listingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listingData != null) {
      return _ListingDetailBody(listing: listingData!);
    }
    final id = listingId;
    if (id == null) {
      return const Scaffold(
        body: Center(
          child: Text('Listing not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final async = ref.watch(listingByIdProvider(id));
    return async.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(listingByIdProvider(id)),
            child: Text('Could not load — retry ($e)'),
          ),
        ),
      ),
      data: (listing) {
        if (listing == null) {
          return const Scaffold(
            body: Center(
              child: Text('Listing not found',
                  style: TextStyle(color: Colors.white)),
            ),
          );
        }
        return _ListingDetailBody(listing: listing);
      },
    );
  }
}

class _ListingDetailBody extends StatefulWidget {
  const _ListingDetailBody({required this.listing});
  final Listing listing;

  @override
  State<_ListingDetailBody> createState() => _ListingDetailBodyState();
}

class _ListingDetailBodyState extends State<_ListingDetailBody> {
  late final PageController _pages;
  int _index = 0;
  bool _messaging = false;

  Listing get listing => widget.listing;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<String> get _images =>
      listing.images.isNotEmpty ? listing.images : [''];

  Future<void> _message() async {
    final ownerId = listing.ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner unavailable for messaging')),
      );
      return;
    }
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me != null && me == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your listing')),
      );
      return;
    }
    setState(() => _messaging = true);
    HapticFeedback.mediumImpact();
    try {
      final convoId = await SwipeRepository().startConversation(
        ownerId: ownerId,
        listingId: listing.id,
      );
      if (!mounted || convoId == null) return;
      await showChatPopup(
        context,
        isNewConversation: true,
        conversation: ChatConversation(
          id: convoId,
          otherUserId: ownerId,
          name: listing.title ?? 'Owner',
          lastMessage: '',
          timestamp: 'now',
          listingTag: listing.title,
        ),
      );
    } finally {
      if (mounted) setState(() => _messaging = false);
    }
  }

  void _openInsights() {
    HapticFeedback.lightImpact();
    showListingInsightsSheet(
      context,
      listing: listing,
      onMessage: _message,
      onShare: _openShare,
      onReport: _openReport,
    );
  }

  void _openShare() {
    HapticFeedback.lightImpact();
    showListingShareSheet(context, listing: listing);
  }

  void _openReport() {
    HapticFeedback.lightImpact();
    showListingReportSheet(context, listing: listing);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Gallery
          PageView.builder(
            controller: _pages,
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final url = _images[i];
              if (url.isEmpty) {
                return const ColoredBox(
                  color: Color(0xFF16161C),
                  child: Center(
                    child: Icon(Icons.home_work_rounded,
                        color: Colors.white24, size: 64),
                  ),
                );
              }
              return GestureDetector(
                onTap: _openInsights,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFF16161C),
                    child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white24, size: 48),
                    ),
                  ),
                ),
              );
            },
          ),

          // Gradients
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xE6000000),
                  ],
                  stops: [0, 0.25, 0.55, 1],
                ),
              ),
            ),
          ),

          // Top chrome
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _CircleBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (_images.length > 1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${_index + 1}/${_images.length}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                _CircleBtn(
                  icon: Icons.flag_outlined,
                  onTap: _openReport,
                ),
                const SizedBox(width: 8),
                _CircleBtn(
                  icon: Icons.info_outline_rounded,
                  onTap: _openInsights,
                ),
              ],
            ),
          ),

          // Price badge
          Positioned(
            top: top + 72,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white30),
              ),
              child: Text(
                listing.formattedPrice,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // Bottom info + actions
          Positioned(
            left: 20,
            right: 20,
            bottom: bottom + 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_images.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _images.length.clamp(0, 8); i++)
                          Container(
                            width: i == _index ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white.withAlpha(80),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onTap: _openInsights,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (listing.title ?? 'Listing').toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          fontSize: 28,
                          height: 1.05,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Color(0xFFEB4898), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              listing.formattedLocation,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'DETAILS',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.brandPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                      if (listing.quickTags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in listing.quickTags.take(4))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  tag,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _messaging ? null : _message,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4D00).withAlpha(120),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _messaging
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    listing.category == 'worker'
                                        ? 'HIRE / MESSAGE'
                                        : 'MESSAGE',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CircleBtn(
                      icon: Icons.share_rounded,
                      size: 56,
                      onTap: _openShare,
                    ),
                    const SizedBox(width: 10),
                    _CircleBtn(
                      icon: Icons.auto_awesome_rounded,
                      size: 56,
                      onTap: _openInsights,
                    ),
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

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.size = 48,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(150),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: size > 50 ? 22 : 18),
      ),
    );
  }
}

/// Kept for callers that still import launch helpers via this file.
Future<void> launchListingExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
