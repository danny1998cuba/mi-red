import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/billing_providers.dart';
import 'package:mi_red/features/billing/data/billing_queries.dart';
import 'package:mi_red/features/clients/client_form_screen.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/dashboard/dashboard_screen.dart';

import '../billing/billing_widgets_test.dart'
    show pumpBilling, pressBilling, reachBillingControl;

class ControlledDashboardQueries extends BillingQueries {
  ControlledDashboardQueries(super.db, super.billing, super.payments);
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<DashboardData> dashboardData(LocalDate today) async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('Fallo sintético de lectura');
    return super.dashboardData(today);
  }
}

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  late AppDatabase db;
  late ProviderContainer container;
  late ControlledDashboardQueries queries;
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 12, 3, 12);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clientClockProvider.overrideWithValue(() => now),
        billingQueriesProvider.overrideWith((ref) {
          queries = ControlledDashboardQueries(
            db,
            ref.watch(billingServiceProvider),
            ref.watch(paymentServiceProvider),
          );
          return queries;
        }),
      ],
    );
    container.read(billingQueriesProvider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<ClientRecord> seed(
    String id, {
    String? name,
    int fee = 12345,
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
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await pumpBilling(tester);
  }

  String metric(WidgetTester tester, String name) =>
      tester.widget<Text>(find.byKey(Key('dashboard-$name'))).data!;
  Future<void> home(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('navigation-home')));
    await pumpBilling(tester);
  }

  Future<void> retry(WidgetTester tester) async {
    final control = find.text('Reintentar');
    await tester.ensureVisible(control);
    await tester.pump();
    await tester.tap(control);
    await pumpBilling(tester);
  }

  testWidgets(
    'Empty dashboard has real zero metrics and opens the existing first-client form',
    (tester) async {
      await open(tester);
      expect(metric(tester, 'active'), '0');
      expect(metric(tester, 'paid'), '0');
      expect(metric(tester, 'unpaid'), '0');
      expect(metric(tester, 'outstanding'), '0,00');
      expect(find.text('Añade tu primer cliente'), findsOneWidget);
      expect(find.text('Pantalla provisional'), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      await tester.ensureVisible(find.text('Añadir cliente'));
      await tester.pump();
      await tester.tap(find.text('Añadir cliente'));
      await pumpBilling(tester);
      expect(find.byType(ClientFormScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await pumpBilling(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect((await db.select(db.clients).get()), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Loading never presents zero metrics as final data', (
    tester,
  ) async {
    await seed('loading');
    queries.gate = Completer<void>();
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('dashboard-active')), findsNothing);
    expect(find.text('Añade tu primer cliente'), findsNothing);
    queries.gate!.complete();
    await pumpBilling(tester);
    expect(metric(tester, 'active'), '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Creating through the first-client action returns to a reactive dashboard and Clients navigation',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('Añadir cliente'));
      await tester.pump();
      await tester.tap(find.text('Añadir cliente'));
      await pumpBilling(tester);
      await tester.enterText(
        find.byKey(const Key('client-name')),
        'Alta sintética desde Inicio',
      );
      await tester.enterText(find.byKey(const Key('client-fee')), '234,56');
      await tester.ensureVisible(find.byKey(const Key('client-save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('client-save')));
      await pumpBilling(tester);
      expect(find.text('Ficha de cliente'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byTooltip('Atrás'));
      await pumpBilling(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(metric(tester, 'active'), '1');
      expect(metric(tester, 'unpaid'), '1');
      expect(metric(tester, 'outstanding'), '234,56');
      await tester.tap(
        find.descendant(
          of: find.byType(FBottomNavigationBar),
          matching: find.text('Clientes'),
        ),
      );
      await pumpBilling(tester);
      expect(find.text('Alta sintética desde Inicio'), findsOneWidget);
      await home(tester);
      expect(metric(tester, 'active'), '1');
      expect((await db.select(db.charges).get()).length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Payment and void through T04 refresh dashboard metrics and review without restarting',
    (tester) async {
      await seed('payment');
      await open(tester);
      expect(metric(tester, 'outstanding'), '123,45');
      await pressBilling(tester, 'review-payment');
      await pressBilling(tester, 'pay-payment:2026-12');
      await pressBilling(tester, 'confirm-payment');
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byTooltip('Atrás'));
      await pumpBilling(tester);
      expect(metric(tester, 'paid'), '1');
      expect(metric(tester, 'unpaid'), '0');
      expect(metric(tester, 'outstanding'), '0,00');
      expect(find.text('Período pagado'), findsOneWidget);
      expect(find.byKey(const Key('review-payment')), findsNothing);
      await pressBilling(tester, 'dashboard-billing');
      await pressBilling(tester, 'billing-charge-payment:2026-12');
      final payment =
          (await container
                  .read(paymentServiceProvider)
                  .historyForClient('payment'))
              .single;
      await pressBilling(tester, 'void-${payment.id}');
      await pressBilling(tester, 'confirm-payment');
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byTooltip('Atrás'));
      await pumpBilling(tester);
      await home(tester);
      expect(metric(tester, 'paid'), '0');
      expect(metric(tester, 'unpaid'), '1');
      expect(metric(tester, 'outstanding'), '123,45');
      expect(find.byKey(const Key('review-payment')), findsOneWidget);
      expect(
        (await container.read(clientServiceProvider).get('payment')).status,
        'active',
      );
      expect((await db.select(db.payments).get()).single.voidedAt, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Paid current month still links to old debt; archived/manual suspension only leave the review queue',
    (tester) async {
      await seed('older', start: LocalDate(2026, 11, 2));
      await container
          .read(billingServiceProvider)
          .reconcile(today: LocalDate.fromDateTime(now), recordedAt: now);
      await container
          .read(paymentServiceProvider)
          .register(chargeId: 'older:2026-12', amountMinor: 12345, paidAt: now);
      await open(tester);
      expect(metric(tester, 'unpaid'), '0');
      expect(metric(tester, 'outstanding'), '0,00');
      expect(find.text('Período pagado'), findsOneWidget);
      expect(find.text('1 cliente activo'), findsOneWidget);
      expect(find.text('Sin pagar desde Noviembre 2026.'), findsOneWidget);
      await pressBilling(tester, 'review-older');
      expect(find.text('Mensualidad seleccionada'), findsOneWidget);
      await reachBillingControl(tester, const Key('pay-older:2026-11'));
      expect(find.text('Noviembre 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Atrás'));
      await pumpBilling(tester);
      await container
          .read(clientServiceProvider)
          .changeStatus(
            'older',
            ServiceStatus.suspended,
            today: LocalDate.fromDateTime(now),
            recordedAt: now,
          );
      await pumpBilling(tester);
      expect(metric(tester, 'active'), '0');
      expect(find.text('0 clientes activos'), findsOneWidget);
      expect((await db.select(db.charges).get()).length, 2);
      await container
          .read(clientServiceProvider)
          .changeStatus(
            'older',
            ServiceStatus.archived,
            today: LocalDate.fromDateTime(now),
            recordedAt: now,
          );
      await pumpBilling(tester);
      expect(metric(tester, 'paid'), '1');
      expect(metric(tester, 'outstanding'), '0,00');
      expect(find.text('0 clientes activos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Quick links use current T02 period and unpaid filter, preserving it through history/back',
    (tester) async {
      now = DateTime(2026, 11, 29, 12);
      await seed('navigation');
      await open(tester);
      expect(find.text('Noviembre 2026'), findsOneWidget);
      await pressBilling(tester, 'dashboard-add-client');
      expect(find.byType(ClientFormScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await pumpBilling(tester);
      now = DateTime(2026, 11, 30, 12);
      await pressBilling(tester, 'dashboard-view-unpaid');
      expect(find.text('Diciembre 2026'), findsOneWidget);
      expect(find.text('Filtros · Pendientes'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await pressBilling(tester, 'billing-charge-navigation:2026-12');
      await tester.tap(find.byTooltip('Atrás'));
      await pumpBilling(tester);
      expect(find.text('Filtros · Pendientes'), findsOneWidget);
      await home(tester);
      expect(find.text('Diciembre 2026'), findsOneWidget);
      expect(metric(tester, 'unpaid'), '1');
      await pressBilling(tester, 'dashboard-refresh');
      await pressBilling(tester, 'dashboard-billing');
      expect(find.text('Filtros · Todos'), findsOneWidget);
      await home(tester);
      expect((await db.select(db.charges).get()).length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Resume updates day 2 to day 3 using the shared clock and never changes service',
    (tester) async {
      now = DateTime(2026, 12, 2, 12);
      await seed('resume');
      await open(tester);
      expect(find.text('0 clientes activos'), findsOneWidget);
      now = DateTime(2026, 12, 3, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpBilling(tester);
      expect(find.text('1 cliente activo'), findsOneWidget);
      expect((await db.select(db.charges).get()).length, 1);
      expect(
        (await container.read(clientServiceProvider).get('resume')).status,
        'active',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Read error offers a real retry without fake metrics or extra charges',
    (tester) async {
      await seed('read');
      queries.fail = true;
      await open(tester);
      expect(find.text('No se pudo actualizar Inicio'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-active')), findsNothing);
      queries.fail = false;
      await retry(tester);
      expect(metric(tester, 'active'), '1');
      expect((await db.select(db.charges).get()).length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reconciliation failure rolls back, then retry and repeated entry never duplicate charges',
    (tester) async {
      await seed('reconcile', start: LocalDate(2026, 11, 2));
      await db.customStatement(
        "CREATE TRIGGER test_dashboard_fail BEFORE INSERT ON charges WHEN NEW.period_key = '2026-12' BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END",
      );
      await open(tester);
      expect(find.text('No se pudo actualizar Inicio'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-active')), findsNothing);
      expect((await db.select(db.charges).get()).length, 1);
      await db.customStatement('DROP TRIGGER test_dashboard_fail');
      await retry(tester);
      expect(metric(tester, 'active'), '1');
      await pressBilling(tester, 'dashboard-refresh');
      await pressBilling(tester, 'dashboard-billing');
      await home(tester);
      expect((await db.select(db.charges).get()).length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Review preview never hides the total and opens the oldest financial history',
    (tester) async {
      for (var index = 0; index < 6; index++) {
        await seed('queue-$index');
      }
      await open(tester);
      expect(find.text('6 clientes activos'), findsOneWidget);
      expect(
        find.text(
          'Mostrando 5 de 6. Revisa también las mensualidades anteriores en Cobros.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('review-queue-4')), findsOneWidget);
      expect(find.byKey(const Key('review-queue-5')), findsNothing);
      await pressBilling(tester, 'dashboard-review-billing');
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/billing',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'Dashboard $width dp/$scale/$brightness supports empty, no charges, paid and long review with keyboard',
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
            await open(tester);
            expect(find.text('Añade tu primer cliente'), findsOneWidget);
            expect(metric(tester, 'active'), '0');
            await seed('matrix', status: ServiceStatus.suspended);
            await pumpBilling(tester);
            expect(find.text('Sin cargos en este período'), findsOneWidget);
            expect(metric(tester, 'unpaid'), '0');
            await container
                .read(settingsServiceProvider)
                .update(
                  businessName: 'Negocio sintético',
                  currencyLabel: 'moneda de prueba con etiqueta extensa',
                  notificationsEnabled: false,
                );
            await container
                .read(clientServiceProvider)
                .changeStatus(
                  'matrix',
                  ServiceStatus.active,
                  today: LocalDate.fromDateTime(now),
                  recordedAt: now,
                );
            await container
                .read(paymentServiceProvider)
                .register(
                  chargeId: 'matrix:2026-12',
                  amountMinor: 12345,
                  paidAt: now,
                );
            await pumpBilling(tester);
            expect(find.text('Período pagado'), findsOneWidget);
            await seed(
              'long',
              name: 'Cliente sintético con un nombre extraordinariamente largo para comprobar la lectura completa del historial',
              fee: 123456789012345,
            );
            await pumpBilling(tester);
            expect(
              metric(tester, 'outstanding'),
              '1234567890123,45 moneda de prueba con etiqueta extensa',
            );
            expect(find.byKey(const Key('review-long')), findsOneWidget);
            tester.view.viewInsets = const FakeViewPadding(bottom: 240);
            await pumpBilling(tester);
            await reachBillingControl(
              tester,
              const Key('dashboard-view-unpaid'),
            );
            final button = find.byKey(const Key('dashboard-view-unpaid'));
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
            await tester.tap(button);
            await pumpBilling(tester);
            expect(find.text('Filtros · Pendientes'), findsOneWidget);
            tester.view.resetViewInsets();
            await pumpBilling(tester);
            await home(tester);
            await pressBilling(tester, 'review-long');
            expect(find.text('Historial de cobros'), findsOneWidget);
            await tester.tap(find.byTooltip('Atrás'));
            await pumpBilling(tester);
            expect(metric(tester, 'unpaid'), '1');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
