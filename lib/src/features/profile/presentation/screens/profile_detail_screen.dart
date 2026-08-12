import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          
          // Image Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network('https://images.unsplash.com/photo-1524504388940-b1c1722653e1', fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0],
                      colors: [Colors.transparent, const Color(0xFF0A0A0D)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(50)),
                      ),
                      child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Profile Details
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    border: Border(top: BorderSide(color: Colors.white.withAlpha(25))),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sarah, 24', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, color: const Color(0xFFFF4D00), size: 16),
                              const SizedBox(width: 8),
                              const Text('Miami, FL', style: TextStyle(color: Colors.white, fontSize: 14)),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(50),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('VERIFIED', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text('ABOUT', style: TextStyle(color: Colors.white.withAlpha(127), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          const SizedBox(height: 12),
                          const Text(
                            'Just moved to Miami. Looking for a modern apartment with a great view. Love design, tech, and fitness.',
                            style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(25),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withAlpha(50)),
                                  ),
                                  child: const Center(
                                    child: Text('REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFFF4D00), Color(0xFFEB4898)]),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFFFF4D00).withAlpha(127), blurRadius: 24, offset: const Offset(0, 8)),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text('MESSAGE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
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
