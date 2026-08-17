import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';

/// Single in-app splash that visually matches the native iOS launch screen.
/// Keep this intentionally simple so users never see a second logo treatment
/// or a separate loading animation after the native splash disappears.
class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0D),
      body: Center(
        child: SwipessLogo(
          width: 190,
          variant: SwipessLogoVariant.transparent,
        ),
      ),
    );
  }
}
