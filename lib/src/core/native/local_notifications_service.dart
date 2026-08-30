import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_swipes/src/core/native/web_notifications_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Swipess system notification service.
///
/// Native iOS/Android reminders are scheduled through
/// `flutter_local_notifications`. Web/PWA uses the browser Notification API.
/// Permission is NEVER requested from a lifecycle/background callback; only an
/// explicit foreground action may call [ensurePermission].
class LocalNotificationsService {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Stable ids, so we cancel exactly what we scheduled.
  static const consistencyReminderId = 88003;
  static const reengageIds = [88001, 88002];

  static const _channelId = 'swipess_reengagement';
  static const _channelName = 'Swipess reminders';
  static const _channelDescription =
      'Consistency challenge, matches and return reminders.';
  static const _permissionPreferenceKey =
      'swipess_notification_permission_granted';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;
  bool _permissionGranted = false;

  /// Route a tapped native reminder into the app.
  void Function(String route)? onNotificationRoute;

  bool get _nativeSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isSupported =>
      kIsWeb ? WebNotificationsBridge.isSupported : _nativeSupported;

  bool get permissionGranted => _permissionGranted;

  Future<void> initialize() async {
    if (_ready) return;

    if (kIsWeb) {
      _permissionGranted = WebNotificationsBridge.permissionGranted;
      _ready = true;
      return;
    }

    if (!_nativeSupported) return;
    tz_data.initializeTimeZones();

    try {
      final prefs = await SharedPreferences.getInstance();
      _permissionGranted =
          prefs.getBool(_permissionPreferenceKey) ?? false;
    } catch (e) {
      debugPrint('[LocalNotifications] permission preference failed: $e');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // A cold start never opens with a permission sheet in the user's face.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleTap,
      );
      _ready = true;
      await _resumeLaunchTap();
    } catch (e) {
      debugPrint('[LocalNotifications] init failed: $e');
    }
  }

  /// A tap that launched the native app from cold arrives here rather than
  /// through the callback above.
  Future<void> _resumeLaunchTap() async {
    if (kIsWeb) return;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (details?.didNotificationLaunchApp ?? false) {
        _handleTap(response);
      }
    } catch (e) {
      debugPrint('[LocalNotifications] launch details failed: $e');
    }
  }

  void _handleTap(NotificationResponse? response) =>
      handleTapForTest(response?.payload);

  @visibleForTesting
  void handleTapForTest(String? payload) {
    final route = (payload == null || payload.isEmpty)
        ? '/notifications'
        : (payload.startsWith('/') ? payload : '/$payload');
    onNotificationRoute?.call(route);
  }

  /// Request notification permission. This method is intentionally called only
  /// from explicit foreground UI (for example the Enable button in Pulse Feed).
  Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    await initialize();
    if (_permissionGranted) return true;

    if (kIsWeb) {
      _permissionGranted = await WebNotificationsBridge.requestPermission();
      return _permissionGranted;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        _permissionGranted =
            await android?.requestNotificationsPermission() ?? false;
      } else {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        _permissionGranted =
            await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permissionPreferenceKey, _permissionGranted);
    } catch (e) {
      debugPrint('[LocalNotifications] permission error: $e');
      _permissionGranted = false;
    }
    return _permissionGranted;
  }

  /// Schedule generic re-engagement reminders only after the app leaves the
  /// foreground. The 45-minute consistency step is in-app only (see
  /// [SessionGamificationService] + [GlobalNotice.showEngagement]).
  Future<void> scheduleReengagement() async {
    if (!isSupported) return;
    await initialize();

    // Backgrounding the app must never open an OS/browser permission prompt.
    if (!_permissionGranted) return;

    if (kIsWeb) {
      WebNotificationsBridge.scheduleReengagement();
      return;
    }

    await cancelReengagement();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _schedule(
        id: reengageIds[0],
        title: 'Your matches miss you 👀',
        body: 'New listings and people are waiting for you on Swipess.',
        after: const Duration(days: 3),
        details: details,
      );
      await _schedule(
        id: reengageIds[1],
        title: "Don't miss out 🔥",
        body: 'Fresh matches near you — come take a look.',
        after: const Duration(days: 7),
        details: details,
      );
    } catch (e) {
      debugPrint('[LocalNotifications] schedule error: $e');
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required Duration after,
    required NotificationDetails details,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(after),
      notificationDetails: details,
      // A nudge does not need to punch through Doze at an exact minute, and
      // inexact alarms need no extra permission on Android 14+.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/notifications',
    );
  }

  Future<void> cancelReengagement() async {
    if (!isSupported) return;

    if (kIsWeb) {
      WebNotificationsBridge.cancelReengagement();
      return;
    }

    try {
      await _plugin.cancel(id: consistencyReminderId);
      for (final id in reengageIds) {
        await _plugin.cancel(id: id);
      }
    } catch (e) {
      debugPrint('[LocalNotifications] cancel error: $e');
    }
  }
}
