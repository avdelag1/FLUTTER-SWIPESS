import 'dart:ui';
import 'package:flutter/material.dart';

class SeekersScreen extends StatelessWidget {
  const SeekersScreen({super.key});

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
                  'SEEKER\\nREQUESTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildSeekerCard('Looking for Penthouse', 'Miami, FL', 'Need a 3BR penthouse with ocean views. Move in next month.'),
                const SizedBox(height: 20),
                _buildSeekerCard('Fitness Coach', 'New York, NY', 'Looking for a private PT for early morning sessions.'),
                
                const SizedBox(height: 120), // Bottom padding for dock
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekerCard(String title, String location, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.blue.withAlpha(50)),
                ),
                child: const Text('REAL ESTATE', style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              const Spacer(),
              const Text('2 hrs ago', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.white.withAlpha(150), size: 14),
              const SizedBox(width: 4),
              Text(location, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Text(description, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
