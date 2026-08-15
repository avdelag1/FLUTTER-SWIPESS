import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `useAppTheme` light/dark — light is white-matte.
enum AppVisualTheme { dark, light }

class VisualThemeNotifier extends Notifier<AppVisualTheme> {
  static const _prefsKey = 'swipess_visual_theme';

  @override
  AppVisualTheme build() {
    Future.microtask(_hydrate);
    return AppVisualTheme.dark;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == 'light' && state != AppVisualTheme.light) {
      state = AppVisualTheme.light;
    }
  }

  Future<void> setTheme(AppVisualTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      theme == AppVisualTheme.light ? 'light' : 'dark',
    );
  }

  Future<void> toggle() async {
    await setTheme(
      state == AppVisualTheme.light
          ? AppVisualTheme.dark
          : AppVisualTheme.light,
    );
  }
}

final visualThemeProvider =
    NotifierProvider<VisualThemeNotifier, AppVisualTheme>(
      VisualThemeNotifier.new,
    );

/// Sync value for widgets.
final isLightThemeProvider = Provider<bool>((ref) {
  return ref.watch(visualThemeProvider) == AppVisualTheme.light;
});
