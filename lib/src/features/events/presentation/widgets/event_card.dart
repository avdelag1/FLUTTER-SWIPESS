import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onBookmarkTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppTheme.dashElevated,
        border: Border.all(
          color: AppTheme.dashGlassBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppTheme.brandPrimary.withAlpha(20),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: GestureDetector(
            onTap: () {
              context.push(AppPaths.exploreEvent(event.id));
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                Image.network(
                  event.imageUrl ?? 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1E1E24),
                      child: const Center(
                        child: Icon(
                          Icons.celebration_rounded,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF16161A),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppTheme.brandPrimary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                ),

                // Gradient Overlay for Text Visibility
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(120),
                        Colors.transparent,
                        Colors.black.withAlpha(180),
                        Colors.black.withAlpha(240),
                      ],
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),

                // Card Content Overlay
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Category Pill & Bookmark Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGlassPill(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.brandAccent,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (event.discountTag != null && event.discountTag!.isNotEmpty)
                                      ? event.discountTag!
                                      : event.category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildGlassIconButton(
                            icon: Icons.bookmark_border_rounded,
                            iconColor: Colors.white.withAlpha(220),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onBookmarkTap?.call();
                            },
                          ),
                        ],
                      ),

                      // Bottom Details Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date & Time Row
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: AppTheme.brandPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                event.eventDate != null ? '${event.eventDate!.month}/${event.eventDate!.day}' : 'TBA',
                                style: const TextStyle(
                                  color: AppTheme.brandPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Event Name
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Location Row
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 15,
                                color: AppTheme.brandAccent.withAlpha(220),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.location ?? 'TBA',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(210),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Footer Row: Attendees & Price / RSVP
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Attendee Count Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.dashWell,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.dashGlassBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                      Text(
                                        'View Details',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(230),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Ticket Price / Action Button
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.brandAccent,
                                      AppTheme.brandPrimary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppTheme.brandPrimary.withAlpha(90),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  event.priceText ?? (event.isFree ? 'Free' : 'Tickets'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildGlassPill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.dashWell,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dashGlassBorder,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.dashWell,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.dashGlassBorder,
            width: 1,
          ),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
    );
  }

}
