import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/direct_requests/presentation/widgets/send_direct_request_sheet.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_insights_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_report_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_share_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final listingByIdProvider = FutureProvider.family<Listing?, String>((ref, id) {
  return ref.read(listingRepositoryProvider).fetchById(id);
});

/// Consent-first listing detail.
///
/// Free path: Interested -> owner matches back -> chat opens free.
/// Priority path: Direct Request -> one token held -> consumed only on accept.
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, this.listingData, this.listingId});

  final Listing? listingData;
  final String? listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listingData != null) return _ListingDetailBody(listing: listingData!);
    final id = listingId;
    if (id == null) {
      return Scaffold(
        backgroundColor: AppTheme.dashBg,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CapBackButton(
                onTap: () => Navigator.of(context).canPop()
                    ? Navigator.pop(context)
                    : context.go(AppPaths.clientDashboard),
              ),
            ),
          ),
        ),
      );
    }
    final async = ref.watch(listingByIdProvider(id));
    return async.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.dashBg,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppTheme.dashBg,
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(listingByIdProvider(id)),
            child: const Text('Could not load — retry'),
          ),
        ),
      ),
      data: (listing) => listing == null
          ? const Scaffold(
              backgroundColor: AppTheme.dashBg,
              body: Center(child: Text('Listing not found', style: TextStyle(color: Colors.white))),
            )
          : _ListingDetailBody(listing: listing),
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
  final _swipes = SwipeRepository();
  late final PageController _pages;
  int _imageIndex = 0;
  bool _busy = false;
  bool _matched = false;
  bool _interested = false;

  Listing get listing => widget.listing;
  bool get _isMine => Supabase.instance.client.auth.currentUser?.id == listing.ownerId;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _refreshMatch();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _refreshMatch() async {
    try {
      final matched = await _swipes.checkForMatch(listing.id);
      if (mounted) setState(() => _matched = matched);
    } catch (_) {}
  }

  void _back() {
    AppHaptics.light();
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      context.go(AppPaths.clientDashboard);
    }
  }

  Future<void> _showInterest() async {
    if (_busy || _isMine) return;
    setState(() => _busy = true);
    try {
      await _swipes.likeListing(listing.id);
      if (!mounted) return;
      await AppHaptics.success();
      setState(() => _interested = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interested sent — if they match you back, chat opens free.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send interest. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFreeChat() async {
    final ownerId = listing.ownerId;
    if (ownerId == null || ownerId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final conversationId = await _swipes.startConversation(
        ownerId: ownerId,
        listingId: listing.id,
      );
      if (!mounted || conversationId == null) return;
      await showChatPopup(
        context,
        conversation: ChatConversation(
          id: conversationId,
          otherUserId: ownerId,
          name: listing.title ?? 'Member',
          lastMessage: '',
          timestamp: 'now',
          listingTag: listing.title,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _matched = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This match is not active yet. You can send a Direct Request instead.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _directRequest() async {
    final ownerId = listing.ownerId;
    if (_busy || ownerId == null || ownerId.isEmpty || _isMine) return;
    AppHaptics.medium();
    await showSendDirectRequestSheet(
      context,
      receiverId: ownerId,
      listingId: listing.id,
      listingTitle: listing.title,
    );
  }

  Future<void> _connect() async {
    if (_isMine) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is your listing.')));
      return;
    }
    await _refreshMatch();
    if (!mounted) return;
    if (_matched) {
      await _openFreeChat();
    } else {
      await _directRequest();
    }
  }

  void _share() {
    AppHaptics.light();
    showListingShareSheet(context, listing: listing);
  }

  void _report() {
    AppHaptics.light();
    showListingReportSheet(context, listing: listing);
  }

  void _insights() {
    AppHaptics.light();
    showListingInsightsSheet(
      context,
      listing: listing,
      onMessage: _connect,
      onShare: _share,
      onReport: _report,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: Stack(
        children: [
          CustomScrollView(
            key: const Key('listing-detail-scroll'),
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _gallery()),
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 150 + bottom),
                  decoration: const BoxDecoration(
                    color: AppTheme.dashBg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (listing.title ?? 'Listing').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(listing.formattedPrice, style: GoogleFonts.plusJakartaSans(color: AppTheme.brandPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFFEB4898), size: 16),
                        const SizedBox(width: 5),
                        Expanded(child: Text(listing.formattedLocation, style: const TextStyle(color: Colors.white70))),
                      ]),
                      if (listing.quickTags.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        Wrap(spacing: 8, runSpacing: 8, children: [for (final tag in listing.quickTags) _Pill(tag)]),
                      ],
                      const SizedBox(height: 26),
                      const _Kicker('HOW CONNECTIONS WORK'),
                      const SizedBox(height: 10),
                      _Rule(icon: Icons.favorite_rounded, title: 'Interested — free', body: 'Let the owner know you like this. If they match back, chat opens for free.'),
                      _Rule(icon: Icons.handshake_rounded, title: 'Match — free chat', body: 'Both sides choose the connection. No token is charged.'),
                      _Rule(icon: Icons.bolt_rounded, title: 'Direct Request — priority', body: 'Skip the wait. One token is held and only spent if they accept.'),
                      const SizedBox(height: 24),
                      if (listing.description?.trim().isNotEmpty == true) ...[
                        const _Kicker('ABOUT THIS LISTING'),
                        const SizedBox(height: 8),
                        Text(listing.description!, style: GoogleFonts.plusJakartaSans(color: Colors.white70, height: 1.5, fontSize: 14)),
                        const SizedBox(height: 24),
                      ],
                      if (listing.amenities.isNotEmpty) ...[
                        const _Kicker('AMENITIES'),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [for (final item in listing.amenities) _Pill(item)]),
                        const SizedBox(height: 24),
                      ],
                      const _Kicker('SAFETY & CONSENT'),
                      const SizedBox(height: 8),
                      Text(
                        'A Direct Request buys priority, never access to a person. The receiver can accept, decline, block or report. Declined or expired requests do not spend the token.',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white60, height: 1.5, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            key: const Key('listing-detail-header'),
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Row(children: [
              CapBackButton(key: const ValueKey('listing-back'), onTap: _back),
              const Spacer(),
              _CircleButton(icon: Icons.share_rounded, onTap: _share),
              const SizedBox(width: 8),
              _CircleButton(icon: Icons.info_outline_rounded, onTap: _insights),
              const SizedBox(width: 8),
              _CircleButton(icon: Icons.flag_outlined, onTap: _report),
            ]),
          ),
          Positioned(
            key: const Key('listing-detail-nav'),
            left: 16,
            right: 16,
            bottom: bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(205),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: _isMine
                  ? const SizedBox(height: 48, child: Center(child: Text('YOUR LISTING', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800))))
                  : Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _showInterest,
                          icon: Icon(_interested ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                          label: Text(_interested ? 'INTEREST SENT' : 'INTERESTED'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: _interested ? AppTheme.brandPrimary : Colors.white38), shape: const StadiumBorder(), minimumSize: const Size(0, 48)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _connect,
                          icon: Icon(_matched ? Icons.chat_bubble_rounded : Icons.bolt_rounded),
                          label: Text(_matched ? 'CHAT FREE' : 'DIRECT REQUEST'),
                          style: ElevatedButton.styleFrom(backgroundColor: _matched ? AppTheme.brandPrimary : const Color(0xFFF59E0B), foregroundColor: Colors.black, shape: const StadiumBorder(), minimumSize: const Size(0, 48)),
                        ),
                      ),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery() {
    final images = listing.images;
    final height = MediaQuery.sizeOf(context).height * .53;
    if (images.isEmpty) {
      return SizedBox(
        height: height,
        child: const ColoredBox(
          color: Color(0xFF16161C),
          child: Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 64)),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Stack(children: [
        PageView.builder(
          controller: _pages,
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _imageIndex = i),
          itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF16161C), child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24)))),
        ),
        const Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000), Color(0xBB000000)]))))),
        if (images.length > 1)
          Positioned(
            right: 18,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
              child: Text('${_imageIndex + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.8));
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: Icon(icon, color: AppTheme.brandPrimary, size: 18)),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(body, style: const TextStyle(color: Colors.white60, height: 1.35, fontSize: 12.5)),
      ])),
    ]),
  );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: Colors.black.withAlpha(165), shape: BoxShape.circle, border: Border.all(color: Colors.white38)),
      child: Icon(icon, color: Colors.white, size: 19),
    ),
  );
}

/// Kept for callers that still import launch helpers via this file.
Future<void> launchListingExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
