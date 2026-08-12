import 'dart:ui';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(40)),
                          ),
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'NOTIFICATIONS',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    children: [
                      _buildNotificationCard(
                        Icons.local_fire_department_rounded, 
                        Colors.pinkAccent, 
                        'New Match!', 
                        'You and Sarah liked each other.', 
                        '2m ago',
                      ),
                      const SizedBox(height: 12),
                      _buildNotificationCard(
                        Icons.chat_bubble_rounded, 
                        Colors.blueAccent, 
                        'New Message', 
                        'John: "Is the penthouse still available?"', 
                        '1h ago',
                      ),
                      const SizedBox(height: 12),
                      _buildNotificationCard(
                        Icons.verified_user_rounded, 
                        const Color(0xFFFF4D00), 
                        'Identity Verified', 
                        'Your ID Card has been officially stamped.', 
                        '2d ago',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(IconData icon, Color color, String title, String subtitle, String time) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(50)),
                ),
                child: Center(child: Icon(icon, color: color, size: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(time, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
