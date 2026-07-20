import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

typedef NotificationTapCallback = Future<void> Function();

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _firstNotificationId = 2000;
  static const int _scheduledDays = 32;
  static const String _payload = 'daily_invitation';

  static const List<String> _invitationTemplates = <String>[
    '{pet} 在窗边等你回来～',
    '{pet} 给你留了一个暖暖的位置',
    '{pet} 想和你一起待一会儿～',
    '回来看看 {pet} 今天在做什么吧',
  ];

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize(NotificationTapCallback onTap) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload == _payload) await onTap();
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) await onTap();
  }

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  Future<void> scheduleDaily({
    required String petName,
    required int hour,
    required int minute,
    DateTime? now,
  }) async {
    await cancelDaily();
    final localNow = now ?? DateTime.now();
    var candidate = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      hour,
      minute,
    );
    if (!candidate.isAfter(localNow)) {
      candidate = DateTime(
        localNow.year,
        localNow.month,
        localNow.day + 1,
        hour,
        minute,
      );
    }
    for (var index = 0; index < _scheduledDays; index++) {
      final day = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + index,
        hour,
        minute,
      );
      // DateTime uses the device's local calendar (including future DST
      // transitions). Converting that instant to a UTC TZDateTime lets the
      // plugin schedule it without a separate native time-zone dependency.
      final scheduled = tz.TZDateTime.from(day.toUtc(), tz.UTC);
      final template =
          _invitationTemplates[index % _invitationTemplates.length];
      await _plugin.zonedSchedule(
        id: _firstNotificationId + index,
        title: petName,
        body: template.replaceAll('{pet}', petName),
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_pet_invitation',
            '每天的宠物邀请',
            channelDescription: '来自宠物的温柔日常邀请',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _payload,
      );
    }
  }

  Future<void> cancelDaily() async {
    for (var index = 0; index < _scheduledDays; index++) {
      await _plugin.cancel(id: _firstNotificationId + index);
    }
  }
}
