import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/communications/communication_actions.dart';
import 'package:mi_red/features/reminders/reminder_plan.dart';
import 'package:mi_red/features/reminders/reminder_scheduler.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../billing/billing_widgets_test.dart' show pumpBilling;
import '../reminders/fake_reminder_scheduler.dart';
import 'fake_communication_actions.dart';

Future<void> reachCommunication(WidgetTester tester, String key) async {
  await pumpBilling(tester);
  final target = find.byKey(Key(key));
  final dialogs = find.byType(Dialog);
  final scope = dialogs.evaluate().isNotEmpty
      ? dialogs.last
      : find.byType(CustomScrollView).evaluate().isNotEmpty
      ? find.byType(CustomScrollView).last
      : find.byType(SingleChildScrollView).last;
  final scroll = find
      .descendant(of: scope, matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump();
  for (var attempt = 0; target.evaluate().isEmpty && attempt < 60; attempt++) {
    final rect = tester.getRect(scroll);
    await tester.dragFrom(
      Offset(rect.left + 4, rect.center.dy),
      const Offset(0, -180),
    );
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> pressCommunication(WidgetTester tester, String key) async {
  await reachCommunication(tester, key);
  await tester.tap(find.byKey(Key(key)));
  await pumpBilling(tester);
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  late AppDatabase db;
  late ProviderContainer container;
  late FakeCommunicationActions actions;
  late FakeReminderScheduler scheduler;
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 12, 3, 12);
    db = AppDatabase(NativeDatabase.memory());
    actions = FakeCommunicationActions();
    scheduler = FakeReminderScheduler();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clientClockProvider.overrideWithValue(() => now),
        communicationActionsProvider.overrideWithValue(actions),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> seed(
    String id, {
    String? name,
    String? phone,
    int fee = 12345,
    LocalDate? start,
  }) async {
    await container
        .read(clientServiceProvider)
        .create(
          id: id,
          fullName: name ?? 'Cliente sintético $id',
          monthlyFeeMinor: fee,
          phone: phone,
          today: start ?? LocalDate.fromDateTime(now),
          recordedAt: now,
        );
  }

  Future<void> open(WidgetTester tester, [String route = '/billing']) async {
    container.read(appRouterProvider).go(route);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await pumpBilling(tester);
  }

  Future<String> snapshot() async => jsonEncode({
    for (final table in [
      'clients',
      'devices',
      'charges',
      'payments',
      'app_settings',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((row) => row.data)
          .toList(),
  });
  Future<void> edit(WidgetTester tester, String key, String text) async {
    await reachCommunication(tester, key);
    await tester.enterText(find.byKey(Key(key)), text);
    await pumpBilling(tester);
  }

  testWidgets(
    'WhatsApp never opens automatically; ambiguous recipient can be corrected temporarily with fallback/copy',
    (tester) async {
      await seed('phone', phone: '2025550123');
      await open(tester, '/billing/clients/phone');
      final before = await snapshot();
      await pressCommunication(tester, 'whatsapp-phone:2026-12');
      expect(actions.opened, isEmpty);
      expect(actions.shared, isEmpty);
      await pressCommunication(tester, 'whatsapp-open');
      expect(actions.opened, isEmpty);
      expect(find.textContaining('No se puede adivinar'), findsOneWidget);
      await edit(tester, 'whatsapp-recipient', '+1 (202) 555-0123');
      const message =
          'Hola, José & Ana + 👋.\nRecordatorio sintético: 123,45 €.';
      await edit(tester, 'whatsapp-message', message);
      await pressCommunication(tester, 'whatsapp-open');
      expect(actions.opened.single.path, '/12025550123');
      expect(actions.opened.single.queryParameters['text'], message);
      expect(
        find.textContaining('No se pudo abrir una aplicación compatible'),
        findsOneWidget,
      );
      await pressCommunication(tester, 'whatsapp-copy');
      expect(actions.copied.single, message);
      await pressCommunication(tester, 'whatsapp-share');
      expect(actions.shared.single, message);
      expect(find.text('Compartir cancelado.'), findsOneWidget);
      expect(
        (await container.read(clientServiceProvider).get('phone')).phone,
        '2025550123',
      );
      expect(await snapshot(), before);
      await pressCommunication(tester, 'communication-close');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A newly paid charge blocks an already-open reminder and paid history hides its action',
    (tester) async {
      await seed('stale', phone: '+12025550123', start: LocalDate(2026, 11, 2));
      await container
          .read(clientServiceProvider)
          .changeMonthlyFee(
            'stale',
            99999,
            today: LocalDate.fromDateTime(now),
            recordedAt: now,
          );
      await open(tester, '/billing/clients/stale?period=2026-11');
      await pressCommunication(tester, 'whatsapp-stale:2026-11');
      final controller = tester
          .widget<TextField>(find.byKey(const Key('whatsapp-message')))
          .controller!;
      expect(controller.text, contains('Noviembre 2026'));
      expect(controller.text, contains('123,45'));
      expect(controller.text, isNot(contains('999,99')));
      await container
          .read(paymentServiceProvider)
          .register(chargeId: 'stale:2026-11', amountMinor: 12345, paidAt: now);
      await pumpBilling(tester);
      await pressCommunication(tester, 'whatsapp-open');
      expect(actions.opened, isEmpty);
      expect(find.textContaining('ya está pagada'), findsOneWidget);
      await pressCommunication(tester, 'communication-close');
      expect(find.byKey(const Key('whatsapp-stale:2026-11')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Duplicate preview/open taps only launch one action and preserve edits after launcher error',
    (tester) async {
      await seed('double', phone: '+12025550123');
      await open(tester, '/billing/clients/double');
      await reachCommunication(tester, 'whatsapp-double:2026-12');
      final preview = tester
          .widget<TextButton>(find.byKey(const Key('whatsapp-double:2026-12')))
          .onPressed!;
      preview();
      preview();
      await pumpBilling(tester);
      expect(find.byType(Dialog), findsOneWidget);
      actions.gate = Completer<void>();
      await reachCommunication(tester, 'whatsapp-open');
      final launch = tester
          .widget<FilledButton>(find.byKey(const Key('whatsapp-open')))
          .onPressed!;
      launch();
      launch();
      await pumpBilling(tester);
      expect(actions.opened.length, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('whatsapp-open')))
            .onPressed,
        isNull,
      );
      actions.gate!.complete();
      await pumpBilling(tester);
      actions.gate = null;
      actions.failOpen = true;
      await pressCommunication(tester, 'whatsapp-open');
      expect(find.textContaining('Fallo sintético de enlace'), findsOneWidget);
      actions.failOpen = false;
      actions.openResult = true;
      await pressCommunication(tester, 'whatsapp-open');
      expect(find.textContaining('no confirma envío ni entrega'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Report scope is explicit, filtered preview matches actual search and full scope includes the paid row',
    (tester) async {
      await seed('a', name: 'Alfa sintético', fee: 10025);
      await seed('b', name: 'Beta sintético', fee: 5075);
      await container
          .read(paymentServiceProvider)
          .register(chargeId: 'a:2026-12', amountMinor: 10025, paidAt: now);
      await open(tester);
      await edit(tester, 'billing-search', 'Beta');
      final before = await snapshot();
      await pressCommunication(tester, 'billing-share-list');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('report-share')))
            .onPressed,
        isNull,
      );
      expect(actions.shared, isEmpty);
      await pressCommunication(tester, 'report-scope-filtered');
      var text = tester
          .widget<SelectableText>(find.byKey(const Key('report-preview')))
          .data!;
      expect(text, contains('Clientes: 1'));
      expect(text, contains('Beta sintético'));
      expect(text, isNot(contains('Alfa sintético')));
      await pressCommunication(tester, 'report-copy');
      expect(actions.copied.single, text);
      await pressCommunication(tester, 'report-scope-fullPeriod');
      text = tester
          .widget<SelectableText>(find.byKey(const Key('report-preview')))
          .data!;
      expect(text, contains('Clientes: 2'));
      expect(text, contains('Alfa sintético — Pagado — 100,25'));
      await pressCommunication(tester, 'report-share');
      expect(actions.shared.single, text);
      expect(find.text('Compartir cancelado.'), findsOneWidget);
      expect(await snapshot(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Report errors can retry and duplicate share taps never open two share sheets',
    (tester) async {
      await seed('share');
      await open(tester);
      await pressCommunication(tester, 'billing-share-list');
      await pressCommunication(tester, 'report-scope-filtered');
      actions.failShare = true;
      await pressCommunication(tester, 'report-share');
      expect(find.text('Fallo sintético de compartir'), findsOneWidget);
      actions.failShare = false;
      actions.gate = Completer<void>();
      await reachCommunication(tester, 'report-share');
      final share = tester
          .widget<FilledButton>(find.byKey(const Key('report-share')))
          .onPressed!;
      share();
      share();
      await pumpBilling(tester);
      expect(actions.shared.length, 2);
      actions.gate!.complete();
      await pumpBilling(tester);
      expect(find.text('Compartir cancelado.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings opt-in handles denied/granted/revoked permission and explicit notification test',
    (tester) async {
      await open(tester, '/settings');
      expect(scheduler.requests, 0);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('reminders-switch')))
            .value,
        isFalse,
      );
      scheduler.requestResult = ReminderPermission.denied;
      await pressCommunication(tester, 'reminders-switch');
      expect(scheduler.requests, 1);
      expect(find.textContaining('Android no concedió'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('reminders-switch')))
            .value,
        isFalse,
      );
      scheduler.requestResult = ReminderPermission.granted;
      await pressCommunication(tester, 'reminders-switch');
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('reminders-switch')))
            .value,
        isTrue,
      );
      await pressCommunication(tester, 'reminders-test');
      expect(scheduler.tests, 1);
      await pressCommunication(tester, 'reminders-permission');
      expect(scheduler.settingsOpened, 1);
      scheduler.permissionValue = ReminderPermission.denied;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpBilling(tester);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('reminders-switch')))
            .value,
        isFalse,
      );
      expect(scheduler.pending, isEmpty);
      expect(scheduler.requests, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cold/live notification opens current unpaid view even when Cobros was showing an older month',
    (tester) async {
      await seed('tap');
      scheduler.launchPayload = ReminderKind.review.name;
      await open(tester, '/');
      expect(find.text('Filtros · Pendientes'), findsOneWidget);
      await pressCommunication(tester, 'billing-previous');
      expect(find.text('Noviembre 2026'), findsOneWidget);
      scheduler.onTap!(ReminderKind.candidates.name);
      await pumpBilling(tester);
      expect(find.text('Diciembre 2026'), findsOneWidget);
      expect(find.text('Filtros · Pendientes'), findsOneWidget);
      expect((await db.select(db.charges).get()).length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'T06 dialogs/settings $width dp/$scale/$brightness keep keyboard, errors and actions reachable',
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
            await seed(
              'matrix',
              name: 'José & Ana · Cliente sintético con un nombre extraordinariamente largo para comprobar la lectura completa',
              fee: 123456789012345,
            );
            await container
                .read(settingsServiceProvider)
                .update(
                  businessName: 'Negocio sintético',
                  currencyLabel: 'moneda de prueba extensa',
                  notificationsEnabled: false,
                );
            await open(tester, '/billing/clients/matrix');
            await pressCommunication(tester, 'whatsapp-matrix:2026-12');
            tester.view.viewInsets = const FakeViewPadding(bottom: 240);
            await edit(
              tester,
              'whatsapp-message',
              'Hola, José & Ana.\nMensaje sintético editable con símbolos: € + #.',
            );
            await pressCommunication(tester, 'whatsapp-open');
            expect(actions.opened, isEmpty);
            final error = find.textContaining('No se puede adivinar');
            expect(error, findsOneWidget);
            expect(tester.getRect(error).bottom, lessThanOrEqualTo(400.1));
            await pressCommunication(tester, 'whatsapp-copy');
            expect(actions.copied.single, contains('José & Ana'));
            await pressCommunication(tester, 'communication-close');
            container.read(appRouterProvider).go('/billing');
            await pumpBilling(tester);
            await pressCommunication(tester, 'billing-share-list');
            await pressCommunication(tester, 'report-scope-filtered');
            await pressCommunication(tester, 'report-share');
            expect(
              actions.shared.single,
              contains('1234567890123,45 moneda de prueba extensa'),
            );
            expect(find.text('Compartir cancelado.'), findsOneWidget);
            await pressCommunication(tester, 'communication-close');
            tester.view.resetViewInsets();
            container.read(appRouterProvider).go('/settings');
            await pumpBilling(tester);
            await pressCommunication(tester, 'reminders-switch');
            expect(
              tester
                  .widget<SwitchListTile>(
                    find.byKey(const Key('reminders-switch')),
                  )
                  .value,
              isTrue,
            );
            await reachCommunication(tester, 'reminders-test');
            expect(
              tester.getSize(find.byKey(const Key('reminders-test'))).height,
              greaterThanOrEqualTo(48),
            );
            await tester.tap(find.byKey(const Key('reminders-test')));
            await pumpBilling(tester);
            expect(scheduler.tests, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
