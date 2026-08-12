
import 'package:flutter/material.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  bool isListings = true;

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
                // Top Tab Selector
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
                        _buildTab('LIKED LISTINGS', true),
                        _buildTab('LIKED PEOPLE', false),
                      ],
                    ),
                  ),
                ),
                
                // Content
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return _buildLikedCard();
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

  Widget _buildTab(String title, bool isListingTab) {
    final isActive = isListings == isListingTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isListings = isListingTab),
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

  Widget _buildLikedCard() {
    return Container(
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
                  colors: [Colors.transparent, Colors.black.withAlpha(200)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\$1.5M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text('Miami, FL', style: TextStyle(color: Colors.white.withAlpha(200), fontWeight: FontWeight.w600, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
