import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap EN/ES catalogs (`src/i18n/locales`) plus Flutter-only `flutter.*` keys.
class AppLocale {
  const AppLocale(this.code);
  final String code;
  bool get isEs => code == 'es';
}

class AppLocaleNotifier extends Notifier<AppLocale> {
  static const _key = 'swipess_locale';

  Map<String, String> _en = const {};
  Map<String, String> _es = const {};

  @override
  AppLocale build() {
    _hydrate();
    return const AppLocale('en');
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    _en = await _loadCatalog('en');
    _es = await _loadCatalog('es');
    final code = prefs.getString(_key) ?? 'en';
    state = AppLocale(code);
  }

  Future<void> setCode(String code) async {
    state = AppLocale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  String lookup(String key, [String fallback = '']) {
    final primary = state.isEs ? _es : _en;
    final secondary = state.isEs ? _en : _es;
    return primary[key] ?? secondary[key] ?? fallback;
  }

  static Future<Map<String, String>> _loadCatalog(String code) async {
    final out = <String, String>{};
    try {
      final cap = await rootBundle.loadString('assets/i18n/$code.json');
      out.addAll(_flatten(jsonDecode(cap)));
    } catch (_) {}
    try {
      final extra = await rootBundle.loadString(
        'assets/i18n/flutter_$code.json',
      );
      final decoded = jsonDecode(extra);
      if (decoded is Map) {
        decoded.forEach((k, v) => out[k.toString()] = v.toString());
      }
    } catch (_) {}
    return out;
  }

  static Map<String, String> _flatten(dynamic obj, [String prefix = '']) {
    final out = <String, String>{};
    if (obj is Map) {
      obj.forEach((k, v) {
        final key = prefix.isEmpty ? k.toString() : '$prefix.$k';
        out.addAll(_flatten(v, key));
      });
    } else if (prefix.isNotEmpty) {
      out[prefix] = obj?.toString() ?? '';
    }
    return out;
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, AppLocale>(
  AppLocaleNotifier.new,
);

String capCopy(WidgetRef ref, String en, String es) {
  return ref.watch(appLocaleProvider).isEs ? es : en;
}

/// Cap `t('nav.home')` — watches locale so screens rebuild.
String t(WidgetRef ref, String key, [String fallback = '']) {
  ref.watch(appLocaleProvider);
  return ref.read(appLocaleProvider.notifier).lookup(key, fallback);
}
