import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Ambient Background
          Positioned.fill(
            child: Container(color: const Color(0xFF0A0A0D)),
          ),
          
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                // Top Nav
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EVENTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.5,
                      ),
                    ),
                    _GlassPillButton(
                      icon: Icons.add_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Placeholder Cards
                _buildEventCard('Yacht Party', 'Miami, FL', 'Tomorrow at 9PM', 'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a'),
                const SizedBox(height: 20),
                _buildEventCard('Penthouse Launch', 'New York, NY', 'Oct 24 at 7PM', 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9'),
                const SizedBox(height: 20),
                _buildEventCard('Private Chef Tasting', 'Los Angeles, CA', 'Nov 2 at 8PM', 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a'),
                
                const SizedBox(height: 120), // Bottom padding for dock
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(String title, String location, String date, String img) {
    return Container(
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(img, fit: BoxFit.cover),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withAlpha(200)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: Colors.white.withAlpha(200), size: 14),
                    const SizedBox(width: 4),
                    Text(location, style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today_rounded, color: Colors.white.withAlpha(200), size: 14),
                    const SizedBox(width: 4),
                    Text(date, style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 14, fontWeight: FontWeight.w600)),
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

class _GlassPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassPillButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 24)),
          ),
        ),
      ),
    );
  }
}
