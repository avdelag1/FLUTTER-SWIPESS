import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/chrome_summon_zones.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_insights_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_report_sheet.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/listing_share_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

final listingByIdProvider = FutureProvider.family<Listing?, String>((ref, id) {
  return ref.read(listingRepositoryProvider).fetchById(id);
});

/// Capacitor ListingDetailPage — long-form card: gallery + scroll body.
/// Header HUD and bottom action dock hide while scrolling down, return on up.
class ListingDetailScreen extends ConsumerWidget {
  final Listing? listingData;
  final String? listingId;

  const ListingDetailScreen({super.key, this.listingData, this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listingData != null) {
      return _ListingDetailBody(listing: listingData!);
    }
    final id = listingId;
    if (id == null) {
      return Scaffold(
        backgroundColor: AppTheme.dashBg,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CapBackButton(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  } else {
                    context.go(AppPaths.clientDashboard);
                  }
                },
              ),
            ),
          ),
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
              child: Text(
                'Listing not found',
                style: TextStyle(color: Colors.white),
              ),
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
  bool _chromeVisible = true;
  double _accum = 0;

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

  List<String> get _images => listing.images.isNotEmpty ? listing.images : [''];

  void _setChrome(bool visible) {
    if (_chromeVisible == visible) return;
    setState(() {
      _chromeVisible = visible;
      _accum = 0;
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final pixels = notification.metrics.pixels;
    final delta = notification.scrollDelta ?? 0;
    if (pixels <= 40) {
      _setChrome(true);
      return false;
    }
    if (delta.abs() < 0.5) return false;
    if ((delta > 0 && _accum < 0) || (delta < 0 && _accum > 0)) {
      _accum = 0;
    }
    _accum += delta;
    if (_accum > 28) {
      _setChrome(false);
    } else if (_accum < -28) {
      _setChrome(true);
    }
    return false;
  }

  void _back() {
    AppHaptics.light();
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      context.go(AppPaths.clientDashboard);
    }
  }

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('This is your listing')));
      return;
    }
    setState(() => _messaging = true);
    AppHaptics.medium();
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
    AppHaptics.light();
    showListingInsightsSheet(
      context,
      listing: listing,
      onMessage: _message,
      onShare: _openShare,
      onReport: _openReport,
    );
  }

  void _openShare() {
    AppHaptics.light();
    showListingShareSheet(context, listing: listing);
  }

  void _openReport() {
    AppHaptics.light();
    showListingReportSheet(context, listing: listing);
  }

  String get _story {
    final raw = listing.description?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final kind = listing.propertyType ?? listing.category ?? 'listing';
    final bits = <String>[
      'A $kind in ${listing.formattedLocation}.',
      if (listing.quickTags.isNotEmpty) listing.quickTags.join(' · '),
      'Listed at ${listing.formattedPrice}. Match on SWIPESS to message the host and lock it in.',
    ];
    return bits.join(' ');
  }

  List<(IconData, String, String)> get _specs {
    final cat = (listing.category ?? 'property').toLowerCase();
    final specs = <(IconData, String, String)>[
      (Icons.attach_money_rounded, 'Price', listing.formattedPrice),
      (Icons.category_rounded, 'Category', cat),
    ];
    if (listing.listingType != null) {
      specs.add((Icons.sell_rounded, 'Mode', listing.listingType!));
    }
    if (cat == 'property') {
      final beds = listing.beds ?? listing.bedrooms;
      final baths = listing.baths ?? listing.bathrooms;
      if (beds != null) specs.add((Icons.bed_rounded, 'Beds', '$beds'));
      if (baths != null) {
        specs.add((
          Icons.bathtub_rounded,
          'Baths',
          baths % 1 == 0 ? baths.toInt().toString() : baths.toString(),
        ));
      }
      if (listing.squareFootage != null) {
        specs.add((
          Icons.square_foot_rounded,
          'Size',
          '${listing.squareFootage!.toStringAsFixed(0)} ft²',
        ));
      }
      if (listing.propertyType != null) {
        specs.add((Icons.home_rounded, 'Type', listing.propertyType!));
      }
      if (listing.furnished == true) {
        specs.add((Icons.check_circle_rounded, 'Furnished', 'Yes'));
      }
      if (listing.petFriendly == true) {
        specs.add((Icons.pets_rounded, 'Pets', 'Friendly'));
      }
    } else if (cat == 'motorcycle' || cat == 'bicycle' || cat == 'yacht') {
      if (listing.vehicleBrand != null) {
        specs.add((Icons.two_wheeler_rounded, 'Brand', listing.vehicleBrand!));
      }
      if (listing.vehicleModel != null) {
        specs.add((
          Icons.precision_manufacturing_rounded,
          'Model',
          listing.vehicleModel!,
        ));
      }
      if (listing.year != null) {
        specs.add((Icons.calendar_today_rounded, 'Year', '${listing.year}'));
      }
      if (listing.mileage != null) {
        specs.add((Icons.speed_rounded, 'Mileage', '${listing.mileage} km'));
      }
    } else if (cat == 'worker') {
      if (listing.serviceCategory != null) {
        specs.add((Icons.work_rounded, 'Service', listing.serviceCategory!));
      }
      if (listing.experienceYears != null) {
        specs.add((
          Icons.timeline_rounded,
          'Experience',
          '${listing.experienceYears} yrs',
        ));
      }
    }
    return specs;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final heroH = MediaQuery.sizeOf(context).height * 0.58;
    final show = _chromeVisible;

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              key: const Key('listing-detail-scroll'),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: heroH,
                    child: _Gallery(
                      listingId: listing.id,
                      pages: _pages,
                      images: _images,
                      index: _index,
                      onChanged: (i) => setState(() => _index = i),
                      onTap: _openInsights,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -28),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.dashBg,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border(
                          top: BorderSide(color: Color(0x33FFFFFF)),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(20, 22, 20, 140 + bottom),
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
                              height: 1.05,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            listing.formattedPrice,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.brandPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFFEB4898),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  listing.formattedLocation,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (listing.quickTags.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final tag in listing.quickTags) _Pill(tag),
                              ],
                            ),
                          ],
                          const SizedBox(height: 22),
                          const _Kicker('SPECS'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final s in _specs)
                                _SpecTile(icon: s.$1, label: s.$2, value: s.$3),
                            ],
                          ),
                          const SizedBox(height: 26),
                          const _Kicker('ABOUT THIS LISTING'),
                          const SizedBox(height: 8),
                          Text(
                            _story,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                          if (listing.amenities.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            const _Kicker('AMENITIES'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final a in listing.amenities) _Pill(a),
                              ],
                            ),
                          ],
                          const SizedBox(height: 26),
                          const _Kicker('HIGHLIGHTS'),
                          const SizedBox(height: 10),
                          _Bullet(
                            icon: Icons.auto_awesome_rounded,
                            title: listing.hasVerifiedDocuments
                                ? 'Verified documents on file'
                                : 'SWIPESS match-ready',
                            body: listing.hasVerifiedDocuments
                                ? 'Host vault includes ID or lease docs reviewed in PEARL.'
                                : 'Like the card, match, then message — no public phone numbers.',
                          ),
                          _Bullet(
                            icon: Icons.nights_stay_rounded,
                            title: listing.furnished == true
                                ? 'Arrive furnished'
                                : 'Flexible stay',
                            body: listing.listingType == 'sale'
                                ? 'Listed for sale. Tour first, then close through SWIPESS escrow when you are ready.'
                                : 'Message the host for dates, guests, and house rules before you commit.',
                          ),
                          _Bullet(
                            icon: Icons.pets_rounded,
                            title: listing.petFriendly == true
                                ? 'Pets welcome'
                                : 'Ask about pets',
                            body: listing.petFriendly == true
                                ? 'The host marked this listing pet friendly.'
                                : 'Confirm animals, deposits, and quiet hours in chat before you travel.',
                          ),
                          const SizedBox(height: 18),
                          const _Kicker('NEIGHBORHOOD'),
                          const SizedBox(height: 8),
                          Text(
                            listing.neighborhood?.trim().isNotEmpty == true
                                ? '${listing.neighborhood} · ${listing.city ?? listing.formattedLocation}. Walk the area on the live map after you match, or drop a pin from Intel Core.'
                                : '${listing.formattedLocation}. Open the live map from the dashboard globe to fly the radius around this pin.',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 26),
                          const _Kicker('MATCH PROTOCOL'),
                          const SizedBox(height: 10),
                          const _Bullet(
                            icon: Icons.swipe_rounded,
                            title: '1 · Swipe the deck',
                            body: 'Keep cards you want. A mutual like opens the thread — no spam DMs.',
                          ),
                          const _Bullet(
                            icon: Icons.chat_bubble_rounded,
                            title: '2 · Message the host',
                            body: 'Ask for a tour, documents, or a hold. Share vault files in-chat.',
                          ),
                          const _Bullet(
                            icon: Icons.verified_user_outlined,
                            title: '3 · Close on SWIPESS',
                            body: 'PEARL ID, contracts, and escrow stay inside the app. Never wire off-platform.',
                          ),
                          const SizedBox(height: 26),
                          const _Kicker('SAFETY'),
                          const SizedBox(height: 8),
                          Text(
                            'Report anything off. Never send deposits outside SWIPESS. Hosts with a violet Verified pill have documents in the vault.',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _GhostBtn(
                                  label: 'SHARE',
                                  icon: Icons.share_rounded,
                                  onTap: _openShare,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _GhostBtn(
                                  label: 'REPORT',
                                  icon: Icons.flag_outlined,
                                  onTap: _openReport,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Header HUD — left inset so it cannot eat back taps.
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: KeyedSubtree(
              key: const Key('listing-detail-header'),
              child: _ChromeLayer(
                visible: show,
                fromTop: true,
                child: Row(
                  children: [
                    const SizedBox(width: 52),
                    const Spacer(),
                    if (_images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                    _CircleBtn(icon: Icons.flag_outlined, onTap: _openReport),
                    const SizedBox(width: 8),
                    _CircleBtn(
                      icon: Icons.info_outline_rounded,
                      onTap: _openInsights,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: top + 8,
            left: 16,
            child: CapBackButton(
              key: const ValueKey('listing-back'),
              onTap: _back,
            ),
          ),

          // Bottom action dock
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 16,
            child: KeyedSubtree(
              key: const Key('listing-detail-nav'),
              child: _ChromeLayer(
                visible: show,
                fromTop: false,
                child: Row(
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
              ),
            ),
          ),

          ChromeSummonZones(visible: show, onSummon: () => _setChrome(true)),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.listingId,
    required this.pages,
    required this.images,
    required this.index,
    required this.onChanged,
    required this.onTap,
  });
  final String listingId;

  final PageController pages;
  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: pages,
          itemCount: images.length,
          onPageChanged: onChanged,
          itemBuilder: (context, i) {
            final url = images[i];
            if (url.isEmpty) {
              return const ColoredBox(
                color: Color(0xFF16161C),
                child: Center(
                  child: Icon(
                    Icons.home_work_rounded,
                    color: Colors.white24,
                    size: 64,
                  ),
                ),
              );
            }
            return GestureDetector(
              onTap: onTap,
              child: Hero(
                tag: 'swipe_hero_${listingId}_$i',
                child: CachedNetworkImage(
  imageUrl: url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFF16161C),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white24,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x00000000),
                  Color(0xCC000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length.clamp(0, 8); i++)
                  Container(
                    width: i == index ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == index
                          ? Colors.white
                          : Colors.white.withAlpha(80),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChromeLayer extends StatelessWidget {
  const _ChromeLayer({
    required this.visible,
    required this.fromTop,
    required this.child,
  });

  final bool visible;
  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: Duration(milliseconds: visible ? 360 : 340),
      curve: const Cubic(0.25, 0.1, 0.25, 1),
      child: AnimatedSlide(
        offset: visible ? Offset.zero : Offset(0, fromTop ? -0.18 : 0.45),
        duration: Duration(milliseconds: visible ? 360 : 340),
        curve: const Cubic(0.25, 0.1, 0.25, 1),
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 50) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.brandPrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: AppTheme.brandPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap, this.size = 48});
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
