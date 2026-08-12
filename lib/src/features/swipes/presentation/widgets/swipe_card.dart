import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class SwipeCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Color>? colors;

  const SwipeCard({
    super.key,
    required this.title,
    required this.description,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cinematicGlassDecoration.copyWith(
        gradient: LinearGradient(
          colors: colors ?? [AppTheme.brandAccent, AppTheme.brandPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                color: Colors.white, // Colors.white.withAlpha is not const, we use simple color here and opacity below
                fontSize: 18,
                letterSpacing: -0.2,
                fontWeight: FontWeight.w500,
              ).copyWith(color: Colors.white.withAlpha(200)),
            ),
          ],
        ),
      ),
    );
  }
}
