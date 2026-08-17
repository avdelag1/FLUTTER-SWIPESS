import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';

/// One deliberately minimal startup surface shared by bootstrap and the router.
/// No progress bars, gradients, cards or top-edge decoration: only the Swipess
/// mark and a tiny activity indicator on the same dark canvas as the native
/// launch screen.
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

    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: canvas,
        body: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwipessLogo(
                  width: 152,
                  variant: SwipessLogoVariant.transparent,
                ),
                SizedBox(height: 22),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.35,
                    color: Color(0xD9FFFFFF),
                    backgroundColor: Colors.transparent,
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
