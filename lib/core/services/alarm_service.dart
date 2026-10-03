import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../data/models/app_settings.dart';
import '../../data/models/calendar_event.dart';

class AlarmService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  int _scheduledCount = 0;

  int get scheduledCount => _scheduledCount;

  static const String channelId = 'cuims_deadline_alarms';
  static const String channelName = 'Quiz & Assignment Alarms';
  static const String channelDescription =
      'High-priority alarms and notifications for upcoming quizzes, tests, and assignment deadlines';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
    } catch (e) {
      debugPrint('[AlarmService] Timezone init error: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[AlarmService] Notification tapped: ${response.payload}');
      },
    );

    // Create high-importance Android Notification Channel
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      try {
        await androidPlugin.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('[AlarmService] Exact alarms permission request: $e');
      }
    }

    _isInitialized = true;
    debugPrint('[AlarmService] Initialized successfully');
  }

  /// Cancels all existing alarms and schedules fresh ones based on current events and settings.
  Future<int> refreshAlarms({
    required List<LmsCalendarEvent> events,
    required AppSettings settings,
  }) async {
    await initialize();

    // 1. Cancel previous alarms
    await cancelAllAlarms();

    if (!settings.enableDeadlineAlarms || !settings.notificationsEnabled) {
      debugPrint('[AlarmService] Deadline alarms disabled in settings.');
      return 0;
    }

    final now = DateTime.now();
    int scheduled = 0;

    for (final event in events) {
      if (!event.isUpcoming) continue;
      final eventTime = event.eventDateTime;

      final isQuiz = event.name.toLowerCase().contains('quiz') ||
          event.name.toLowerCase().contains('test') ||
          event.name.toLowerCase().contains('exam') ||
          event.name.toLowerCase().contains('mst') ||
          (event.actionUrl?.toLowerCase().contains('mod/quiz') ?? false);

      final isAssignment = event.name.toLowerCase().contains('assign') ||
          event.name.toLowerCase().contains('submission') ||
          (event.actionUrl?.toLowerCase().contains('mod/assign') ?? false);

      // 1. 24 Hours Before (for Quiz)
      if (isQuiz && settings.alarm24HoursBefore) {
        final t24 = eventTime.subtract(const Duration(hours: 24));
        if (t24.isAfter(now)) {
          final id = _generateAlarmId(event.id, 1);
          final title = '⏰ 24h Reminder: Quiz Tomorrow';
          final body =
              '${event.name}${event.courseName != null ? ' (${event.courseName})' : ''} begins in 24 hours.';
          await _scheduleZonedNotification(
            id: id,
            title: title,
            body: body,
            scheduledTime: t24,
            payload: event.actionUrl ?? '',
          );
          scheduled++;
        }
      }

      // 2. 1 Hour Before (for Quiz or Assignment)
      if ((isQuiz || isAssignment) && settings.alarm1HourBefore) {
        final t1 = eventTime.subtract(const Duration(hours: 1));
        if (t1.isAfter(now)) {
          final id = _generateAlarmId(event.id, 2);
          final type = isQuiz ? 'Quiz' : 'Assignment';
          final title = '🚨 1 Hour Alert: $type Starting Soon';
          final body =
              '${event.name}${event.courseName != null ? ' (${event.courseName})' : ''} in 1 hour!';
          await _scheduleZonedNotification(
            id: id,
            title: title,
            body: body,
            scheduledTime: t1,
            payload: event.actionUrl ?? '',
          );
          scheduled++;
        }
      }

      // 3. On the Time (Exact Start / Due Time)
      if (settings.alarmAtExactTime) {
        if (eventTime.isAfter(now)) {
          final id = _generateAlarmId(event.id, 3);
          final type = isQuiz ? 'Quiz Started' : 'Deadline Now';
          final title = '🔔 NOW: $type';
          final body =
              '${event.name}${event.courseName != null ? ' (${event.courseName})' : ''} is happening right now!';
          await _scheduleZonedNotification(
            id: id,
            title: title,
            body: body,
            scheduledTime: eventTime,
            payload: event.actionUrl ?? '',
          );
          scheduled++;
        }
      }
    }

    _scheduledCount = scheduled;
    debugPrint('[AlarmService] Scheduled $_scheduledCount alarms successfully.');
    return scheduled;
  }

  Future<void> _scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[AlarmService] Error scheduling notification $id: $e');
    }
  }

  Future<void> cancelAllAlarms() async {
    await initialize();
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('[AlarmService] Error cancelling alarms: $e');
    }
    _scheduledCount = 0;
    debugPrint('[AlarmService] All previous alarms cancelled.');
  }

  Future<void> showTestAlarm() async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      999999,
      '🔔 LMS Alarm Test Active',
      'Your quiz and assignment deadline alarms are configured with sound and vibration!',
      details,
    );
  }

  int _generateAlarmId(int eventId, int offset) {
    // Generate safe 31-bit positive integer
    return (eventId.abs() % 100000) * 10 + offset;
  }
}
