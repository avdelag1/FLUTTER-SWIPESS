import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported voice recognition languages.
///
/// [auto] is the default so dashboard dictation can preserve bilingual and
/// code-switched speech instead of forcing every new session through en-US.
enum VoiceLanguage {
  auto('', 'AUTO', '🌐 Auto detect'),
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

  bool get isAutomatic => this == VoiceLanguage.auto;
}

/// Global provider for the user's selected voice recognition language.
final voiceLanguageProvider =
    NotifierProvider<VoiceLanguageNotifier, VoiceLanguage>(() {
  return VoiceLanguageNotifier();
});

class VoiceLanguageNotifier extends Notifier<VoiceLanguage> {
  @override
  VoiceLanguage build() => VoiceLanguage.auto;

  void setLanguage(VoiceLanguage lang) {
    state = lang;
  }
}
