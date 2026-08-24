typedef BrowserSpeechTextCallback = void Function(String text, bool isFinal);
typedef BrowserSpeechListeningCallback = void Function(bool listening);
typedef BrowserSpeechErrorCallback = void Function(String message);

class BrowserLiveSpeech {
  bool get isSupported => false;
  void setLanguage(String langCode) {}

  Future<bool> start({
    required BrowserSpeechTextCallback onText,
    required BrowserSpeechListeningCallback onListening,
    required BrowserSpeechErrorCallback onError,
  }) async => false;

  Future<void> stop() async {}

  Future<void> cancel() async {}
}
