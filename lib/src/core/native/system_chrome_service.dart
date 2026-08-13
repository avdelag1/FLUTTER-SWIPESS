import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';

/// Cap boot chrome: `main.tsx` ran `StatusBar.setOverlaysWebView({overlay: true})`
/// + `Style.Dark` + a black bar, and `microPolish.setStatusBarColor` flipped the
/// icons when the matte theme changed.
///
/// Flutter already paints behind the bars, but nothing told Android which icon
/// brightness to use. The Android window theme is `Theme.Light.NoTitleBar`, so
/// the platform picked dark icons — an invisible clock and battery on the black
/// Swipess canvas.
abstract final class SystemChromeService {
  /// Dark canvas: light icons, no scrim on either bar.
  static const dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  /// White-matte theme: dark icons over the light canvas.
  static const light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  static SystemUiOverlayStyle styleFor({required bool isLight}) =>
      isLight ? light : dark;

  /// Edge to edge, so the reel and the floating dock run under the system bars
  /// the way the Capacitor WebView did. Screens keep their own `SafeArea`.
  static Future<void> initialize() async {
    apply(isLight: false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static void apply({required bool isLight}) {
    SystemChrome.setSystemUIOverlayStyle(styleFor(isLight: isLight));
  }
}

/// Keeps the system bars in step with the matte theme toggle, and re-asserts the
/// style after any surface (a Material `AppBar`, a route transition) overwrites it.
class SystemChromeSync extends ConsumerWidget {
  const SystemChromeSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(isLightThemeProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemChromeService.styleFor(isLight: isLight),
      child: child,
    );
  }
}
