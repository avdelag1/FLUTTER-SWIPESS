import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Explicit voice languages supported by SWIPESS AI.
///
/// There is intentionally no automatic detector. The selected language is the
/// single source of truth for speech recognition and AI reply language so iOS,
/// Android and PWA behave consistently.
enum VoiceLanguage {
  english('en-US', 'EN', '🇺🇸 English'),
  spanish('es-MX', 'ES', '🇲🇽 Español'),
  french('fr-FR', 'FR', '🇫🇷 Français'),
  german('de-DE', 'DE', '🇩🇪 Deutsch'),
  italian('it-IT', 'IT', '🇮🇹 Italiano'),
  portuguese('pt-BR', 'PT', '🇧🇷 Português'),
  russian('ru-RU', 'RU', '🇷🇺 Русский'),
  chinese('zh-CN', 'ZH', '🇨🇳 中文'),
  japanese('ja-JP', 'JA', '🇯🇵 日本語'),
  arabic('ar-SA', 'AR', '🇸🇦 العربية');

  const VoiceLanguage(this.localeCode, this.shortCode, this.displayName);

  final String localeCode;
  final String shortCode;
  final String displayName;
}

/// Global explicit language selection used by voice recognition and AI replies.
final voiceLanguageProvider =
    NotifierProvider<VoiceLanguageNotifier, VoiceLanguage>(() {
      return VoiceLanguageNotifier();
    });

class VoiceLanguageNotifier extends Notifier<VoiceLanguage> {
  static const _prefsKey = 'swipess_voice_language';

  @override
  VoiceLanguage build() {
    unawaited(_restore());
    return VoiceLanguage.english;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == null || saved.isEmpty) return;
      final restored = VoiceLanguage.values.where((lang) => lang.name == saved);
      if (restored.isNotEmpty) state = restored.first;
    } catch (_) {}
  }

  void setLanguage(VoiceLanguage lang) {
    state = lang;
    unawaited(_persist(lang));
  }

  Future<void> _persist(VoiceLanguage lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, lang.name);
    } catch (_) {}
  }
}
