import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Temporary stand-in for a Capacitor route that is not fully ported yet.
class CapPlaceholderScreen extends StatelessWidget {
  const CapPlaceholderScreen({
    super.key,
    required this.title,
    required this.path,
    this.note,
  });

  final String title;
  final String path;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/client/dashboard');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              path,
              style: GoogleFonts.jetBrainsMono(
                color: AppTheme.brandAccent,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              note ??
                  'This Capacitor route is registered for parity. UI is still being ported.',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withAlpha(200),
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
