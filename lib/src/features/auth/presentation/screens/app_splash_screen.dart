import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';

/// One consistent startup surface shared by web and native boot.
/// The native launch screen, this frame, and the welcome page all use the same
/// brand mark so startup feels continuous instead of changing logos.
class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFF0A0A0D);
    const overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: canvas,
      systemNavigationBarDividerColor: canvas,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: canvas,
        body: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SwipessLogo(
                  width: 220,
                  variant: SwipessLogoVariant.white,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF4D78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
