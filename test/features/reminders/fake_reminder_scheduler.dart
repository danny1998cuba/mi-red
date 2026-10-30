import 'dart:async';

import 'package:mi_red/features/reminders/reminder_plan.dart';
import 'package:mi_red/features/reminders/reminder_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeReminderScheduler implements ReminderScheduler {
  ReminderPermission permissionValue = ReminderPermission.denied;
  ReminderPermission requestResult = ReminderPermission.granted;
  String zoneName = 'America/Toronto';
  String? launchPayload;
  void Function(String)? onTap;
  int initializations = 0,
      requests = 0,
      scheduledCalls = 0,
      tests = 0,
      settingsOpened = 0;
  bool failInitialize = false;
  int? failScheduleAt;
  Completer<void>? requestGate;
  Completer<void>? zoneGate;
  final pending = <int, PlannedReminder>{};
  final foreignIds = <int>{42};
  final cancellations = <int>[];

  @override
  Future<String?> initialize(void Function(String) callback) async {
    initializations++;
    if (failInitialize) throw StateError('Fallo sintético al inicializar');
    onTap = callback;
    return launchPayload;
  }

  @override
  Future<ReminderPermission> permission() async => permissionValue;
  @override
  Future<ReminderPermission> requestPermission() async {
    requests++;
    if (requestGate != null) await requestGate!.future;
    permissionValue = requestResult;
    return permissionValue;
  }

  @override
  Future<tz.Location> localZone() async {
    if (zoneGate != null) await zoneGate!.future;
    return tz.getLocation(zoneName);
  }

  @override
  Future<List<int>> pendingIds() async => [...pending.keys, ...foreignIds];
  @override
  Future<void> schedule(PlannedReminder reminder) async {
    scheduledCalls++;
    if (scheduledCalls == failScheduleAt) {
      throw StateError('Fallo sintético de programación');
    }
    pending[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    cancellations.add(id);
    pending.remove(id);
    foreignIds.remove(id);
  }

  @override
  Future<void> showTest() async {
    tests++;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}
