import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';

/// Black canvas + transparent SWIPESS wordmark. Used for native-adjacent
/// loading (after the access code, while onboarding prefs resolve).
class BootSplash extends StatelessWidget {
  const BootSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          StarfieldBackground(),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: SwipessLogo(
                width: 280,
                variant: SwipessLogoVariant.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
