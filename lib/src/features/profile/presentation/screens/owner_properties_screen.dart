import 'dart:ui';
import 'package:flutter/material.dart';

class OwnerPropertiesScreen extends StatefulWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  State<OwnerPropertiesScreen> createState() => _OwnerPropertiesScreenState();
}

class _OwnerPropertiesScreenState extends State<OwnerPropertiesScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: Column(
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
                        'MY ASSETS',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withAlpha(25)),
                    ),
                    child: Row(
                      children: [
                        _buildTab('ACTIVE', 0),
                        _buildTab('PENDING', 1),
                        _buildTab('SOLD', 2),
                      ],
                    ),
                  ),
                ),
                
                // Content
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 40),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return _buildAssetCard();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isActive 
                ? const LinearGradient(colors: [Color(0xFFFF4D00), Color(0xFFEB4898)])
                : null,
            boxShadow: isActive ? [BoxShadow(color: const Color(0xFFFF4D00).withAlpha(89), blurRadius: 24, offset: const Offset(0, 8))] : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withAlpha(127),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network('https://images.unsplash.com/photo-1600596542815-ffad4c1539a9', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                  colors: [Colors.transparent, Colors.black.withAlpha(220)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('The Neo Penthouse', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('Miami, FL', style: TextStyle(color: Colors.white.withAlpha(200), fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: const Text('EDIT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
