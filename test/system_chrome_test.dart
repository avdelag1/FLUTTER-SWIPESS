import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/native/system_chrome_service.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';

void main() {
  Widget wrap({required bool isLight}) {
    final container = ProviderContainer(
      overrides: [isLightThemeProvider.overrideWithValue(isLight)],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: SystemChromeSync(child: Scaffold(backgroundColor: Colors.black)),
      ),
    );
  }

  testWidgets('dark canvas asks the platform for light system bar icons', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(isLight: false));
    await tester.pumpAndSettle();

    final style = SystemChrome.latestStyle!;
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarColor, Colors.transparent);
  });

  testWidgets('white-matte theme flips the icons dark', (tester) async {
    await tester.pumpWidget(wrap(isLight: true));
    await tester.pumpAndSettle();

    expect(SystemChrome.latestStyle!.statusBarIconBrightness, Brightness.dark);
    expect(
      SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
  });

  test(
    'both styles keep the bars transparent, like the Cap overlay WebView',
    () {
      for (final style in [
        SystemChromeService.dark,
        SystemChromeService.light,
      ]) {
        expect(style.statusBarColor, Colors.transparent);
        expect(style.systemNavigationBarColor, Colors.transparent);
        expect(style.systemNavigationBarContrastEnforced, isFalse);
      }
    },
  );
}
