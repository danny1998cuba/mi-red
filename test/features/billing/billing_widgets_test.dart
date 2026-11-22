import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/billing_providers.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/clients/data/client_service.dart';

Future<void> pumpBilling(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}

Future<void> reachBillingControl(WidgetTester tester, Key key) async {
  await pumpBilling(tester);
  final finder = find.byKey(key);
  final dialogs = find.byType(AlertDialog);
  final scope = dialogs.evaluate().isNotEmpty
      ? dialogs.last
      : find.byType(CustomScrollView).last;
  final scrollable = find
      .descendant(of: scope, matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  for (var attempt = 0; finder.evaluate().isEmpty && attempt < 70; attempt++) {
    final rect = tester.getRect(scrollable);
    await tester.dragFrom(
      Offset(rect.left + 5, rect.center.dy),
      const Offset(0, -200),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
}

Future<void> pressBilling(WidgetTester tester, String key) async {
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  }
  await reachBillingControl(tester, Key(key));
  await tester.tap(find.byKey(Key(key)));
  await pumpBilling(tester);
}

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  late AppDatabase db;
  late ProviderContainer container;
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 12, 2, 12, 30);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clientClockProvider.overrideWithValue(() => now),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<ClientRecord> seed(
    String id, {
    String? name,
    int fee = 12550,
    LocalDate? start,
    ServiceStatus status = ServiceStatus.active,
  }) => container
      .read(clientServiceProvider)
      .create(
        id: id,
        fullName: name ?? 'Cliente sintético $id',
        monthlyFeeMinor: fee,
        today: start ?? LocalDate.fromDateTime(now),
        recordedAt: now,
        status: status,
      );
  Future<void> open(WidgetTester tester, [String path = '/billing']) async {
    container.read(appRouterProvider).go(path);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await pumpBilling(tester);
  }

  Future<void> chooseFilter(WidgetTester tester, String label) async {
    await pressBilling(tester, 'billing-filters');
    final choice = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(choice);
    await tester.pump();
    await tester.tap(choice);
    await pumpBilling(tester);
    await pressBilling(tester, 'billing-filters');
  }

  Future<void> chooseMonths(WidgetTester tester, int count) async {
    await pressBilling(tester, 'payment-month-count');
    final dialog = find.byType(SimpleDialog);
    final option = find.descendant(
      of: dialog,
      matching: find.text('$count mensualidades'),
    );
    await tester.scrollUntilVisible(
      option,
      120,
      scrollable: find.descendant(
        of: dialog,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await pumpBilling(tester);
  }

  testWidgets(
    'P21/P22 reviews two months at 200% in dark mode and voids through group history',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      now = DateTime(2026, 11, 22, 12);
      await seed('group', fee: 1500);
      await open(tester);
      await pressBilling(tester, 'pay-group:2026-11');
      expect(find.text('1 mensualidad'), findsOneWidget);
      await chooseMonths(tester, 2);
      expect(find.byKey(const Key('review-month-2026-11')), findsOneWidget);
      expect(find.byKey(const Key('review-month-2026-12')), findsOneWidget);
      expect(find.text('Anticipo'), findsOneWidget);
      expect(find.textContaining('Total: 30,00'), findsOneWidget);
      expect(await db.select(db.charges).get(), hasLength(1));
      await pressBilling(tester, 'confirm-payment');
      final payments = container.read(paymentServiceProvider);
      final group = (await payments.batchesForClient('group')).single;
      expect(group.payments, hasLength(2));
      container.read(appRouterProvider).go('/billing/clients/group');
      await pumpBilling(tester);
      await pressBilling(tester, 'show-billing-operations');
      await pressBilling(tester, 'group-detail-${group.batch.id}');
      await pressBilling(tester, 'void-payment-batch');
      expect(find.text('Confirmar anulación'), findsOneWidget);
      expect(find.textContaining('Importe a anular: 30,00'), findsOneWidget);
      await pressBilling(tester, 'confirm-void-batch');
      expect(
        (await payments.batchesForClient('group')).single.batch.voidedAt,
        isNotNull,
      );
      expect(
        find.byKey(ValueKey('void-${group.payments.first.payment.id}')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'P15 grouped payment warns for suspended service and hides the entry for archived clients',
    (tester) async {
      await seed('held', status: ServiceStatus.suspended);
      await seed('archived-group', status: ServiceStatus.archived);
      await open(tester, '/billing/clients/held');
      await pressBilling(tester, 'pay-months');
      await chooseMonths(tester, 2);
      expect(
        find.text('El servicio está suspendido. El cobro mantiene ese estado.'),
        findsOneWidget,
      );
      await pressBilling(tester, 'confirm-payment');
      expect(
        (await container.read(clientServiceProvider).get('held')).status,
        'suspended',
      );
      container.read(appRouterProvider).go('/billing/clients/archived-group');
      await pumpBilling(tester);
      expect(find.text('Servicio: archivado'), findsOneWidget);
      expect(find.byKey(const Key('pay-months')), findsNothing);
    },
  );

  testWidgets(
    'T09.1 320 dp and 200% review twelve, confirm and void one member',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      now = DateTime(2026, 11, 22, 12);
      await seed('dozen', fee: 1500);
      await open(tester, '/billing/clients/dozen?period=2026-11');
      await pressBilling(tester, 'pay-dozen:2026-11');
      await chooseMonths(tester, 12);
      expect(find.text('Total: 180,00'), findsOneWidget);
      await reachBillingControl(tester, const Key('review-month-2027-10'));
      expect(
        find.text('Próxima mensualidad pendiente: Noviembre 2027.'),
        findsOneWidget,
      );
      await pressBilling(tester, 'confirm-payment');
      await pressBilling(tester, 'show-billing-operations');
      final service = container.read(paymentServiceProvider);
      final group = (await service.batchesForClient('dozen')).single;
      await pressBilling(tester, 'group-detail-${group.batch.id}');
      await pressBilling(tester, 'void-member-${group.payments[1].payment.id}');
      expect(find.text('Diciembre 2026 · 15,00'), findsOneWidget);
      expect(find.text('Importe a anular: 15,00'), findsOneWidget);
      await pressBilling(tester, 'confirm-void-batch');
      expect(
        (await service.batchesForClient('dozen')).single.active,
        hasLength(11),
      );
      expect(find.text('Parcialmente anulado'), findsWidgets);
      expect(find.text('Importe vigente: 165,00 · 11 vigentes'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T09.1 stale review refreshes the total and requires another confirmation',
    (tester) async {
      now = DateTime(2026, 11, 22, 12);
      await seed('stale', fee: 1500);
      await open(tester);
      await pressBilling(tester, 'pay-stale:2026-11');
      await chooseMonths(tester, 2);
      expect(find.text('Total: 30,00'), findsOneWidget);
      await container
          .read(billingServiceProvider)
          .correctChargeAmount(
            chargeId: 'stale:2026-11',
            expectedAmountMinor: 1500,
            amountMinor: 1200,
            today: LocalDate.fromDateTime(now),
          );
      await pressBilling(tester, 'confirm-payment');
      expect(find.text('Total: 27,00'), findsOneWidget);
      expect(
        find.textContaining('Revisa la selección actualizada'),
        findsOneWidget,
      );
      expect(await db.select(db.payments).get(), isEmpty);
      await pressBilling(tester, 'confirm-payment');
      expect(
        (await db.select(db.paymentBatches).get()).single.totalMinor,
        2700,
      );
    },
  );

  testWidgets(
    'T09.1 changing selected period recomposes monthly sections without writes',
    (tester) async {
      now = DateTime(2026, 11, 22, 12);
      await seed('order', start: LocalDate(2026, 8, 12));
      final service = container.read(paymentServiceProvider);
      final quote = await service.previewBatch('order', now, count: 7);
      await service.registerBatch(quote, paidAt: now);
      final before = await db.select(db.charges).get();
      await open(tester, '/billing/clients/order?period=2026-11');

      Future<double> position(String period) async {
        final key = Key('history-month-$period');
        await reachBillingControl(tester, key);
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        return scroll.position.pixels + tester.getTopLeft(find.byKey(key)).dy;
      }

      Future<void> order(List<String> chronological) async {
        var prior = -1e9;
        for (final key in chronological) {
          final offset = await position(key);
          expect(offset, greaterThan(prior), reason: key);
          prior = offset;
        }
      }

      await order([
        '2026-11',
        '2026-12',
        '2027-01',
        '2027-02',
        '2026-10',
        '2026-09',
        '2026-08',
      ]);
      await pressBilling(tester, 'client-history-period');
      await tester.tap(find.text('Enero 2027').last);
      await pumpBilling(tester);
      await order([
        '2027-01',
        '2027-02',
        '2026-12',
        '2026-11',
        '2026-10',
        '2026-09',
        '2026-08',
      ]);
      await pressBilling(tester, 'client-history-period');
      await tester.tap(find.text('Octubre 2026').last);
      await pumpBilling(tester);
      await order([
        '2026-10',
        '2026-11',
        '2026-12',
        '2027-01',
        '2027-02',
        '2026-09',
        '2026-08',
      ]);
      expect(await db.select(db.charges).get(), before);
      expect(await db.select(db.payments).get(), hasLength(7));
    },
  );

  testWidgets(
    'T09.1 operations follow recording time and return to the selected month',
    (tester) async {
      now = DateTime(2026, 11, 22, 12);
      await seed('operations');
      final service = container.read(paymentServiceProvider);
      final old = await service.previewBatch('operations', now, count: 4);
      await service.registerBatch(old, paidAt: now);
      final original = (await service.batchesForClient('operations')).single;
      now = now.add(const Duration(minutes: 30));
      for (final row in original.payments.take(2)) {
        await service.voidPayment(
          row.payment.id,
          voidedAt: now,
          expectedBatchId: old.id,
          expectedClientId: 'operations',
        );
      }
      final latest = await service.previewBatch('operations', now, count: 2);
      await service.registerBatch(latest, paidAt: now);
      await open(tester, '/billing/clients/operations?period=2027-01');
      await pressBilling(tester, 'show-billing-operations');
      Future<double> offset(String id) async {
        final key = Key('operation-$id');
        await reachBillingControl(tester, key);
        return tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .pixels +
            tester.getTopLeft(find.byKey(key)).dy;
      }

      expect(await offset(latest.id), lessThan(await offset(old.id)));
      await pressBilling(tester, 'group-detail-${old.id}');
      final rows = original.payments
          .map((row) => find.byKey(ValueKey('batch-member-${row.payment.id}')))
          .toList();
      for (var i = 1; i < rows.length; i++) {
        expect(
          tester.getTopLeft(rows[i]).dy,
          greaterThan(tester.getTopLeft(rows[i - 1]).dy),
        );
      }
      await tester.tap(find.text('Cerrar'));
      await pumpBilling(tester);
      await pressBilling(tester, 'show-billing-operations');
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('client-history-period')),
            )
            .value,
        '2027-01',
      );
    },
  );

  testWidgets(
    'Period controls load real charges, previous empty month and idempotent repeated entries',
    (tester) async {
      await seed('month');
      await open(tester);
      expect(find.text('Diciembre 2026'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('billing-next')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('summary-Clientes con cargo')))
            .data,
        '1',
      );
      expect(find.byType(ChoiceChip), findsNothing);
      await pressBilling(tester, 'billing-previous');
      expect(find.text('Noviembre 2026'), findsOneWidget);
      expect(find.text('No hay cargos en este período'), findsOneWidget);
      await pressBilling(tester, 'billing-next');
      await pressBilling(tester, 'billing-refresh');
      expect((await db.select(db.charges).get()).length, 1);
      await pressBilling(tester, 'billing-previous');
      await pressBilling(tester, 'billing-current');
      expect(find.text('Diciembre 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Search combines with collapsed filters and survives the contextual history return',
    (tester) async {
      final alpha = await seed('alpha', name: 'Alfa sintético');
      final beta = await seed('beta', name: 'Beta sintético');
      await container
          .read(paymentServiceProvider)
          .register(
            chargeId: '${beta.id}:2026-12',
            amountMinor: 12550,
            paidAt: now,
          );
      await open(tester);
      await chooseFilter(tester, 'Pendientes');
      await reachBillingControl(tester, const Key('billing-search'));
      await tester.enterText(find.byKey(const Key('billing-search')), 'ALFA');
      await pumpBilling(tester);
      await reachBillingControl(
        tester,
        Key('billing-charge-${alpha.id}:2026-12'),
      );
      expect(find.text('Alfa sintético'), findsOneWidget);
      expect(find.text('Beta sintético'), findsNothing);
      await tester.tap(find.text('Alfa sintético'));
      await pumpBilling(tester);
      expect(find.text('Historial de cobros'), findsOneWidget);
      await tester.tap(find.byTooltip('Atrás'));
      await pumpBilling(tester);
      await reachBillingControl(tester, const Key('billing-search'));
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('billing-search')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'ALFA',
      );
      expect(find.text('Filtros · Pendientes'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await pressBilling(tester, 'billing-filters');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Pendientes'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Complete payment confirms once and updates the list and exact total reactively',
    (tester) async {
      final client = await seed('pay');
      await open(tester);
      await reachBillingControl(tester, Key('pay-${client.id}:2026-12'));
      final pay = tester.widget<FilledButton>(
        find.byKey(Key('pay-${client.id}:2026-12')),
      );
      pay.onPressed!();
      pay.onPressed!();
      await pumpBilling(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('payment-note')),
        'Pago sintético completo',
      );
      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('confirm-payment')),
      );
      confirm.onPressed!();
      confirm.onPressed!();
      await pumpBilling(tester);
      final payments = await db.select(db.payments).get();
      expect(payments.length, 1);
      expect(payments.single.amountMinor, 12550);
      expect(payments.single.note, 'Pago sintético completo');
      expect(find.byType(AlertDialog), findsNothing);
      await reachBillingControl(tester, const Key('summary-Pagados'));
      expect(
        tester.widget<Text>(find.byKey(const Key('summary-Pagados'))).data,
        '1',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('summary-Por cobrar'))).data,
        '0,00',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Void cancellation preserves payment; confirmed void keeps audit and updates summary',
    (tester) async {
      final client = await seed('void');
      final paid = await container
          .read(paymentServiceProvider)
          .register(
            chargeId: '${client.id}:2026-12',
            amountMinor: 12550,
            paidAt: now,
            note: 'Nota histórica',
          );
      await open(tester);
      await reachBillingControl(
        tester,
        Key('billing-charge-${client.id}:2026-12'),
      );
      await tester.tap(find.text(client.fullName));
      await pumpBilling(tester);
      await pressBilling(tester, 'void-${paid.id}');
      await pressBilling(tester, 'cancel-payment');
      expect((await db.select(db.payments).get()).single.voidedAt, isNull);
      await pressBilling(tester, 'void-${paid.id}');
      await pressBilling(tester, 'confirm-payment');
      expect((await db.select(db.payments).get()).single.paidAt, paid.paidAt);
      expect(
        (await db.select(db.payments).get()).single.voidedAt,
        now.millisecondsSinceEpoch,
      );
      await reachBillingControl(tester, Key('pay-${client.id}:2026-12'));
      expect(find.text('Pago anulado'), findsOneWidget);
      expect(find.text('Nota: Nota histórica'), findsOneWidget);
      await reachBillingControl(tester, const Key('payment-history-status'));
      expect(find.text('Sin pagos vigentes'), findsOneWidget);
      await tester.tap(find.byTooltip('Atrás'));
      await pumpBilling(tester);
      await reachBillingControl(tester, const Key('summary-Por cobrar'));
      expect(
        tester.widget<Text>(find.byKey(const Key('summary-Por cobrar'))).data,
        '125,50',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('summary-Pagados'))).data,
        '0',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Paid current month shows older debt and never equates manual suspension with an unpaid charge',
    (tester) async {
      final client = await seed('past', start: LocalDate(2026, 11, 2));
      await container
          .read(billingServiceProvider)
          .reconcile(today: LocalDate.fromDateTime(now));
      await container
          .read(clientServiceProvider)
          .changeStatus(
            client.id,
            ServiceStatus.suspended,
            today: LocalDate.fromDateTime(now),
          );
      await container
          .read(paymentServiceProvider)
          .register(
            chargeId: '${client.id}:2026-12',
            amountMinor: 12550,
            paidAt: now,
          );
      await open(tester);
      await reachBillingControl(
        tester,
        Key('billing-charge-${client.id}:2026-12'),
      );
      expect(find.text('Pagado'), findsOneWidget);
      expect(find.text('Servicio: suspendido'), findsOneWidget);
      expect(
        find.text('Tiene mensualidades anteriores sin pagar.'),
        findsOneWidget,
      );
      await chooseFilter(tester, 'Posible suspensión');
      expect(find.text('No hay coincidencias'), findsOneWidget);
      await chooseFilter(tester, 'Pagados');
      await reachBillingControl(
        tester,
        Key('billing-charge-${client.id}:2026-12'),
      );
      await tester.tap(find.text(client.fullName));
      await pumpBilling(tester);
      await reachBillingControl(tester, Key('pay-${client.id}:2026-11'));
      expect(find.text('Candidato a suspensión'), findsOneWidget);
      expect(
        (await container.read(clientServiceProvider).get(client.id)).status,
        'suspended',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tariff edits do not change the amount displayed and paid for an existing charge',
    (tester) async {
      final client = await seed('fee', fee: 12345);
      await container
          .read(clientServiceProvider)
          .updateProfile(
            client.id,
            fullName: client.fullName,
            monthlyFeeMinor: 99999,
            status: ServiceStatus.active,
            today: LocalDate.fromDateTime(now),
          );
      await container
          .read(settingsServiceProvider)
          .update(
            businessName: 'Prueba',
            currencyLabel: 'unidad',
            notificationsEnabled: false,
          );
      await open(tester);
      await pressBilling(tester, 'pay-${client.id}:2026-12');
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('123,45 unidad'),
        ),
        findsOneWidget,
      );
      await pressBilling(tester, 'confirm-payment');
      expect((await db.select(db.payments).get()).single.amountMinor, 12345);
      expect((await db.select(db.charges).get()).single.amountMinor, 12345);
      expect(
        (await container.read(clientServiceProvider).get(client.id))
            .monthlyFeeMinor,
        99999,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Write errors remain reachable at 200 percent and retain the note for a safe retry',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final client = await seed(
        'error',
        name: 'Cliente sintético con un nombre muy largo para comprobar el desplazamiento del error',
      );
      await db.customStatement(
        "CREATE TRIGGER test_payment_fail BEFORE INSERT ON payments BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END",
      );
      await open(tester);
      await pressBilling(tester, 'pay-${client.id}:2026-12');
      await reachBillingControl(tester, const Key('payment-note'));
      await tester.enterText(
        find.byKey(const Key('payment-note')),
        'Nota conservada',
      );
      await pressBilling(tester, 'confirm-payment');
      final error = find.text(
        'No se pudo registrar el pago. Tu nota sigue aquí; vuelve a intentarlo.',
      );
      expect(error, findsOneWidget);
      expect(tester.getRect(error).bottom, lessThanOrEqualTo(640));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('payment-note')))
            .controller!
            .text,
        'Nota conservada',
      );
      expect(await db.select(db.payments).get(), isEmpty);
      await db.customStatement('DROP TRIGGER test_payment_fail');
      await pressBilling(tester, 'confirm-payment');
      expect(
        (await db.select(db.payments).get()).single.note,
        'Nota conservada',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Archived interval stays empty after reactivation and repeated UI reconciliation',
    (tester) async {
      final client = await seed('archive', start: LocalDate(2026, 9, 2));
      await container
          .read(clientServiceProvider)
          .changeStatus(
            client.id,
            ServiceStatus.archived,
            today: LocalDate(2026, 9, 10),
          );
      await container
          .read(clientServiceProvider)
          .changeStatus(
            client.id,
            ServiceStatus.active,
            today: LocalDate.fromDateTime(now),
          );
      await open(tester);
      await pressBilling(tester, 'billing-previous');
      expect(find.text('Noviembre 2026'), findsOneWidget);
      expect(find.text('No hay cargos en este período'), findsOneWidget);
      await pressBilling(tester, 'billing-previous');
      expect(find.text('Octubre 2026'), findsOneWidget);
      expect(find.text('No hay cargos en este período'), findsOneWidget);
      await pressBilling(tester, 'billing-current');
      await pressBilling(tester, 'billing-refresh');
      expect(
        (await db.select(db.charges).get()).map((row) => row.periodKey).toSet(),
        {'2026-09', '2026-12'},
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'App startup and foreground resume reconcile through T02 and refresh day-3 states',
    (tester) async {
      final client = await seed('resume', start: LocalDate(2026, 11, 2));
      await open(tester, '/');
      expect((await db.select(db.charges).get()).length, 2);
      now = DateTime(2026, 12, 3, 9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpBilling(tester);
      expect(
        container.read(billingSessionProvider).requireValue,
        LocalDate(2026, 12, 3),
      );
      container.read(appRouterProvider).go('/billing');
      await pumpBilling(tester);
      await reachBillingControl(
        tester,
        Key('billing-charge-${client.id}:2026-12'),
      );
      expect(find.text('Candidato a suspensión'), findsOneWidget);
      expect((await db.select(db.charges).get()).length, 2);
      expect(
        (await container.read(clientServiceProvider).get(client.id)).status,
        'active',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'Billing and history at $width dp, text $scale and $brightness keep actions reachable',
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
            final client = await seed(
              'layout',
              name: 'Cliente sintético con un nombre considerablemente largo para una pantalla pequeña',
            );
            await container
                .read(settingsServiceProvider)
                .update(
                  businessName: 'Prueba',
                  currencyLabel: 'unidad de prueba',
                  notificationsEnabled: false,
                );
            await open(tester);
            await reachBillingControl(tester, const Key('billing-search'));
            await tester.enterText(
              find.byKey(const Key('billing-search')),
              'sintético',
            );
            tester.view.viewInsets = const FakeViewPadding(bottom: 240);
            await pumpBilling(tester);
            await pressBilling(tester, 'pay-${client.id}:2026-12');
            tester.view.resetViewInsets();
            await pumpBilling(tester);
            await pressBilling(tester, 'cancel-payment');
            await reachBillingControl(
              tester,
              Key('billing-charge-${client.id}:2026-12'),
            );
            await tester.tap(find.text(client.fullName));
            await pumpBilling(tester);
            await pressBilling(tester, 'pay-${client.id}:2026-12');
            await pressBilling(tester, 'cancel-payment');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
