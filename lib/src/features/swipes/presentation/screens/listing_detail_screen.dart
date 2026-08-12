import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';

/// Full-screen listing detail — maps to web's ListingDetailPage.tsx.
class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  Listing? _listing;
  bool _loading = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    final repo = ListingRepository();
    final listing = await repo.fetchById(widget.listingId);
    if (mounted) {
      setState(() {
        _listing = listing;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      );
    }

    final listing = _listing;
    if (listing == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('Listing not found', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Image carousel header
          _buildImageHeader(listing),

          // Content
          SliverToBoxAdapter(child: _buildContent(listing)),
        ],
      ),
    );
  }

  Widget _buildImageHeader(Listing listing) {
    final images = listing.images;
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: Colors.black,
      leading: _buildBackButton(),
      actions: [
        _buildActionPill(Icons.share_rounded, () {}),
        const SizedBox(width: 8),
        _buildActionPill(Icons.favorite_border_rounded, () {}),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: images.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentImageIndex = i),
                    itemBuilder: (ctx, i) => Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.image_not_supported_rounded, color: Colors.white38, size: 48),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 1.0],
                          colors: [
                            Colors.black.withAlpha(76),
                            Colors.transparent,
                            Colors.black.withAlpha(200),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Page indicator
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (i) => Container(
                          width: i == _currentImageIndex ? 20 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: i == _currentImageIndex
                                ? Colors.white
                                : Colors.white.withAlpha(102),
                          ),
                        )),
                      ),
                    ),
                ],
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                  ),
                ),
                child: const Icon(Icons.home_rounded, color: Colors.white38, size: 64),
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withAlpha(76),
              ),
              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionPill(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withAlpha(76),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Listing listing) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price & Category
          Row(
            children: [
              Text(
                listing.formattedPrice,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              const Spacer(),
              if (listing.category != null)
                _GlassChip(
                  label: listing.category!,
                  color: AppTheme.brandPrimary,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            listing.title ?? 'Listing',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Location
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.white.withAlpha(153), size: 16),
              const SizedBox(width: 4),
              Text(
                listing.formattedLocation,
                style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick stats row
          if (listing.beds != null || listing.baths != null || listing.squareFootage != null)
            _buildStatsRow(listing),

          const SizedBox(height: 20),

          // Amenities
          if (listing.amenities.isNotEmpty) ...[
            const Text('Amenities', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: listing.amenities.map((a) => _GlassChip(label: a)).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Description
          if (listing.description != null && listing.description!.isNotEmpty) ...[
            const Text('About', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              listing.description!,
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 20),
          ],

          // Contact button
          _buildContactButton(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Listing listing) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (listing.beds != null) _StatItem(icon: Icons.bed_rounded, value: '${listing.beds}', label: 'Beds'),
              if (listing.baths != null) _StatItem(icon: Icons.bathtub_rounded, value: listing.baths!.toStringAsFixed(listing.baths! % 1 == 0 ? 0 : 1), label: 'Baths'),
              if (listing.squareFootage != null) _StatItem(icon: Icons.square_foot_rounded, value: listing.squareFootage!.toStringAsFixed(0), label: 'Sq ft'),
              if (listing.furnished == true) _StatItem(icon: Icons.chair_rounded, value: '✓', label: 'Furnished'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
          ),
          boxShadow: [BoxShadow(color: AppTheme.brandPrimary.withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.chat_bubble_rounded, size: 20),
          label: const Text('Contact Owner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.brandPrimary, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 11)),
      ],
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _GlassChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: (color ?? Colors.white).withAlpha(20),
        border: Border.all(color: (color ?? Colors.white).withAlpha(40)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? Colors.white.withAlpha(220),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
