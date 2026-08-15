import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Cap `src/utils/localNotifications.ts` (`@capacitor/local-notifications`).
///
/// When the app goes to the background we schedule a couple of friendly nudges
/// a few days out; when the user comes back we cancel them. Net effect: a
/// reminder only ever fires if they *don't* return on their own.
class LocalNotificationsService {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Stable ids, so we cancel exactly what we scheduled. Same numbers as Cap.
  static const reengageIds = [88001, 88002];

  static const _channelId = 'swipess_reengagement';
  static const _channelName = 'Reminders';
  static const _channelDescription =
      'Occasional nudges about new matches and listings.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;
  bool _permissionGranted = false;

  /// Route a tapped reminder into the app. Cap read `extra.url` and defaulted
  /// to `/notifications`.
  void Function(String route)? onNotificationRoute;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_ready || !isSupported) return;
    tz_data.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Asked for explicitly on the first schedule instead, so a cold start
        // never opens with a permission sheet in the user's face.
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

  /// A tap that launched the app from cold arrives here rather than through the
  /// callback above.
  Future<void> _resumeLaunchTap() async {
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

  Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    if (_permissionGranted) return true;
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
    } catch (e) {
      debugPrint('[LocalNotifications] permission error: $e');
      _permissionGranted = false;
    }
    return _permissionGranted;
  }

  /// Cap's two nudges: three days out, then a week out.
  Future<void> scheduleReengagement() async {
    if (!isSupported) return;
    await initialize();
    if (!await ensurePermission()) return;
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
    try {
      for (final id in reengageIds) {
        await _plugin.cancel(id: id);
      }
    } catch (e) {
      debugPrint('[LocalNotifications] cancel error: $e');
    }
  }
}
