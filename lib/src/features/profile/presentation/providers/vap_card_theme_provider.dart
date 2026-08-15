import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted PEARL card theme index — shared by the nav-bar VAP ID card and
/// the identity vault preview on the profile page so both show the same
/// color the user picked, instead of two disconnected looks.
class VapCardThemeIndexNotifier extends AsyncNotifier<int> {
  static const _key = 'vap-card-theme-index';

  @override
  Future<int> build() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_key) ?? 0;
    return (i >= 0 && i < VapCardTheme.themes.length) ? i : 0;
  }

  Future<void> setIndex(int index) async {
    final clamped = index % VapCardTheme.themes.length;
    state = AsyncData(clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, clamped);
  }

  Future<void> cycle() async {
    final current = state.value ?? 0;
    await setIndex((current + 1) % VapCardTheme.themes.length);
  }
}

final vapCardThemeIndexProvider =
    AsyncNotifierProvider<VapCardThemeIndexNotifier, int>(
      VapCardThemeIndexNotifier.new,
    );

/// Convenience accessor — resolved theme, falling back to the first theme
/// (Pearl) while the persisted index is still loading.
final vapCardThemeProvider = Provider<VapCardTheme>((ref) {
  final index = ref.watch(vapCardThemeIndexProvider).value ?? 0;
  return VapCardTheme.themes[index];
});
