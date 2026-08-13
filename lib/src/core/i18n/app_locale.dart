import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap EN/ES toggle — persisted; screens read [copy].
class AppLocale {
  const AppLocale(this.code);
  final String code;
  bool get isEs => code == 'es';
}

class AppLocaleNotifier extends Notifier<AppLocale> {
  static const _key = 'swipess_locale';

  @override
  AppLocale build() {
    _hydrate();
    return const AppLocale('en');
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'en';
    if (code != state.code) state = AppLocale(code);
  }

  Future<void> setCode(String code) async {
    state = AppLocale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}

final appLocaleProvider =
    NotifierProvider<AppLocaleNotifier, AppLocale>(AppLocaleNotifier.new);

String capCopy(WidgetRef ref, String en, String es) {
  return ref.watch(appLocaleProvider).isEs ? es : en;
}
