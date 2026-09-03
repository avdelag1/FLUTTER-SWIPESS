import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `NotFound.tsx` — 404 with suggested destinations (not a grey scaffold).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.path});

  final String? path;

  static const _suggestions = [
    (AppPaths.clientDashboard, 'Explore Properties', Icons.explore_rounded),
    (AppPaths.clientLikedProperties, 'My Likes', Icons.favorite_rounded),
    (AppPaths.messages, 'Messages', Icons.chat_bubble_rounded),
    (AppPaths.clientServices, 'Find Services', Icons.search_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.12,
            left: 24,
            child: Transform.rotate(
              angle: -0.2,
              child: _GhostCard(width: 150, height: 220),
            ),
          ),
          Positioned(
            bottom: MediaQuery.sizeOf(context).height * 0.18,
            right: 28,
            child: Transform.rotate(
              angle: 0.14,
              child: _GhostCard(width: 130, height: 190, orange: true),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFF97316),
                            Color(0xFFEA580C),
                            Color(0xFFFBBF24),
                            Color(0xFFFF6B35),
                            Color(0xFFDC2626),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          '404',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 96,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                            letterSpacing: -4,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'This swipe went off the map',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        path == null
                            ? 'That route is not in Swipess yet.'
                            : 'No screen for $path',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            AppHaptics.medium();
                            context.go(AppPaths.clientDashboard);
                          },
                          icon: Icon(Icons.home_rounded),
                          label: Text(
                            'BACK TO DASHBOARD',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'TRY THESE',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      for (final s in _suggestions) ...[
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                AppHaptics.selection();
                                context.go(s.$1);
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      s.$3,
                                      color: AppTheme.brandPrimary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        s.$2,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostCard extends StatelessWidget {
  const _GhostCard({
    required this.width,
    required this.height,
    this.orange = false,
  });

  final double width;
  final double height;
  final bool orange;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: orange
              ? [const Color(0xFFF97316).withAlpha(18), Colors.transparent]
              : [Colors.white.withAlpha(14), Colors.transparent],
        ),
      ),
    );
  }
}
