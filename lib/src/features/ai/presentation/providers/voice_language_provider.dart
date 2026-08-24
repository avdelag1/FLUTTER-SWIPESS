import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported voice recognition languages.
enum VoiceLanguage {
  english('en-US', 'EN', '🇺🇸 English'),
  spanish('es-ES', 'ES', '🇪🇸 Español'),
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

/// Global provider for the user's selected voice recognition language.
final voiceLanguageProvider =
    StateNotifierProvider<VoiceLanguageNotifier, VoiceLanguage>((ref) {
  return VoiceLanguageNotifier();
});

class VoiceLanguageNotifier extends StateNotifier<VoiceLanguage> {
  // Defaults to English, though if null the JS bridge would fallback to OS lang.
  // We keep an explicit default here so the UI knows what to show.
  VoiceLanguageNotifier() : super(VoiceLanguage.english);

  void setLanguage(VoiceLanguage lang) {
    state = lang;
  }
}
