import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

enum ReminderPermission { granted, denied, unsupported }

abstract class ReminderScheduler {
  Future<String?> initialize(void Function(String) onTap);
  Future<ReminderPermission> permission();
  Future<ReminderPermission> requestPermission();
  Future<tz.Location> localZone();
  Future<List<int>> pendingIds();
  Future<void> schedule(PlannedReminder reminder);
  Future<void> cancel(int id);
  Future<void> showTest();
  Future<void> openSettings();
}

class AndroidReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  static bool _zonesReady = false;
  static const _channel = AndroidNotificationChannel(
    'mi_red_reminders_v1',
    'Recordatorios de cobros',
    description: 'Avisos aproximados de revisión de mensualidades y posibles suspensiones.',
    enableVibration: false,
  );
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'mi_red_reminders_v1',
      'Recordatorios de cobros',
      channelDescription: 'Avisos aproximados de revisión de mensualidades y posibles suspensiones.',
      icon: 'ic_notification',
      enableVibration: false,
      visibility: NotificationVisibility.private,
    ),
  );
  AndroidFlutterLocalNotificationsPlugin get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()!;

  @override
  Future<String?> initialize(void Function(String) onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) onTap(response.payload!);
      },
    );
    await _android.createNotificationChannel(_channel);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? launch?.notificationResponse?.payload
        : null;
  }

  @override
  Future<ReminderPermission> permission() async =>
      await _android.areNotificationsEnabled() == true
      ? ReminderPermission.granted
      : ReminderPermission.denied;
  @override
  Future<ReminderPermission> requestPermission() async {
    await _android.requestNotificationsPermission();
    return permission();
  }

  @override
  Future<tz.Location> localZone() async {
    if (!_zonesReady) {
      tz_data.initializeTimeZones();
      _zonesReady = true;
    }
    final info = await FlutterTimezone.getLocalTimezone();
    return tz.getLocation(info.identifier);
  }

  @override
  Future<List<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests())
          .map((request) => request.id)
          .toList();
  @override
  Future<void> schedule(PlannedReminder reminder) => _plugin.zonedSchedule(
    id: reminder.id,
    title: reminder.title,
    body: reminder.body,
    scheduledDate: reminder.when,
    notificationDetails: _details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: reminder.kind.name,
  );
  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
  @override
  Future<void> showTest() => _plugin.show(
    id: reminderTestId,
    title: 'Prueba de Mi Red',
    body: 'Revisa los cobros pendientes en Mi Red. Este es un aviso de prueba.',
    notificationDetails: _details,
    payload: ReminderKind.review.name,
  );
  @override
  Future<void> openSettings() async {
    if (await _plugin.openAppNotificationSettings() != true) {
      throw StateError('No se pudieron abrir los ajustes de notificaciones.');
    }
  }
}

/// This Android MVP has no OS notification integration on other platforms.
class UnsupportedReminderScheduler implements ReminderScheduler {
  @override
  Future<String?> initialize(void Function(String) onTap) async => null;
  @override
  Future<ReminderPermission> permission() async =>
      ReminderPermission.unsupported;
  @override
  Future<ReminderPermission> requestPermission() => permission();
  @override
  Future<tz.Location> localZone() async => tz.UTC;
  @override
  Future<List<int>> pendingIds() async => [];
  @override
  Future<void> schedule(PlannedReminder reminder) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> showTest() async {}
  @override
  Future<void> openSettings() async {}
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => Platform.isAndroid
      ? AndroidReminderScheduler()
      : UnsupportedReminderScheduler(),
);
