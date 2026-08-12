import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class PriceTrackerScreen extends StatelessWidget {
  const PriceTrackerScreen({super.key});

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
                        'MARKET TRENDS',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                // Chart area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withAlpha(25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Aldea Zamá Average Price', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('\$4,250', style: TextStyle(color: AppTheme.brandPrimary, fontSize: 32, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(50),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.trending_up_rounded, color: Colors.green, size: 12),
                                      SizedBox(width: 4),
                                      Text('+5.2%', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Mock Chart
                            SizedBox(
                              height: 150,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) {
                                  final height = 50.0 + (index * 15.0);
                                  return Container(
                                    width: 32,
                                    height: height,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Jan', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Feb', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Mar', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Apr', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('May', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text('Jun', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
          ),
        ],
      ),
    );
  }
}
