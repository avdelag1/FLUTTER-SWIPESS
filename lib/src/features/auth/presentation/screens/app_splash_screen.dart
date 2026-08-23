import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Minimal Swipess startup surface: thin wordmark + three-dot loader.
/// Keep this visually aligned with the web bootstrap so startup feels like one
/// continuous branded moment instead of switching between different loaders.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                const Padding(
                  padding: EdgeInsets.only(left: 6.8),
                  child: Text(
                    'SWIPESS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 6.8,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final phase =
                            (_controller.value - (index * 0.13)) % 1.0;
                        double pulse = 0;
                        if (phase < 0.6) {
                          final local = phase / 0.6;
                          pulse = local <= 0.5 ? local * 2 : (1 - local) * 2;
                        }
                        return Padding(
                          padding: EdgeInsets.only(right: index == 2 ? 0 : 7),
                          child: Transform.translate(
                            offset: Offset(0, -5 * pulse),
                            child: Opacity(
                              opacity: 0.38 + (0.62 * pulse),
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(width: 4, height: 4),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
