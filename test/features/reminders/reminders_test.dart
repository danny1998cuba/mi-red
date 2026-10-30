import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/reminders/reminder_plan.dart';
import 'package:mi_red/features/reminders/reminder_providers.dart';
import 'package:mi_red/features/reminders/reminder_scheduler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'fake_reminder_scheduler.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);
  test('Plans only day 2/day 3 at 09 local, bounded horizon and stable IDs across leap February/year rollover', () {
    final zone = tz.getLocation('America/Toronto');
    for (final instant in [
      DateTime.utc(2026, 12, 31, 20),
      DateTime.utc(2027, 2, 1),
      DateTime.utc(2028, 2, 1),
    ]) {
      final plan = planReminders(instant, zone);
      expect(plan.length, inInclusiveRange(10, 12));
      expect(plan.map((item) => item.id).toSet().length, plan.length);
      expect(plan.every((item) => item.when.isAfter(instant)), isTrue);
      expect(
        plan.every((item) => item.when.hour == 9 && item.when.minute == 0),
        isTrue,
      );
      expect(
        plan.every(
          (item) => item.when.day == (item.kind == ReminderKind.review ? 2 : 3),
        ),
        isTrue,
      );
      expect(plan.every((item) => isReminderId(item.id)), isTrue);
      expect(
        plan.map((item) => item.id),
        planReminders(instant, zone).map((item) => item.id),
      );
      expect(
        plan.every((item) => !item.body.contains('Cliente sintético')),
        isTrue,
      );
      expect(plan.every((item) => !item.body.contains('123,45')), isTrue);
    }
  });
  test(
    '09:00 today is not duplicated; day 3 becomes next pending reminder',
    () {
      final zone = tz.getLocation('America/Toronto');
      final before = planReminders(
        tz.TZDateTime(zone, 2026, 12, 2, 8, 59),
        zone,
      );
      final after = planReminders(tz.TZDateTime(zone, 2026, 12, 2, 9), zone);
      expect(before.first.kind, ReminderKind.review);
      expect(after.first.kind, ReminderKind.candidates);
      expect(after.first.when.day, 3);
      expect(after.map((item) => item.id), isNot(contains(before.first.id)));
    },
  );
  test('Real IANA schedules retain 09 local across DST and change the UTC instant by timezone', () {
    final toronto = tz.getLocation('America/Toronto');
    final madrid = tz.getLocation('Europe/Madrid');
    final start = DateTime.utc(2026, 2, 1, 12);
    final plan = planReminders(start, toronto);
    final march = plan.firstWhere((item) => item.when.month == 3);
    final april = plan.firstWhere((item) => item.when.month == 4);
    expect(march.when.hour, 9);
    expect(april.when.hour, 9);
    expect(march.when.timeZoneOffset, const Duration(hours: -5));
    expect(april.when.timeZoneOffset, const Duration(hours: -4));
    final other = planReminders(start, madrid);
    expect(other.map((item) => item.id), plan.map((item) => item.id));
    expect(
      other.first.when.millisecondsSinceEpoch,
      isNot(plan.first.when.millisecondsSinceEpoch),
    );
  });

  late AppDatabase db;
  late FakeReminderScheduler scheduler;
  late ProviderContainer container;
  late DateTime now;
  final navigations = <ReminderKind>[];
  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      clientClockProvider.overrideWithValue(() => now),
      reminderNavigationProvider.overrideWithValue(navigations.add),
    ],
  );
  setUp(() {
    now = DateTime.utc(2026, 10, 29, 15);
    db = AppDatabase(NativeDatabase.memory());
    scheduler = FakeReminderScheduler();
    navigations.clear();
    container = newContainer();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  RemindersController controller() =>
      container.read(remindersProvider.notifier);
  Future<String> financialSnapshot() async => jsonEncode({
    for (final table in ['clients', 'devices', 'charges', 'payments'])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((row) => row.data)
          .toList(),
  });

  test(
    'Startup is opt-out and never asks permission or changes financial data',
    () async {
      final before = await financialSnapshot();
      final initial = await container.read(remindersProvider.future);
      expect(initial.enabled, isFalse);
      expect(scheduler.requests, 0);
      expect(scheduler.pending, isEmpty);
      expect(scheduler.foreignIds, {42});
      expect(await financialSnapshot(), before);
      expect(
        (await container.read(settingsServiceProvider).read())
            .notificationsEnabled,
        isFalse,
      );
    },
  );
  test('Denial persists off, leaves no reminders and never shows a test implicitly', () async {
    await container.read(remindersProvider.future);
    scheduler.requestResult = ReminderPermission.denied;
    await controller().setEnabled(true);
    final data = container.read(remindersProvider).requireValue;
    expect(data.enabled, isFalse);
    expect(data.permission, ReminderPermission.denied);
    expect(data.notice, contains('no concedió'));
    expect(scheduler.requests, 1);
    expect(scheduler.pending, isEmpty);
    expect(scheduler.tests, 0);
    expect(
      (await container.read(settingsServiceProvider).read())
          .notificationsEnabled,
      isFalse,
    );
  });
  test('Granted opt-in is idempotent; off cancels only this feature and preserves other settings', () async {
    await container
        .read(settingsServiceProvider)
        .update(
          businessName: 'Negocio sintético',
          currencyLabel: 'unidad',
          defaultCallingCode: '+1',
          notificationsEnabled: false,
        );
    await container
        .read(clientServiceProvider)
        .create(
          id: 'synthetic',
          fullName: 'Cliente sintético de avisos',
          monthlyFeeMinor: 12345,
          today: LocalDate.fromDateTime(now),
        );
    await container
        .read(paymentServiceProvider)
        .register(
          chargeId: 'synthetic:2026-10',
          amountMinor: 12345,
          paidAt: now,
        );
    final before = await financialSnapshot();
    await container.read(remindersProvider.future);
    await controller().setEnabled(true);
    final firstCount = scheduler.scheduledCalls;
    expect(firstCount, inInclusiveRange(10, 12));
    expect(container.read(remindersProvider).requireValue.enabled, isTrue);
    await Future.wait([controller().refresh(), controller().refresh()]);
    expect(scheduler.scheduledCalls, firstCount);
    expect(scheduler.requests, 1);
    await controller().setEnabled(false);
    expect(scheduler.pending, isEmpty);
    expect(scheduler.foreignIds, {42});
    expect(scheduler.cancellations, contains(reminderTestId));
    final settings = await container.read(settingsServiceProvider).read();
    expect(settings.businessName, 'Negocio sintético');
    expect(settings.currencyLabel, 'unidad');
    expect(settings.defaultCallingCode, '+1');
    expect(settings.notificationsEnabled, isFalse);
    expect(await financialSnapshot(), before);
  });
  test(
    'Concurrent enable taps prompt once, and a queued opt-out is never lost',
    () async {
      await container.read(remindersProvider.future);
      scheduler.requestGate = Completer<void>();
      final first = controller().setEnabled(true);
      final duplicate = controller().setEnabled(true);
      final off = controller().setEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.requests, 1);
      scheduler.requestGate!.complete();
      await Future.wait([first, duplicate, off]);
      expect(scheduler.requests, 1);
      expect(scheduler.pending, isEmpty);
      expect(container.read(remindersProvider).requireValue.enabled, isFalse);
      expect(
        (await container.read(settingsServiceProvider).read())
            .notificationsEnabled,
        isFalse,
      );
    },
  );
  test('Zone/clock changes reschedule, prune expired IDs, and simulated process restart retains one plan', () async {
    await container.read(remindersProvider.future);
    await controller().setEnabled(true);
    final initial = scheduler.pending.values.first.when.millisecondsSinceEpoch;
    final ids = scheduler.pending.keys.toSet();
    scheduler.zoneName = 'Europe/Madrid';
    await controller().refresh();
    expect(scheduler.pending.keys.toSet(), ids);
    expect(
      scheduler.pending.values.first.when.millisecondsSinceEpoch,
      isNot(initial),
    );
    now = DateTime.utc(2026, 12, 4, 15);
    await controller().refresh();
    expect(
      scheduler.pending.values.every((item) => item.when.isAfter(now)),
      isTrue,
    );
    expect(scheduler.cancellations.any(ids.contains), isTrue);
    final expected = scheduler.pending.keys.toSet();
    container.dispose();
    container = newContainer();
    final reopened = await container.read(remindersProvider.future);
    expect(reopened.enabled, isTrue);
    expect(scheduler.pending.keys.toSet(), expected);
    expect(scheduler.pending.length, reopened.scheduledCount);
    expect(scheduler.requests, 1);
  });
  test('Revoked OS permission cancels the plan and persists off without prompting on resume', () async {
    await container.read(remindersProvider.future);
    await controller().setEnabled(true);
    scheduler.permissionValue = ReminderPermission.denied;
    await controller().refresh();
    expect(container.read(remindersProvider).requireValue.enabled, isFalse);
    expect(scheduler.pending, isEmpty);
    expect(scheduler.requests, 1);
    expect(
      (await container.read(settingsServiceProvider).read())
          .notificationsEnabled,
      isFalse,
    );
  });
  test('Partial scheduler failure is cleaned up and retry can enable without touching accounting', () async {
    await container.read(remindersProvider.future);
    final before = await financialSnapshot();
    scheduler.failScheduleAt = 2;
    await controller().setEnabled(true);
    expect(container.read(remindersProvider).hasError, isTrue);
    expect(
      (await container.read(settingsServiceProvider).read())
          .notificationsEnabled,
      isFalse,
    );
    expect(scheduler.pending, isEmpty);
    scheduler.failScheduleAt = null;
    await controller().refresh();
    await controller().setEnabled(true);
    expect(container.read(remindersProvider).requireValue.enabled, isTrue);
    expect(await financialSnapshot(), before);
  });
  test('Initialization error is retryable, test notification is explicit and cold/live taps validate payload', () async {
    scheduler.failInitialize = true;
    await expectLater(
      container.read(remindersProvider.future),
      throwsStateError,
    );
    scheduler.failInitialize = false;
    scheduler.launchPayload = ReminderKind.candidates.name;
    await controller().refresh();
    expect(navigations, [ReminderKind.candidates]);
    await controller().refresh();
    expect(navigations.length, 1);
    scheduler.onTap!('invalid-payload');
    expect(navigations.length, 1);
    await controller().testNotification();
    expect(scheduler.tests, 0);
    await controller().setEnabled(true);
    await controller().testNotification();
    expect(scheduler.tests, 1);
    scheduler.onTap!(ReminderKind.review.name);
    expect(navigations, [ReminderKind.candidates, ReminderKind.review]);
    await controller().openSettings();
    expect(scheduler.settingsOpened, 1);
    expect(scheduler.initializations, 2);
  });
}
