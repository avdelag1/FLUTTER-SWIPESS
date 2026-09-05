import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `useAppTheme` light/dark — light is white-matte.
enum AppVisualTheme { dark, light }

class VisualThemeNotifier extends Notifier<AppVisualTheme> {
  static const _prefsKey = 'swipess_visual_theme';
  static const _whiteDefaultMigrationKey =
      'swipess_white_default_20260905_applied';

  @override
  AppVisualTheme build() {
    Future.microtask(_hydrate);
    // White/light is the automatic default for a fresh install/session.
    // Users who explicitly choose dark keep that preference via hydration.
    return AppVisualTheme.light;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();

    // Previous releases could leave existing installs persisted as dark even
    // though white is now the product default. Migrate every install to white
    // exactly once. After this marker is written, any user who intentionally
    // switches to black/dark keeps that choice normally.
    final migrated = prefs.getBool(_whiteDefaultMigrationKey) ?? false;
    if (!migrated) {
      await prefs.setString(_prefsKey, 'light');
      await prefs.setBool(_whiteDefaultMigrationKey, true);
      if (state != AppVisualTheme.light) state = AppVisualTheme.light;
      return;
    }

    final raw = prefs.getString(_prefsKey);
    final savedTheme = switch (raw) {
      'dark' => AppVisualTheme.dark,
      'light' => AppVisualTheme.light,
      _ => null,
    };
    if (savedTheme != null && state != savedTheme) {
      state = savedTheme;
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
