import 'dart:ui';
import 'package:flutter/material.dart';

class AddListingScreen extends StatelessWidget {
  const AddListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                const Text(
                  'WHAT ARE WE\\nADDING TODAY?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 48),
                _buildAddCard(Icons.home_work_rounded, 'Real Estate', 'List a property for sale or rent'),
                const SizedBox(height: 16),
                _buildAddCard(Icons.directions_car_rounded, 'Vehicle', 'List a luxury car or yacht'),
                const SizedBox(height: 16),
                _buildAddCard(Icons.work_rounded, 'Service', 'Offer your professional services'),
                const SizedBox(height: 16),
                _buildAddCard(Icons.event_rounded, 'Event', 'Host an exclusive event'),
                
                const SizedBox(height: 120), // Bottom padding for dock
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard(IconData icon, String title, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4D00).withAlpha(50),
                ),
                child: Center(child: Icon(icon, color: const Color(0xFFFF4D00), size: 28)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100), size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
