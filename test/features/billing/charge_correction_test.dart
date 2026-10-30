import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/backups/backup_service.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_queries.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/client_values.dart';
import 'package:mi_red/features/clients/data/client_service.dart';

void main() {
  late AppDatabase db;
  late BillingService billing;
  late PaymentService payments;
  final today = LocalDate(2026, 12, 3);
  final now = DateTime(2026, 12, 3, 12);
  void connect(AppDatabase database) {
    db = database;
    billing = BillingService(db);
    payments = PaymentService(db);
  }

  setUp(() => connect(AppDatabase(NativeDatabase.memory())));
  tearDown(() => db.close());
  Future<void> seed() async {
    await ClientService(db, billing).create(
      id: 'synthetic',
      fullName: 'Cliente sintético',
      monthlyFeeMinor: 1000,
      today: LocalDate(2026, 11, 3),
      recordedAt: now,
    );
    await billing.reconcile(today: today, recordedAt: now);
  }

  Future<void> correct({
    String id = 'synthetic:2026-12',
    int expected = 1000,
    int amount = 2000,
    LocalDate? date,
  }) => billing.correctChargeAmount(
    chargeId: id,
    expectedAmountMinor: expected,
    amountMinor: amount,
    today: date ?? today,
  );
  Future<String> fingerprint() async =>
      jsonEncode((await BackupService(db).capture(now)).records);
  Future<Object?> outcome(Future<dynamic> future) async {
    try {
      await future;
      return null;
    } catch (error) {
      return error;
    }
  }

  test('correction survives reopening and reconciliation; voided payment and all other fields remain exact', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp(
      'mi-red-correction-',
    );
    final file = File('${directory.path}/correction.sqlite');
    connect(AppDatabase(NativeDatabase(file)));
    await seed();
    final payment = await payments.register(
      id: 'voided',
      chargeId: 'synthetic:2026-12',
      amountMinor: 1000,
      paidAt: now,
      note: 'Nota de auditoría sintética',
    );
    await payments.voidPayment(
      payment.id,
      voidedAt: now.add(const Duration(hours: 1)),
    );
    final before = jsonDecode(await fingerprint()) as Map<String, dynamic>;
    await correct();
    final rows = before['charges'] as List<dynamic>;
    (rows.singleWhere((dynamic row) => row['id'] == 'synthetic:2026-12')
            as Map<String, dynamic>)['amount_minor'] =
        2000;
    expect(jsonDecode(await fingerprint()), before);
    expect(await billing.reconcile(today: today, recordedAt: now), 0);
    await db.close();
    connect(AppDatabase(NativeDatabase(file)));
    expect(jsonDecode(await fingerprint()), before);
    expect(
      (await payments.historyForCharge('synthetic:2026-12')).single.amountMinor,
      1000,
    );
    expect((await db.select(db.clients).getSingle()).monthlyFeeMinor, 1000);
    expect(await billing.reconcile(today: today), 0);
    expect((await db.customSelect('PRAGMA foreign_key_check').get()), isEmpty);
    await db.close();
    await directory.delete(recursive: true);
  });

  for (final invalid in [
    'missing',
    'historical',
    'future',
    'paid',
    'negative',
    'stale',
    'same',
  ]) {
    test('reject $invalid correction before changing any table', () async {
      await seed();
      if (invalid == 'paid') {
        await payments.register(
          chargeId: 'synthetic:2026-12',
          amountMinor: 1000,
          paidAt: now,
        );
      }
      final before = await fingerprint();
      final operation = switch (invalid) {
        'missing' => correct(id: 'missing'),
        'historical' => correct(id: 'synthetic:2026-11'),
        'future' => correct(date: LocalDate(2026, 11, 29)),
        'negative' => correct(amount: -1),
        'stale' => correct(expected: 999),
        'same' => correct(amount: 1000),
        _ => correct(),
      };
      await expectLater(
        operation,
        invalid == 'negative' ? throwsArgumentError : throwsStateError,
      );
      expect(await fingerprint(), before);
    });
  }

  test('two confirmations of the same original amount apply once and reject stale replay', () async {
    await seed();
    final results = await Future.wait([
      outcome(correct()),
      outcome(correct(amount: 3000)),
    ]);
    expect(results.where((value) => value == null), hasLength(1));
    expect(results.whereType<StateError>(), hasLength(1));
    expect(
      (await db.select(db.charges).get())
          .singleWhere((row) => row.periodKey == '2026-12')
          .amountMinor,
      2000,
    );
  });

  for (final paymentFirst in [true, false]) {
    test(
      'payment/correction race serializes safely, payment first: $paymentFirst',
      () async {
        await seed();
        Future<Object?> pay() => outcome(
          payments.register(
            chargeId: 'synthetic:2026-12',
            amountMinor: 1000,
            paidAt: now,
          ),
        );
        final operations = paymentFirst
            ? [pay(), outcome(correct())]
            : [outcome(correct()), pay()];
        final results = await Future.wait(operations);
        expect(results.where((result) => result == null), hasLength(1));
        final charge = (await db.select(db.charges).get()).singleWhere(
          (row) => row.periodKey == '2026-12',
        );
        final history = await payments.historyForCharge(charge.id);
        expect(charge.amountMinor, paymentFirst ? 1000 : 2000);
        expect(history.length, paymentFirst ? 1 : 0);
        if (history.isNotEmpty) {
          expect(history.single.amountMinor, charge.amountMinor);
        }
      },
    );
  }

  test(
    'real SQL failure after partial trigger work rolls back all tables',
    () async {
      await seed();
      final before = await fingerprint();
      await db.customStatement(
        "CREATE TRIGGER synthetic_correction_failure AFTER UPDATE OF amount_minor ON charges BEGIN UPDATE clients SET monthly_fee_minor=777; SELECT RAISE(ABORT, 'Synthetic rollback'); END",
      );
      await expectLater(correct(), throwsA(isA<Exception>()));
      expect(await fingerprint(), before);
      await db.customStatement('DROP TRIGGER synthetic_correction_failure');
      await correct();
      expect((await db.select(db.clients).getSingle()).monthlyFeeMinor, 1000);
    },
  );

  test('int64 boundary and month rollover use existing integer parser and period rules', () async {
    await seed();
    expect(
      () => parseMoneyMinor('92233720368547758.08'),
      throwsFormatException,
    );
    await correct(amount: parseMoneyMinor('92233720368547758,07'));
    final charge = (await db.select(db.charges).get()).singleWhere(
      (row) => row.periodKey == '2026-12',
    );
    expect(charge.amountMinor, maxAmountMinor);
    await correct(
      expected: maxAmountMinor,
      amount: 0,
      date: LocalDate(2026, 11, 30),
    );
    await expectLater(
      correct(expected: 0, amount: 100, date: LocalDate(2026, 12, 30)),
      throwsStateError,
    );
  });

  test('collected projection matches current active payments through correction, payment, void and T07 restore', () async {
    await seed();
    final clients = ClientService(db, billing);
    await clients.create(
      id: 'archived',
      fullName: 'Cliente archivado sintético',
      monthlyFeeMinor: 3000,
      today: today,
      recordedAt: now,
    );
    await payments.register(
      chargeId: 'archived:2026-12',
      amountMinor: 3000,
      paidAt: now,
    );
    await clients.changeStatus(
      'archived',
      ServiceStatus.archived,
      today: today,
      recordedAt: now,
    );
    await payments.register(
      chargeId: 'synthetic:2026-11',
      amountMinor: 1000,
      paidAt: now,
    );
    await clients.changeMonthlyFee(
      'synthetic',
      99999,
      today: today,
      recordedAt: now,
    );
    final queries = BillingQueries(db, billing, payments);
    Future<void> expectCollected(int expected) async {
      final dashboard = await queries.dashboardData(today);
      final period = await queries.periodData(currentPeriod(today), today);
      expect(dashboard.billing.summary.collectedMinor, expected);
      expect(period.summary.collectedMinor, expected);
    }

    await expectCollected(3000);
    await correct();
    await expectCollected(3000);
    final payment = await payments.register(
      chargeId: 'synthetic:2026-12',
      amountMinor: 2000,
      paidAt: now,
    );
    await expectCollected(5000);
    final snapshot = await BackupService(db).capture(now);
    await payments.voidPayment(payment.id, voidedAt: now);
    await expectCollected(3000);
    await BackupService(db).restore(snapshot);
    await expectCollected(5000);
  });
}
