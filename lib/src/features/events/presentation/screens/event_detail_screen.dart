import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

class EventDetailScreen extends StatelessWidget {
  final Event event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: CustomScrollView(
        slivers: [
          // Hero Image AppBar
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: AppTheme.surfaceColor,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                iconColor: Colors.white,
                onTap: () => context.pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildGlassIconButton(
                  icon: Icons.bookmark_border_rounded,
                  iconColor: Colors.white,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to your calendar!')),
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    event.imageUrl ?? 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(100),
                          Colors.transparent,
                          AppTheme.surfaceColor,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Row(
                    children: [
                      _buildPill(event.category, AppTheme.brandPrimary),
                      if (event.discountTag != null && event.discountTag!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildPill(event.discountTag!, AppTheme.brandAccent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Details Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.calendar_today_rounded,
                          title: 'Date & Time',
                          subtitle: event.eventDate != null 
                            ? '${event.eventDate!.month}/${event.eventDate!.day} at ${event.eventDate!.hour}:${event.eventDate!.minute.toString().padLeft(2, '0')}' 
                            : 'TBA',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.location_on_rounded,
                          title: 'Location',
                          subtitle: event.location ?? 'TBA',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.confirmation_number_rounded,
                          title: 'Tickets',
                          subtitle: event.priceText ?? (event.isFree ? 'Free' : 'TBA'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.person_rounded,
                          title: 'Organizer',
                          subtitle: event.organizerName ?? 'Swipess Elite',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Description
                  const Text(
                    'About this Event',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.description ?? 'Join us for an exclusive experience. Get your tickets now before they sell out!',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Location Detail
                  if (event.locationDetail != null && event.locationDetail!.isNotEmpty) ...[
                    const Text(
                      'Getting There',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.locationDetail!,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  
                  const SizedBox(height: 100), // padding for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withAlpha(240),
          border: Border(
            top: BorderSide(color: Colors.white.withAlpha(20), width: 1),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Redirecting to ticketing partner...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                alignment: Alignment.center,
                child: const Text(
                  'Get Tickets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.brandPrimary, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withAlpha(45),
                width: 1,
              ),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}
