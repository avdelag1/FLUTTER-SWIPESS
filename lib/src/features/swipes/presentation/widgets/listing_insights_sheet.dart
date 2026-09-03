import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showListingInsightsSheet(
  BuildContext context, {
  required Listing listing,
  required VoidCallback onMessage,
  required VoidCallback onShare,
  required VoidCallback onReport,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InsightsSheet(
      listing: listing,
      onMessage: onMessage,
      onShare: onShare,
      onReport: onReport,
    ),
  );
}

class _InsightsSheet extends StatelessWidget {
  const _InsightsSheet({
    required this.listing,
    required this.onMessage,
    required this.onShare,
    required this.onReport,
  });

  final Listing listing;
  final VoidCallback onMessage;
  final VoidCallback onShare;
  final VoidCallback onReport;

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
        specs.add((
          Icons.branding_watermark_rounded,
          'Brand',
          listing.vehicleBrand!,
        ));
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
      if (listing.pricingUnit != null) {
        specs.add((Icons.payments_rounded, 'Pricing', listing.pricingUnit!));
      }
    }
    return specs;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF0A0A0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'INSIGHTS',
                      style: AppTheme.displayItalic.copyWith(fontSize: 24),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              Text(
                (listing.title ?? 'Listing').toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFEB4898),
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      listing.formattedLocation,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in _specs)
                    Container(
                      width: (MediaQuery.sizeOf(context).width - 50) / 2,
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Icon(s.$1, color: AppTheme.brandPrimary, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.$2.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  s.$3,
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
                    ),
                ],
              ),
              if (listing.description?.trim().isNotEmpty == true) ...[
                SizedBox(height: 20),
                Text(
                  'DESCRIPTION',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  listing.description!,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
              ],
              if (listing.amenities.isNotEmpty) ...[
                SizedBox(height: 20),
                Text(
                  'AMENITIES',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in listing.amenities)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          a,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onMessage();
                      },
                      icon: Icon(Icons.chat_bubble_rounded),
                      label: Text(
                        'CONNECT',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  _Rail(
                    icon: Icons.share_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      onShare();
                    },
                  ),
                  SizedBox(width: 8),
                  _Rail(
                    icon: Icons.flag_outlined,
                    onTap: () {
                      AppHaptics.medium();
                      Navigator.pop(context);
                      onReport();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
