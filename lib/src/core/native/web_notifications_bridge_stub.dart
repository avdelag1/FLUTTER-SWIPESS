class WebNotificationsBridge {
  const WebNotificationsBridge._();

  static bool get isSupported => false;
  static bool get permissionGranted => false;

  static Future<bool> requestPermission() async => false;

  static void scheduleReengagement() {}

  static void cancelReengagement() {}
}
