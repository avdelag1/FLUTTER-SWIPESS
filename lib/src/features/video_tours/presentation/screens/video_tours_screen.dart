import 'package:flutter/material.dart';

class VideoToursScreen extends StatelessWidget {
  const VideoToursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fake Video Feed (just an image for now, representing a playing video)
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.7, 1.0],
                  colors: [Colors.black.withAlpha(100), Colors.transparent, Colors.black.withAlpha(200)],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Bar
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
                            color: Colors.black.withAlpha(100),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(50)),
                          ),
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'VIDEO TOURS',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom Info & Right Actions
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D00),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('\$12,500/mo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(height: 12),
                            const Text('The Neo Penthouse', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            const Text('Miami, FL • 3 Bed • 2 Bath', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                      // Actions
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(Icons.favorite_rounded, '1.2k'),
                          const SizedBox(height: 24),
                          _buildActionButton(Icons.chat_bubble_rounded, '34'),
                          const SizedBox(height: 24),
                          _buildActionButton(Icons.share_rounded, 'Share'),
                        ],
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

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(50)),
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 28)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
