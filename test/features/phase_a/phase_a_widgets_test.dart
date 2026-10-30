import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';
import 'package:mi_red/features/backups/backup_providers.dart';
import 'package:mi_red/features/backups/backup_service.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/communications/communication_actions.dart';
import 'package:mi_red/features/reminders/reminder_scheduler.dart';
import 'package:mi_red/features/settings/data/settings_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../billing/billing_widgets_test.dart' show pumpBilling;
import '../communications/communication_widgets_test.dart'
    show pressCommunication, reachCommunication;
import '../communications/fake_communication_actions.dart';
import '../reminders/fake_reminder_scheduler.dart';

class ControlledBusinessSettings extends SettingsService {
  ControlledBusinessSettings(super.db);
  bool failRead = false, failSave = false;
  int saves = 0;
  Completer<void>? readGate, saveGate;

  @override
  Stream<SettingsRecord> watch() async* {
    if (readGate != null) await readGate!.future;
    if (failRead) throw StateError('Synthetic read error');
    yield* super.watch();
  }

  @override
  Future<void> update({
    required String businessName,
    required String currencyLabel,
    String? defaultCallingCode,
    bool? notificationsEnabled,
  }) async {
    saves++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Synthetic write error');
    await super.update(
      businessName: businessName,
      currencyLabel: currencyLabel,
      defaultCallingCode: defaultCallingCode,
      notificationsEnabled: notificationsEnabled,
    );
  }
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  late AppDatabase db;
  late ProviderContainer container;
  late ControlledBusinessSettings settings;
  late FakeCommunicationActions actions;
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 12, 3, 12);
    db = AppDatabase(NativeDatabase.memory());
    settings = ControlledBusinessSettings(db);
    actions = FakeCommunicationActions();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clientClockProvider.overrideWithValue(() => now),
        settingsServiceProvider.overrideWithValue(settings),
        communicationActionsProvider.overrideWithValue(actions),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> seed({
    String name = 'Cliente sintético',
    String? phone,
    int fee = 12345,
  }) async {
    await container
        .read(clientServiceProvider)
        .create(
          id: 'phase-a',
          fullName: name,
          monthlyFeeMinor: fee,
          phone: phone,
          today: LocalDate.fromDateTime(now),
          recordedAt: now,
        );
  }

  Future<void> open(WidgetTester tester, String path) async {
    container.read(appRouterProvider).go(path);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await pumpBilling(tester);
  }

  Future<void> route(WidgetTester tester, String path) async {
    container.read(appRouterProvider).go(path);
    await pumpBilling(tester);
  }

  Future<void> press(WidgetTester tester, String key) =>
      pressCommunication(tester, key);
  Future<void> edit(WidgetTester tester, String key, String value) async {
    await reachCommunication(tester, key);
    await tester.enterText(find.byKey(Key(key)), value);
    await pumpBilling(tester);
  }

  String collected(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('dashboard-collected'))).data!;

  testWidgets(
    'Mi negocio route reads, saves and reopens only business fields',
    (tester) async {
      await BackupService(db).markExported(now);
      await open(tester, '/settings');
      await press(tester, 'settings-business');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('business-name')))
            .controller!
            .text,
        'Mi Red',
      );
      await edit(tester, 'business-name', 'Negocio sintético A');
      await edit(tester, 'business-currency', 'Unidad local');
      await edit(tester, 'business-prefix', '+53');
      await press(tester, 'business-save');
      expect(find.textContaining('Cambios guardados.'), findsOneWidget);
      final saved = await settings.read();
      expect(saved.businessName, 'Negocio sintético A');
      expect(saved.currencyLabel, 'Unidad local');
      expect(saved.defaultCallingCode, '+53');
      expect(saved.notificationsEnabled, isFalse);
      expect(saved.lastBackupAt, now.millisecondsSinceEpoch);
      await tester.tap(find.byTooltip('Atrás'));
      await pumpBilling(tester);
      await press(tester, 'settings-business');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('business-currency')))
            .controller!
            .text,
        'Unidad local',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'business validation prevents save and read/write failures offer real retry with fields retained',
    (tester) async {
      settings.failRead = true;
      await open(tester, '/settings/business');
      expect(find.text('No se pudo cargar el negocio'), findsOneWidget);
      settings.failRead = false;
      await tester.tap(find.text('Reintentar'));
      await pumpBilling(tester);
      await edit(tester, 'business-name', ' ');
      await press(tester, 'business-save');
      expect(
        find.text('El nombre del negocio es obligatorio.'),
        findsOneWidget,
      );
      expect(settings.saves, 0);
      await edit(tester, 'business-name', 'Negocio reintentado');
      await edit(tester, 'business-prefix', '53');
      await press(tester, 'business-save');
      expect(find.textContaining('Usa + y'), findsOneWidget);
      expect(settings.saves, 0);
      await edit(tester, 'business-prefix', '+53');
      settings.failSave = true;
      await press(tester, 'business-save');
      expect(find.textContaining('No se pudo guardar.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('business-name')))
            .controller!
            .text,
        'Negocio reintentado',
      );
      settings.failSave = false;
      await press(tester, 'business-save');
      expect((await settings.read()).businessName, 'Negocio reintentado');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'business loading has no editable fake data and double save coalesces while pending',
    (tester) async {
      settings.readGate = Completer<void>();
      await open(tester, '/settings/business');
      expect(find.byKey(const Key('business-name')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      settings.readGate!.complete();
      await pumpBilling(tester);
      await edit(tester, 'business-name', 'Guardado único');
      settings.saveGate = Completer<void>();
      await reachCommunication(tester, 'business-save');
      final point = tester.getCenter(find.byKey(const Key('business-save')));
      await tester.tapAt(point);
      await tester.pump();
      await tester.tapAt(point);
      await pumpBilling(tester);
      expect(settings.saves, 1);
      settings.saveGate!.complete();
      await pumpBilling(tester);
      expect((await settings.read()).businessName, 'Guardado único');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom/empty currency propagates across Home, Clients, history, payment and T06 without inferring recipient',
    (tester) async {
      await seed(phone: '2025550123');
      for (final currency in ['XTA', '']) {
        await settings.update(
          businessName: 'Negocio',
          currencyLabel: currency,
          defaultCallingCode: '+1',
        );
        await open(tester, '/');
        final money = currency.isEmpty ? '123,45' : '123,45 XTA';
        expect(collected(tester), currency.isEmpty ? '0,00' : '0,00 XTA');
        await route(tester, '/clients/phase-a');
        expect(find.textContaining(money), findsWidgets);
        await route(tester, '/billing/clients/phase-a');
        await press(tester, 'pay-phase-a:2026-12');
        expect(find.text(money), findsWidgets);
        await press(tester, 'cancel-payment');
        await press(tester, 'whatsapp-phase-a:2026-12');
        final message = tester
            .widget<TextField>(find.byKey(const Key('whatsapp-message')))
            .controller!
            .text;
        expect(message, contains(money));
        await press(tester, 'whatsapp-open');
        expect(actions.opened, isEmpty);
        expect(find.textContaining('No se puede adivinar'), findsOneWidget);
        await press(tester, 'communication-close');
        await route(tester, '/billing');
        await press(tester, 'billing-share-list');
        await press(tester, 'report-scope-fullPeriod');
        await press(tester, 'report-copy');
        expect(actions.copied.last, contains(money));
        await press(tester, 'communication-close');
        expect((await db.select(db.charges).getSingle()).amountMinor, 12345);
        expect(
          (await db.select(db.clients).getSingle()).monthlyFeeMinor,
          12345,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'correction requires review and confirmation, accepts comma/point, cancellation changes nothing and double confirm writes once',
    (tester) async {
      await seed();
      await open(tester, '/billing/clients/phase-a');
      await press(tester, 'correct-phase-a:2026-12');
      await edit(tester, 'correction-amount', '-1');
      await press(tester, 'correction-review');
      expect(find.byKey(const Key('correction-confirm')), findsNothing);
      await edit(tester, 'correction-amount', '234,56');
      await press(tester, 'correction-review');
      expect(find.text('Nuevo importe: 234,56'), findsOneWidget);
      expect((await db.select(db.charges).getSingle()).amountMinor, 12345);
      await press(tester, 'correction-cancel');
      expect((await db.select(db.charges).getSingle()).amountMinor, 12345);
      await press(tester, 'correct-phase-a:2026-12');
      await edit(tester, 'correction-amount', '234.56');
      await press(tester, 'correction-review');
      await reachCommunication(tester, 'correction-confirm');
      final point = tester.getCenter(
        find.byKey(const Key('correction-confirm')),
      );
      await tester.tapAt(point);
      await tester.tapAt(point);
      await pumpBilling(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await db.select(db.charges).getSingle()).amountMinor, 23456);
      expect((await db.select(db.clients).getSingle()).monthlyFeeMinor, 12345);
      await route(tester, '/');
      expect(collected(tester), '0,00');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paid race and period change reject stale correction; history/paid actions are absent',
    (tester) async {
      await seed();
      await open(tester, '/billing/clients/phase-a');
      await press(tester, 'correct-phase-a:2026-12');
      await edit(tester, 'correction-amount', '200');
      await press(tester, 'correction-review');
      final payment = await container
          .read(paymentServiceProvider)
          .register(
            chargeId: 'phase-a:2026-12',
            amountMinor: 12345,
            paidAt: now,
          );
      await press(tester, 'correction-confirm');
      expect(find.text('El cargo ya tiene un pago vigente.'), findsOneWidget);
      expect((await db.select(db.charges).getSingle()).amountMinor, 12345);
      await press(tester, 'correction-cancel');
      expect(find.byKey(const Key('correct-phase-a:2026-12')), findsNothing);
      await container
          .read(paymentServiceProvider)
          .voidPayment(payment.id, voidedAt: now);
      await pumpBilling(tester);
      await press(tester, 'correct-phase-a:2026-12');
      await edit(tester, 'correction-amount', '200');
      await press(tester, 'correction-review');
      now = DateTime(2026, 12, 30, 12);
      await press(tester, 'correction-confirm');
      expect(
        find.text('Solo se puede corregir el período vigente.'),
        findsOneWidget,
      );
      await press(tester, 'correction-cancel');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpBilling(tester);
      await route(tester, '/billing/clients/phase-a');
      expect(find.byKey(const Key('correct-phase-a:2026-12')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collected updates reactively on payment, void, correction, business save and T07 restore',
    (tester) async {
      await seed();
      await open(tester, '/');
      expect(collected(tester), '0,00');
      await container
          .read(billingServiceProvider)
          .correctChargeAmount(
            chargeId: 'phase-a:2026-12',
            expectedAmountMinor: 12345,
            amountMinor: 2000,
            today: LocalDate.fromDateTime(now),
          );
      await pumpBilling(tester);
      expect(collected(tester), '0,00');
      final payment = await container
          .read(paymentServiceProvider)
          .register(
            chargeId: 'phase-a:2026-12',
            amountMinor: 2000,
            paidAt: now,
          );
      await pumpBilling(tester);
      expect(collected(tester), '20,00');
      await settings.update(businessName: 'Negocio', currencyLabel: 'XTA');
      await pumpBilling(tester);
      expect(collected(tester), '20,00 XTA');
      final snapshot = await BackupService(db).capture(now);
      await container
          .read(paymentServiceProvider)
          .voidPayment(payment.id, voidedAt: now);
      await pumpBilling(tester);
      expect(collected(tester), '0,00 XTA');
      await container.read(backupRestorerProvider)(snapshot);
      await pumpBilling(tester);
      expect(collected(tester), '20,00 XTA');
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'business and correction $width/$scale/$brightness with keyboard, long text and collected metric',
          (tester) async {
            tester.view.physicalSize = Size(width, 640);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetViewInsets);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(
              tester.platformDispatcher.clearPlatformBrightnessTestValue,
            );
            const currency = 'moneda de prueba con etiqueta extensa';
            await seed(
              name: 'Cliente sintético con nombre extenso para revisar la accesibilidad del formulario y sus confirmaciones',
              fee: 123456789012345,
            );
            await open(tester, '/settings/business');
            tester.view.viewInsets = const FakeViewPadding(bottom: 240);
            await edit(
              tester,
              'business-name',
              'Negocio sintético con nombre largo para comprobar el formulario',
            );
            await edit(tester, 'business-currency', currency);
            await edit(tester, 'business-prefix', '+53');
            await press(tester, 'business-save');
            expect(find.textContaining('Cambios guardados.'), findsOneWidget);
            await route(tester, '/billing/clients/phase-a');
            await press(tester, 'correct-phase-a:2026-12');
            await edit(tester, 'correction-amount', '2345678901234,56');
            await press(tester, 'correction-review');
            expect(
              find.text('Nuevo importe: 2345678901234,56 $currency'),
              findsOneWidget,
            );
            await press(tester, 'correction-edit');
            await edit(tester, 'correction-amount', '2345678901234.56');
            await press(tester, 'correction-review');
            await press(tester, 'correction-confirm');
            expect(
              (await db.select(db.charges).getSingle()).amountMinor,
              234567890123456,
            );
            await route(tester, '/');
            await reachCommunication(tester, 'dashboard-collected');
            expect(collected(tester), '0,00 $currency');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
