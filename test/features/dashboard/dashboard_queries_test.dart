import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_queries.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/data/client_service.dart';

void main() {
  late AppDatabase db;
  late BillingService billing;
  late PaymentService payments;
  late ClientService clients;
  late BillingQueries queries;
  final today = LocalDate(2026, 12, 3);
  final audit = DateTime(2026, 12, 3, 12);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    billing = BillingService(db);
    payments = PaymentService(db);
    clients = ClientService(db, billing);
    queries = BillingQueries(db, billing, payments);
  });
  tearDown(() => db.close());

  Future<ClientRecord> create(
    String id, {
    int fee = 12345,
    String? name,
    LocalDate? start,
    ServiceStatus status = ServiceStatus.active,
  }) => clients.create(
    id: id,
    fullName: name ?? 'Cliente sintético $id',
    monthlyFeeMinor: fee,
    status: status,
    today: start ?? today,
    recordedAt: audit,
  );
  Future<String> snapshot() async => jsonEncode({
    for (final table in [
      'clients',
      'charges',
      'payments',
      'devices',
      'app_settings',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((row) => row.data)
          .toList(),
  });

  test(
    'Empty and clients without current charges are real read-only states',
    () async {
      var data = await queries.dashboardData(today);
      expect(data.period, BillingPeriod(2026, 12));
      expect(data.totalClients, 0);
      expect(data.billing.summary.activeClients, 0);
      expect(data.billing.summary.totalCharges, 0);
      expect(data.billing.outstandingMinor, 0);
      expect(data.reviewCount, 0);
      expect(data.reviewClients, isEmpty);
      await create('suspended', status: ServiceStatus.suspended);
      final before = await snapshot();
      data = await queries.dashboardData(today);
      expect(data.totalClients, 1);
      expect(data.billing.summary.totalCharges, 0);
      expect(data.billing.summary.activeClients, 0);
      expect(await snapshot(), before);
    },
  );

  test('Current financial totals match T04 including archived/suspended history and old tariffs', () async {
    await create('active', fee: 10101);
    await create('suspended', fee: 20202);
    await create('archived', fee: 30303);
    await clients.changeMonthlyFee(
      'active',
      99999,
      today: today,
      recordedAt: audit,
    );
    await clients.changeStatus(
      'suspended',
      ServiceStatus.suspended,
      today: today,
      recordedAt: audit,
    );
    await clients.changeStatus(
      'archived',
      ServiceStatus.archived,
      today: today,
      recordedAt: audit,
    );
    await payments.register(
      chargeId: 'suspended:2026-12',
      amountMinor: 20202,
      paidAt: audit,
    );
    final voided = await payments.register(
      chargeId: 'archived:2026-12',
      amountMinor: 30303,
      paidAt: audit,
    );
    await payments.voidPayment(voided.id, voidedAt: audit);
    final before = await snapshot();
    final data = await queries.dashboardData(today);
    final period = await queries.periodData(data.period, today);
    expect(data.totalClients, 3);
    expect(data.billing.summary.activeClients, 1);
    expect(data.billing.summary.paidCharges, period.summary.paidCharges);
    expect(data.billing.summary.paidCharges, 1);
    expect(data.billing.summary.unpaidCharges, period.summary.unpaidCharges);
    expect(data.billing.summary.unpaidCharges, 2);
    expect(data.billing.outstandingMinor, period.outstandingMinor);
    expect(data.billing.outstandingMinor, 40404);
    expect(data.reviewCount, 1);
    expect(data.reviewClients.single.id, 'active');
    expect(await snapshot(), before);
  });

  test('Paid current month retains older debt without adding it to the period amount', () async {
    await create('old', start: LocalDate(2026, 11, 2));
    await billing.reconcile(today: today, recordedAt: audit);
    await payments.register(
      chargeId: 'old:2026-12',
      amountMinor: 12345,
      paidAt: audit,
    );
    final data = await queries.dashboardData(today);
    expect(data.billing.summary.paidCharges, 1);
    expect(data.billing.summary.unpaidCharges, 0);
    expect(data.billing.outstandingMinor, 0);
    expect(data.reviewCount, 1);
    expect(data.reviewClients.single.oldestPeriodKey, '2026-11');
    expect((await clients.get('old')).status, 'active');
  });

  test('Review counts distinct active clients and limits preview after stable debt-age ordering', () async {
    await create(
      'oldest',
      name: 'Zeta sintético',
      start: LocalDate(2026, 8, 2),
    );
    for (final id in ['b', 'a', 'f', 'e', 'd', 'c']) {
      await create(
        id,
        name: 'Mismo nombre sintético',
        start: LocalDate(2026, 11, 2),
      );
    }
    await create('manual', start: LocalDate(2026, 7, 2));
    await clients.changeStatus(
      'manual',
      ServiceStatus.suspended,
      today: today,
      recordedAt: audit,
    );
    await create('archive', start: LocalDate(2026, 6, 2));
    await clients.changeStatus(
      'archive',
      ServiceStatus.archived,
      today: today,
      recordedAt: audit,
    );
    await billing.reconcile(today: today, recordedAt: audit);
    final data = await queries.dashboardData(today);
    expect(data.reviewCount, 7);
    expect(data.reviewClients.map((client) => client.id), [
      'oldest',
      'a',
      'b',
      'c',
      'd',
    ]);
    expect(data.reviewClients.first.oldestPeriodKey, '2026-08');
    expect(
      (await queries.dashboardData(today)).reviewClients
          .map((client) => client.id),
      ['oldest', 'a', 'b', 'c', 'd'],
    );
    expect((await clients.get('manual')).status, 'suspended');
    expect((await clients.get('archive')).status, 'archived');
  });

  test('One observable projection reacts to payment, void, profile and manual-state changes', () async {
    await create('watch');
    DashboardData? latest;
    Object? error;
    final subscription = queries
        .watchDashboard(today)
        .listen(
          (data) => latest = data,
          onError: (Object value) => error = value,
        );
    Future<DashboardData> waitFor(bool Function(DashboardData) ready) async {
      for (var attempt = 0; attempt < 200; attempt++) {
        if (error != null) throw error!;
        if (latest != null && ready(latest!)) return latest!;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      throw StateError('La proyección no se actualizó');
    }

    try {
      await waitFor((data) => data.reviewCount == 1);
      final payment = await payments.register(
        chargeId: 'watch:2026-12',
        amountMinor: 12345,
        paidAt: audit,
      );
      final paid = await waitFor(
        (data) => data.billing.summary.paidCharges == 1,
      );
      expect(paid.reviewCount, 0);
      expect(paid.billing.outstandingMinor, 0);
      await payments.voidPayment(payment.id, voidedAt: audit);
      final voided = await waitFor(
        (data) => data.billing.summary.unpaidCharges == 1,
      );
      expect(voided.billing.outstandingMinor, 12345);
      expect(voided.reviewCount, 1);
      await clients.updateContactDetails(
        'watch',
        fullName: 'Nombre sintético actualizado',
        recordedAt: audit,
      );
      await waitFor(
        (data) =>
            data.reviewClients.single.fullName ==
            'Nombre sintético actualizado',
      );
      await clients.changeStatus(
        'watch',
        ServiceStatus.suspended,
        today: today,
        recordedAt: audit,
      );
      final suspended = await waitFor(
        (data) => data.billing.summary.activeClients == 0,
      );
      expect(suspended.reviewCount, 0);
      expect(suspended.billing.summary.unpaidCharges, 1);
    } finally {
      await subscription.cancel();
    }
  });

  for (final dates in [
    (
      LocalDate(2026, 11, 29),
      LocalDate(2026, 11, 30),
      LocalDate(2026, 12, 2),
      LocalDate(2026, 12, 3),
    ),
    (
      LocalDate(2027, 2, 27),
      LocalDate(2027, 2, 28),
      LocalDate(2027, 3, 2),
      LocalDate(2027, 3, 3),
    ),
    (
      LocalDate(2028, 2, 28),
      LocalDate(2028, 2, 29),
      LocalDate(2028, 3, 2),
      LocalDate(2028, 3, 3),
    ),
  ]) {
    test(
      'Dashboard follows T02 cutoff ${dates.$2} and day 3 without writing',
      () async {
        expect(
          (await queries.dashboardData(dates.$1)).period,
          BillingPeriod(dates.$1.year, dates.$1.month),
        );
        await create('cutoff', start: dates.$2);
        final before = await snapshot();
        final opened = await queries.dashboardData(dates.$2);
        expect(opened.period, BillingPeriod(dates.$3.year, dates.$3.month));
        expect(opened.billing.summary.totalCharges, 1);
        expect(opened.reviewCount, 0);
        expect((await queries.dashboardData(dates.$3)).reviewCount, 0);
        expect((await queries.dashboardData(dates.$4)).reviewCount, 1);
        expect(await snapshot(), before);
      },
    );
  }
}
