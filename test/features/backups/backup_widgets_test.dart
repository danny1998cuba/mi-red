import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_maintenance.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';
import 'package:mi_red/features/backups/backup_providers.dart';
import 'package:mi_red/features/backups/backup_service.dart';
import 'package:mi_red/features/billing/billing_providers.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/reminders/reminder_providers.dart';
import 'package:mi_red/features/reminders/reminder_scheduler.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../billing/billing_widgets_test.dart' show pumpBilling;
import '../communications/communication_widgets_test.dart'
    show reachCommunication, pressCommunication;
import '../reminders/fake_reminder_scheduler.dart';
import 'backup_fixture.dart';
import 'fake_backup_adapters.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  late AppDatabase db;
  late ProviderContainer container;
  late FakeBackupCipher cipher;
  late FakeBackupDocuments documents;
  late FakeReminderScheduler scheduler;
  late DateTime now;
  var failImport = false;
  setUp(() async {
    now = backupTestDate;
    failImport = false;
    db = AppDatabase(NativeDatabase.memory());
    await insertSyntheticBackup(db, syntheticBackup(notifications: false));
    cipher = FakeBackupCipher();
    documents = FakeBackupDocuments();
    scheduler = FakeReminderScheduler();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clientClockProvider.overrideWithValue(() => now),
        backupCipherProvider.overrideWithValue(cipher),
        backupDocumentsProvider.overrideWithValue(documents),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        backupServiceProvider.overrideWithValue(
          BackupService(
            db,
            afterTableImported: (table) async {
              if (failImport && table == 'devices') {
                throw StateError('Synthetic import failure');
              }
            },
          ),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester tester) async {
    container.read(appRouterProvider).go('/settings');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await pumpBilling(tester);
  }

  Future<void> press(WidgetTester tester, String key) =>
      pressCommunication(tester, key);
  Future<void> enter(WidgetTester tester, String key, String value) async {
    await reachCommunication(tester, key);
    await tester.enterText(find.byKey(Key(key)), value);
    await pumpBilling(tester);
  }

  Future<void> passwords(WidgetTester tester) async {
    await enter(tester, 'backup-password', backupWidgetPassword);
    await enter(tester, 'backup-confirm-password', backupWidgetPassword);
  }

  Future<void> preview(WidgetTester tester) async {
    await press(tester, 'backup-restore');
    await enter(tester, 'backup-password', backupWidgetPassword);
    await press(tester, 'backup-verify');
  }

  Future<String> fingerprint() async =>
      jsonEncode((await BackupService(db).capture(backupTestDate)).records);

  testWidgets(
    'export requires matching strong password; errors clear fields and never invoke SAF',
    (tester) async {
      await open(tester);
      final before = await fingerprint();
      await press(tester, 'backup-create');
      await enter(tester, 'backup-password', 'short');
      await enter(tester, 'backup-confirm-password', 'short');
      await press(tester, 'backup-save');
      expect(find.textContaining('al menos 12'), findsWidgets);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('backup-password')))
            .controller!
            .text,
        isEmpty,
      );
      await enter(tester, 'backup-password', backupWidgetPassword);
      await enter(tester, 'backup-confirm-password', 'A different password');
      await press(tester, 'backup-save');
      expect(find.textContaining('no coinciden'), findsOneWidget);
      expect(documents.saves, 0);
      await press(tester, 'backup-password-visibility');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('backup-password')))
            .obscureText,
        isFalse,
      );
      await press(tester, 'backup-close');
      expect(await fingerprint(), before);
      expect(container.read(databaseMaintenanceProvider).active, isFalse);
    },
  );

  testWidgets(
    'cancelled save and disk/permission failures do not claim success; retry succeeds with name/date/destination',
    (tester) async {
      await open(tester);
      final before = await fingerprint();
      documents.cancelSave = true;
      await press(tester, 'backup-create');
      await passwords(tester);
      await press(tester, 'backup-save');
      expect(find.textContaining('Guardado cancelado'), findsOneWidget);
      expect(await fingerprint(), before);
      documents.cancelSave = false;
      documents.failSave = true;
      await passwords(tester);
      await press(tester, 'backup-save');
      expect(find.textContaining('espacio disponible'), findsOneWidget);
      expect(await fingerprint(), before);
      documents.failSave = false;
      await passwords(tester);
      await press(tester, 'backup-save');
      expect(find.textContaining('Copia cifrada guardada'), findsOneWidget);
      expect(documents.lastName, endsWith('.miredbk'));
      expect(
        cipher.captured!.records['app_settings']!.single['last_backup_at'],
        syntheticBackup().records['app_settings']!.single['last_backup_at'],
      );
      expect(
        (await db.select(db.appSettings).getSingle()).lastBackupAt,
        now.millisecondsSinceEpoch,
      );
      await press(tester, 'backup-done');
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'double export tap cannot duplicate modal or active system operation',
    (tester) async {
      await open(tester);
      await reachCommunication(tester, 'backup-create');
      final openPoint = tester.getCenter(
        find.byKey(const Key('backup-create')),
      );
      await tester.tapAt(openPoint);
      // A real second tap can land on the modal that has just covered Settings.
      await tester.tapAt(openPoint);
      await pumpBilling(tester);
      expect(find.byType(Dialog), findsOneWidget);
      await passwords(tester);
      documents.saveGate = Completer<void>();
      await reachCommunication(tester, 'backup-save');
      final savePoint = tester.getCenter(find.byKey(const Key('backup-save')));
      await tester.tapAt(savePoint);
      await tester.tapAt(savePoint);
      await pumpBilling(tester);
      expect(documents.saves, 1);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('backup-close')))
            .onPressed,
        isNull,
      );
      documents.saveGate!.complete();
      await pumpBilling(tester);
      expect(find.textContaining('Copia cifrada guardada'), findsOneWidget);
    },
  );

  testWidgets(
    'cancel picker and cancel replacement preview preserve every table',
    (tester) async {
      await open(tester);
      final before = await fingerprint();
      documents.cancelPick = true;
      await press(tester, 'backup-restore');
      expect(find.byType(Dialog), findsNothing);
      expect(cipher.decryptions, 0);
      expect(await fingerprint(), before);
      documents.cancelPick = false;
      await preview(tester);
      expect(find.text('Clientes: 3 / 3'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('backup-replace')))
            .onPressed,
        isNull,
      );
      await press(tester, 'backup-close');
      expect(await fingerprint(), before);
    },
  );

  testWidgets(
    'wrong password clears secret and retry previews before explicit replacement; dashboard and watchers refresh',
    (tester) async {
      await db.customStatement(
        "UPDATE clients SET full_name='Cambio sintético posterior' WHERE id='active'",
      );
      await open(tester);
      final before = await fingerprint();
      await press(tester, 'backup-restore');
      await enter(tester, 'backup-password', 'wrong');
      await press(tester, 'backup-verify');
      expect(
        find.textContaining('incorrecta o archivo dañado'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('backup-password')))
            .controller!
            .text,
        isEmpty,
      );
      expect(await fingerprint(), before);
      await enter(tester, 'backup-password', backupWidgetPassword);
      await press(tester, 'backup-verify');
      expect(await fingerprint(), before);
      await press(tester, 'backup-accept-replacement');
      await press(tester, 'backup-replace');
      expect(
        find.textContaining('Datos restaurados y verificados'),
        findsOneWidget,
      );
      expect(await fingerprint(), jsonEncode(cipher.source.records));
      await press(tester, 'backup-done');
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/',
      );
      expect(find.text('Cambio sintético posterior'), findsNothing);
      container.read(appRouterProvider).go('/clients');
      await pumpBilling(tester);
      expect(find.textContaining('Prueba T07 active'), findsWidgets);
    },
  );

  testWidgets(
    'mid-import UI failure rolls back then retries without mixed rows',
    (tester) async {
      await db.customStatement(
        "UPDATE clients SET full_name='Base anterior sintética' WHERE id='active'",
      );
      await open(tester);
      final before = await fingerprint();
      await preview(tester);
      failImport = true;
      await press(tester, 'backup-accept-replacement');
      await press(tester, 'backup-replace');
      expect(await fingerprint(), before);
      expect(find.textContaining('Datos restaurados'), findsNothing);
      failImport = false;
      await press(tester, 'backup-replace');
      expect(await fingerprint(), jsonEncode(cipher.source.records));
    },
  );

  testWidgets(
    'SAF return cannot trigger reconciliation writes during the exclusive workflow',
    (tester) async {
      await open(tester);
      final before = await fingerprint();
      documents.pickGate = Completer();
      await press(tester, 'backup-restore');
      expect(container.read(databaseMaintenanceProvider).active, isTrue);
      now = DateTime(2026, 12, 3);
      scheduler.onTap?.call('review');
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/settings',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await container.read(billingSessionProvider.notifier).refresh();
      await container.read(remindersProvider.notifier).refresh();
      await pumpBilling(tester);
      expect(await fingerprint(), before);
      documents.pickGate!.complete(null);
      await pumpBilling(tester);
      expect(container.read(databaseMaintenanceProvider).active, isFalse);
      await container.read(billingSessionProvider.notifier).refresh();
      await pumpBilling(tester);
      expect(await fingerprint(), isNot(before));
    },
  );

  testWidgets(
    'restored opt-in uses actual granted permission and never duplicates IDs',
    (tester) async {
      scheduler.permissionValue = ReminderPermission.granted;
      cipher.source = syntheticBackup();
      await open(tester);
      await preview(tester);
      await press(tester, 'backup-accept-replacement');
      await press(tester, 'backup-replace');
      expect(scheduler.requests, 0);
      expect(scheduler.pending, hasLength(10));
      final ids = scheduler.pending.keys.toSet();
      await container.read(remindersProvider.notifier).rebuildAfterRestore();
      expect(scheduler.pending.keys.toSet(), ids);
      expect(
        (await db.select(db.appSettings).getSingle()).notificationsEnabled,
        isTrue,
      );
    },
  );

  testWidgets(
    'restored opt-in with denied permission stays off without requesting permission',
    (tester) async {
      cipher.source = syntheticBackup();
      await open(tester);
      await preview(tester);
      await press(tester, 'backup-accept-replacement');
      await press(tester, 'backup-replace');
      expect(scheduler.requests, 0);
      expect(scheduler.pending, isEmpty);
      expect(
        (await db.select(db.appSettings).getSingle()).notificationsEnabled,
        isFalse,
      );
      expect(
        (await BackupService(db).capture(now)).records['payments'],
        cipher.source.records['payments'],
      );
    },
  );

  testWidgets(
    'post-commit notification error reports restored data and settings warning, never fake rollback',
    (tester) async {
      scheduler.permissionValue = ReminderPermission.granted;
      scheduler.failScheduleAt = 1;
      cipher.source = syntheticBackup();
      await open(tester);
      await preview(tester);
      await press(tester, 'backup-accept-replacement');
      await press(tester, 'backup-replace');
      expect(find.textContaining('Los datos se restauraron'), findsOneWidget);
      expect(find.textContaining('No se revirtió'), findsOneWidget);
      expect(
        (await BackupService(db).capture(now)).records['payments'],
        cipher.source.records['payments'],
      );
    },
  );

  testWidgets(
    'new selection failure clears the old preview and requires a fresh verification',
    (tester) async {
      await open(tester);
      final before = await fingerprint();
      await preview(tester);
      await press(tester, 'backup-accept-replacement');
      documents.failPick = true;
      await press(tester, 'backup-pick');
      expect(find.byKey(const Key('backup-replace')), findsNothing);
      expect(await fingerprint(), before);
      documents.failPick = false;
      await press(tester, 'backup-pick');
      expect(find.byKey(const Key('backup-password')), findsOneWidget);
      expect(find.byKey(const Key('backup-replace')), findsNothing);
      await press(tester, 'backup-close');
    },
  );

  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'backup forms/preview/errors accessible $width $scale $brightness with keyboard',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            addTearDown(() {
              tester.view.reset();
              tester.platformDispatcher.clearAllTestValues();
            });
            await open(tester);
            await press(tester, 'backup-create');
            tester.view.viewInsets = const FakeViewPadding(bottom: 240);
            await tester.pump();
            await enter(tester, 'backup-password', 'short');
            await enter(tester, 'backup-confirm-password', 'short');
            await reachCommunication(tester, 'backup-save');
            expect(
              tester.getSize(find.byKey(const Key('backup-save'))).height,
              greaterThanOrEqualTo(48),
            );
            await press(tester, 'backup-save');
            expect(
              find.textContaining('al menos 12').evaluate().isNotEmpty,
              isTrue,
            );
            expect(tester.takeException(), isNull);
            await press(tester, 'backup-close');
            await preview(tester);
            await reachCommunication(tester, 'backup-accept-replacement');
            await tester.tap(
              find.byKey(const Key('backup-accept-replacement')),
            );
            await pumpBilling(tester);
            await reachCommunication(tester, 'backup-replace');
            expect(
              tester.getSize(find.byKey(const Key('backup-replace'))).height,
              greaterThanOrEqualTo(48),
            );
            expect(tester.takeException(), isNull);
            await press(tester, 'backup-close');
            tester.view.viewInsets = const FakeViewPadding();
          },
        );
      }
    }
  }
}
