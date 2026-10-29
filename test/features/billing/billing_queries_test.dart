import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/billing_providers.dart';
import 'package:mi_red/features/billing/billing_values.dart';
import 'package:mi_red/features/billing/data/billing_queries.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/settings/data/settings_service.dart';

class CountingBillingService extends BillingService {
  CountingBillingService(super.db);
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<int> reconcile({
    required LocalDate today,
    DateTime? recordedAt,
  }) async {
    calls++;
    await gate?.future;
    return super.reconcile(today: today, recordedAt: recordedAt);
  }
}

void main() {
  late AppDatabase db;
  late BillingService billing;
  late ClientService clients;
  late PaymentService payments;
  late BillingQueries queries;
  final today = LocalDate(2026, 12, 2);
  final audit = DateTime(2026, 12, 2, 12, 30);
  final december = BillingPeriod(2026, 12);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    billing = BillingService(db);
    clients = ClientService(db, billing);
    payments = PaymentService(db);
    queries = BillingQueries(db, billing, payments);
  });
  tearDown(() => db.close());
  Future<ClientRecord> create(
    String id, {
    String? name,
    int fee = 12550,
    LocalDate? start,
  }) => clients.create(
    id: id,
    fullName: name ?? 'Cliente sintético $id',
    monthlyFeeMinor: fee,
    today: start ?? today,
    recordedAt: audit,
  );

  test('Period projection reads exact snapshots, settings and stable unpaid-first order without writing', () async {
    final alpha = await create('a', name: 'Alfa sintético', fee: 10000);
    await create('c', name: 'beta sintético', fee: 23050);
    await create('b', name: 'Beta sintético', fee: 30000);
    await payments.register(
      chargeId: '${alpha.id}:2026-12',
      amountMinor: 10000,
      paidAt: audit,
    );
    await SettingsService(db).update(
      businessName: 'Prueba',
      currencyLabel: 'unidad',
      notificationsEnabled: false,
    );
    final before = await db.select(db.charges).get();
    final result = await queries.periodData(december, today);
    expect(result.rows.map((row) => row.client.id), ['b', 'c', 'a']);
    expect(result.summary.totalCharges, 3);
    expect(result.summary.paidCharges, 1);
    expect(result.summary.unpaidCharges, 2);
    expect(result.outstandingMinor, 53050);
    expect(result.summary.collectedMinor, 10000);
    expect(result.currencyLabel, 'unidad');
    expect(await db.select(db.charges).get(), before);
    expect(
      (await queries.periodData(BillingPeriod(2025, 1), today)).rows,
      isEmpty,
    );
    expect(await queries.clientData('missing', today), isNull);
  });

  test('Current paid charge retains earlier unpaid debt and manual service status is independent', () async {
    final client = await create('debt', start: LocalDate(2026, 11, 2));
    await billing.reconcile(today: today, recordedAt: audit);
    await clients.changeStatus(
      client.id,
      ServiceStatus.suspended,
      today: today,
    );
    await payments.register(
      chargeId: '${client.id}:2026-12',
      amountMinor: 12550,
      paidAt: audit,
    );
    final row = (await queries.periodData(december, today)).rows.single;
    expect(row.item.status, ChargeStatus.paid);
    expect(row.client.status, 'suspended');
    expect(row.hasPreviousDebt, isTrue);
    final history = (await queries.clientData(client.id, today))!;
    expect(history.charges.first.status, ChargeStatus.suspensionCandidate);
    expect(history.lastValidPayment!.chargeId, '${client.id}:2026-12');
    await payments.register(
      chargeId: '${client.id}:2026-11',
      amountMinor: 12550,
      paidAt: audit,
    );
    expect(
      (await queries.periodData(december, today)).rows.single.hasPreviousDebt,
      isFalse,
    );
  });

  test('Reactive reads follow register, void and replacement, keeping tariff and audit snapshots', () async {
    final client = await create('watch');
    await clients.updateProfile(
      client.id,
      fullName: client.fullName,
      monthlyFeeMinor: 99999,
      status: ServiceStatus.active,
      today: today,
    );
    final iterator = StreamIterator(queries.watchPeriod(december, today));
    try {
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.outstandingMinor, 12550);
      final paid = await payments.register(
        chargeId: '${client.id}:2026-12',
        amountMinor: 12550,
        paidAt: audit,
        note: 'Nota sintética',
      );
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.summary.paidCharges, 1);
      expect(iterator.current.summary.collectedMinor, 12550);
      expect(iterator.current.outstandingMinor, 0);
      final voidedAt = audit.add(const Duration(minutes: 1));
      await payments.voidPayment(paid.id, voidedAt: voidedAt);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.summary.paidCharges, 0);
      expect(iterator.current.outstandingMinor, 12550);
      final history = (await queries.clientData(client.id, today))!;
      expect(history.lastValidPayment, isNull);
      expect(history.payments.single.paidAt, paid.paidAt);
      expect(history.payments.single.note, paid.note);
      expect(history.payments.single.voidedAt, voidedAt.millisecondsSinceEpoch);
      expect(history.client.monthlyFeeMinor, 99999);
      expect(history.charges.single.charge.amountMinor, 12550);
      final replacement = await payments.register(
        chargeId: paid.chargeId,
        amountMinor: 12550,
        paidAt: voidedAt,
      );
      expect(await iterator.moveNext(), isTrue);
      expect(
        (await queries.clientData(client.id, today))!.lastValidPayment!.id,
        replacement.id,
      );
    } finally {
      await iterator.cancel();
    }
  });

  test('Readiness coalesces entries, advances local date and does not recreate inactive months', () async {
    final client = await create('anchor', start: LocalDate(2026, 9, 2));
    await clients.changeStatus(
      client.id,
      ServiceStatus.archived,
      today: LocalDate(2026, 9, 10),
    );
    await clients.changeStatus(client.id, ServiceStatus.active, today: today);
    final service = CountingBillingService(db)..gate = Completer<void>();
    var now = audit;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        billingServiceProvider.overrideWithValue(service),
        clientClockProvider.overrideWithValue(() => now),
      ],
    );
    try {
      final first = container.read(billingSessionProvider.future);
      final second = container.read(billingSessionProvider.notifier).refresh();
      expect(service.calls, 1);
      service.gate!.complete();
      await first;
      await second;
      expect(
        (await db.select(db.charges).get()).map((row) => row.periodKey).toSet(),
        {'2026-09', '2026-12'},
      );
      now = DateTime(2026, 12, 3, 8);
      await container.read(billingSessionProvider.notifier).refresh();
      expect(
        container.read(billingSessionProvider).requireValue,
        LocalDate(2026, 12, 3),
      );
      expect(service.calls, 2);
      final listener = container.listen(
        billingPeriodProvider(december),
        (_, _) {},
      );
      final view = await container.read(billingPeriodProvider(december).future);
      expect(view.rows.single.item.status, ChargeStatus.suspensionCandidate);
      expect(view.rows.single.hasPreviousDebt, isTrue);
      listener.close();
      expect((await db.select(db.charges).get()).length, 2);
    } finally {
      container.dispose();
    }
  });

  test('Failed readiness is visible and retry uses the same transactional T02 engine', () async {
    await create('retry', start: LocalDate(2026, 11, 2));
    await db.customStatement(
      "CREATE TRIGGER test_billing_fail BEFORE INSERT ON charges WHEN NEW.period_key = '2026-12' BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END",
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clientClockProvider.overrideWithValue(() => audit),
      ],
    );
    try {
      await expectLater(
        container.read(billingSessionProvider.future),
        throwsA(isA<SqliteException>()),
      );
      expect(container.read(billingSessionProvider).hasError, isTrue);
      expect((await db.select(db.charges).get()).length, 1);
      await db.customStatement('DROP TRIGGER test_billing_fail');
      await container.read(billingSessionProvider.notifier).refresh();
      expect(container.read(billingSessionProvider).hasValue, isTrue);
      await container.read(billingSessionProvider.notifier).refresh();
      expect((await db.select(db.charges).get()).length, 2);
    } finally {
      container.dispose();
    }
  });

  test('File reopens with valid and voided payments, exact history and derived states', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp('mi_red_t04_');
    final file = File('${directory.path}/billing.sqlite');
    var disk = AppDatabase(NativeDatabase(file));
    try {
      final diskBilling = BillingService(disk);
      final client = await ClientService(disk, diskBilling).create(
        id: 'file',
        fullName: 'Cliente sintético de fichero',
        monthlyFeeMinor: 34567,
        today: today,
        recordedAt: audit,
      );
      final service = PaymentService(disk);
      final first = await service.register(
        chargeId: '${client.id}:2026-12',
        amountMinor: 34567,
        paidAt: audit,
      );
      await service.voidPayment(first.id, voidedAt: audit);
      final current = await service.register(
        chargeId: first.chargeId,
        amountMinor: 34567,
        paidAt: audit,
        note: 'Reemplazo sintético',
      );
      await disk.close();
      disk = AppDatabase(NativeDatabase(file));
      final read = BillingQueries(
        disk,
        BillingService(disk),
        PaymentService(disk),
      );
      final history = (await read.clientData(
        client.id,
        LocalDate(2026, 12, 3),
      ))!;
      expect(history.payments.length, 2);
      expect(
        history.payments.where((payment) => payment.voidedAt != null).length,
        1,
      );
      expect(history.lastValidPayment!.id, current.id);
      expect(history.charges.single.status, ChargeStatus.paid);
      expect((await read.periodData(december, today)).outstandingMinor, 0);
      expect(
        await disk.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await disk.close();
      if (await directory.parent.resolveSymbolicLinks() !=
          await Directory.systemTemp.resolveSymbolicLinks()) {
        throw StateError('Carpeta temporal fuera de la ubicación esperada.');
      }
      await directory.delete(recursive: true);
    }
  });

  test('Period presentation is explicit and navigation is bounded without altering the calendar', () {
    expect(periodLabel(december), 'Diciembre 2026');
    expect(adjacentPeriod(BillingPeriod(2027, 1), -1), december);
    expect(adjacentPeriod(BillingPeriod(1, 1), -1), isNull);
    expect(adjacentPeriod(BillingPeriod(9999, 12), 1), isNull);
    expect(calendarLabel('2026-11-30'), '30/11/2026');
  });
}
