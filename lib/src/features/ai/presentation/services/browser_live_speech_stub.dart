typedef BrowserSpeechTextCallback = void Function(String text, bool isFinal);
typedef BrowserSpeechListeningCallback = void Function(bool listening);
typedef BrowserSpeechErrorCallback = void Function(String message);
typedef BrowserSpeechSilenceCallback = void Function();
typedef BrowserSpeechActivityCallback = void Function();

class BrowserLiveSpeech {
  bool get isSupported => false;
  void setLanguage(String langCode) {}

  Future<bool> start({
    required BrowserSpeechTextCallback onText,
    required BrowserSpeechListeningCallback onListening,
    required BrowserSpeechErrorCallback onError,
    BrowserSpeechSilenceCallback? onSilence,
    BrowserSpeechActivityCallback? onSpeechActivity,
  }) async => false;

  Future<void> stop() async {}

  Future<void> cancel() async {}
}
