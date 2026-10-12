import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminders.dart';
import '../models/task.dart' show Task;

/// Schedules a local reminder for each incomplete task (see [Task.reminderAt]).
/// Local notifications are not supported on web, so every call is a no-op there.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!_supported || _ready) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Falls back to UTC; reminders still fire, just offset.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks for notification permission (Android 13+ and iOS).
  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _queue = Future.value();

  /// Rebuilds all reminders from the current task list.
  /// Calls run one after another, so an older list can never overwrite a newer one.
  Future<void> sync(List<Task> tasks) {
    _queue = _queue.then((_) => _sync(tasks)).catchError((Object _) {});
    return _queue;
  }

  Future<void> _sync(List<Task> tasks) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    // Exact alarms fire at the chosen minute. Inexact ones can be delayed by a minute or more.
    final canBeExact = await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        false;
    final mode = canBeExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    var id = 0; // cancelAll ran first, so a simple counter can't collide
    for (final (:task, :at) in plannedReminders(tasks, DateTime.now())) {
      final t = task;
      final when = tz.TZDateTime.from(at, tz.local);
      final dueText = t.hasTime ? DateFormat('d MMM, h:mm a').format(t.dueDate) : DateFormat('d MMM').format(t.dueDate);
      await _plugin.zonedSchedule(
        id: id++,
        title: t.remindMinutes == 0 ? (t.hasTime ? 'Task due now' : 'Task due today') : 'Upcoming task',
        body: t.remindMinutes == 0 ? t.title : '${t.title} - due $dueText',
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task reminders',
            channelDescription: 'Reminders for your tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: mode,
      );
    }
  }

  Future<void> cancelAll() {
    _queue = _queue.then((_) async {
      if (_ready) await _plugin.cancelAll();
    }).catchError((Object _) {});
    return _queue;
  }
}
