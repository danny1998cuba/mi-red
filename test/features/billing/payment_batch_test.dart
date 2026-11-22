import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_queries.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/communications/communication_text.dart';

void main() {
  final november = DateTime(2026, 11, 22, 12);
  final december = DateTime(2026, 12, 3, 12);
  late AppDatabase db;
  late PaymentService payments;
  late BillingService billing;
  late ClientService clients;
  late BillingQueries queries;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    payments = PaymentService(db);
    billing = BillingService(db);
    clients = ClientService(db, billing);
    queries = BillingQueries(db, billing, payments);
  });
  tearDown(() => db.close());

  Future<void> seed({
    DateTime? date,
    ServiceStatus status = ServiceStatus.active,
    String id = 'qa',
    int fee = 1500,
  }) => clients.create(
    id: id,
    fullName: 'Cliente sintético $id',
    monthlyFeeMinor: fee,
    today: LocalDate.fromDateTime(date ?? november),
    recordedAt: date ?? november,
    status: status,
  );

  Future<BatchQuote> quote([DateTime? date, int count = 2]) =>
      payments.previewBatch('qa', date ?? november, count: count);
  Future<BatchHistory> group(String id) async =>
      (await payments.batchesForClient('qa'))
          .singleWhere((row) => row.batch.id == id);
  Set<String> activeIds(BatchHistory history) =>
      history.active.map((row) => row.payment.id).toSet();
  Future<void> voidMember(BatchHistory history, int index, DateTime when) =>
      payments.voidPayment(
        history.payments[index].payment.id,
        voidedAt: when,
        expectedBatchId: history.batch.id,
        expectedClientId: history.batch.clientId,
      );
  Future<void> individual(String key) async {
    final charge = await (db.select(
      db.charges,
    )..where((c) => c.periodKey.equals(key))).getSingle();
    await payments.register(
      chargeId: charge.id,
      amountMinor: charge.amountMinor,
      paidAt: november,
    );
  }

  Iterable<String> periods(BatchQuote quote) =>
      quote.months.map((month) => month.periodKey);
  Future<void> save(BatchQuote quote, [DateTime? date]) =>
      payments.registerBatch(quote, paidAt: date ?? november);

  test('P01 chooses two oldest amounts, retains other debt and uses the customer rate', () async {
    await seed(date: DateTime(2026, 9, 13), fee: 800);
    await seed(id: 'second', fee: 9999);
    await clients.changeMonthlyFee('qa', 1500, today: LocalDate(2026, 9, 13));
    await billing.reconcileClient('qa', today: LocalDate(2026, 10, 10));
    final preview = await quote();
    expect(periods(preview), ['2026-09', '2026-10']);
    expect(preview.months.map((m) => m.amountMinor), [800, 1500]);
    expect(preview.totalMinor, 2300);
    expect(preview.remaining, ['2026-11']);
    expect(await db.select(db.charges).get(), hasLength(3));
    await save(preview);
    final histories = await payments.batchesForClient('qa');
    expect(histories.single.batch.totalMinor, 2300);
    expect(histories.single.payments.map((p) => p.payment.amountMinor), [
      800,
      1500,
    ]);
    expect(await db.select(db.charges).get(), hasLength(4));
  });

  test('P02/P06/P07/P08 future charge retains reviewed fee and stays paid at cut and day 3', () async {
    await seed();
    final preview = await quote();
    expect(periods(preview), ['2026-11', '2026-12']);
    expect(await db.select(db.charges).get(), hasLength(1));
    await save(preview);
    await clients.changeMonthlyFee(
      'qa',
      2500,
      today: LocalDate.fromDateTime(november),
    );
    expect(await billing.reconcile(today: LocalDate(2026, 11, 30)), 0);
    expect(await billing.reconcile(today: LocalDate(2026, 12, 3)), 0);
    final current = await queries.dashboardData(
      LocalDate.fromDateTime(december),
    );
    expect(current.billing.summary.collectedMinor, 1500);
    expect(current.billing.summary.paidCharges, 1);
    expect(current.reviewCount, 0);
    expect(
      await billing.clientHasOverdueDebt(
        'qa',
        today: LocalDate.fromDateTime(december),
      ),
      isFalse,
    );
    final row = current.billing.rows.single;
    expect(row.item.charge.amountMinor, 1500);
    expect(ReportEntry.fromRow(row).status, ChargeStatus.paid);
    expect(await db.select(db.charges).get(), hasLength(2));
  });

  test(
    'P03/P05 paid months skipped across December, January and February',
    () async {
      await seed();
      await save(await quote());
      final next = await quote();
      expect(periods(next), ['2027-01', '2027-02']);
      await save(next);
      final charges = await billing.historyForClient(
        'qa',
        today: LocalDate.fromDateTime(november),
      );
      expect(charges.map((row) => row.charge.collectionDate), [
        '2026-10-30',
        '2026-11-30',
        '2026-12-30',
        '2027-01-30',
      ]);
      expect(
        charges.map((row) => row.status),
        List.filled(4, ChargeStatus.paid),
      );
    },
  );

  test('P04 skips an already paid intervening month', () async {
    await seed(date: DateTime(2026, 9, 13));
    await billing.reconcile(today: LocalDate(2026, 10, 13));
    await individual('2026-10');
    final preview = await quote();
    expect(periods(preview), ['2026-09', '2026-11']);
    await save(preview);
    final history = await payments.historyForClient('qa');
    expect(
      history.singleWhere((p) => p.chargeId.endsWith('2026-10')).batchId,
      isNull,
    );
  });

  test(
    'P06 February cut opens March without regenerating advance payments',
    () async {
      final date = DateTime(2028, 2, 27, 12);
      await seed(date: date);
      final preview = await quote(date);
      expect(periods(preview), ['2028-02', '2028-03']);
      await save(preview, date);
      expect(currentPeriod(LocalDate(2028, 2, 29)).key, '2028-03');
      expect(await billing.reconcile(today: LocalDate(2028, 2, 29)), 0);
      expect(
        (await quote(DateTime(2028, 2, 29, 12))).months.first.periodKey,
        '2028-04',
      );
    },
  );

  test('P09 actual SQLite failure on second child rolls back reconciliation, future charge and group', () async {
    await seed(date: DateTime(2026, 10, 11));
    await individual('2026-10');
    final preview = await quote();
    expect(periods(preview), ['2026-11', '2026-12']);
    await db.customStatement("""
      CREATE TRIGGER qa_fail_second BEFORE INSERT ON payments
      WHEN NEW.batch_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM payments WHERE batch_id = NEW.batch_id
      )
      BEGIN SELECT RAISE(ABORT, 'synthetic fault'); END
    """);
    await expectLater(save(preview), throwsA(isA<SqliteException>()));
    expect(await db.select(db.paymentBatches).get(), isEmpty);
    expect(await db.select(db.charges).get(), hasLength(1));
    expect(await db.select(db.payments).get(), hasLength(1));
  });

  test('P10 duplicate, overlapping concurrent and later replay confirmations commit only once', () async {
    await seed();
    final first = await quote();
    final second = await quote();
    Future<bool> trySave(BatchQuote preview) async {
      try {
        await save(preview);
        return true;
      } on StateError {
        return false;
      }
    }

    expect(
      await Future.wait([trySave(first), trySave(first), trySave(second)]),
      [true, false, false],
    );
    expect(await db.select(db.payments).get(), hasLength(2));
    await payments.voidBatch(
      first.id,
      voidedAt: december,
      expectedActiveIds: activeIds(await group(first.id)),
    );
    expect(await trySave(first), isFalse);
    expect(await db.select(db.paymentBatches).get(), hasLength(1));
  });

  test('P11–P14 voids individual and remaining children, rejects stale and repeated voids, retains later coverage', () async {
    await seed();
    final older = await quote();
    await save(older);
    final later = await quote();
    await save(later);
    final before = await payments.historyForClient('qa');
    final child = before.firstWhere((p) => p.batchId == older.id);
    await expectLater(
      payments.voidPayment(child.id, voidedAt: december),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('operación seleccionada'),
        ),
      ),
    );
    await expectLater(
      db.customStatement('UPDATE payments SET amount_minor = 42 WHERE id = ?', [
        child.id,
      ]),
      throwsA(isA<SqliteException>()),
    );
    final original = await group(older.id);
    final earlier = december.subtract(const Duration(hours: 1));
    await voidMember(original, 0, earlier);
    await expectLater(voidMember(original, 0, december), throwsStateError);
    final partial = await group(older.id);
    expect(partial.status, BatchStatus.partiallyVoided);
    expect(partial.activeMinor, 1500);
    await expectLater(
      payments.voidBatch(
        older.id,
        voidedAt: december,
        expectedActiveIds: activeIds(original),
      ),
      throwsStateError,
    );
    await payments.voidBatch(
      older.id,
      voidedAt: december,
      expectedActiveIds: activeIds(partial),
    );
    await expectLater(
      payments.voidBatch(
        older.id,
        voidedAt: december,
        expectedActiveIds: activeIds(partial),
      ),
      throwsStateError,
    );
    final after = await payments.historyForClient('qa');
    expect(
      after.where((p) => p.batchId == later.id),
      before.where((p) => p.batchId == later.id),
    );
    expect(
      after.where((p) => p.batchId == older.id).map((p) => p.voidedAt),
      unorderedEquals([
        earlier.millisecondsSinceEpoch,
        december.millisecondsSinceEpoch,
      ]),
    );
    expect(await db.select(db.charges).get(), hasLength(4));
    final today = LocalDate.fromDateTime(december);
    final client = (await queries.clientData('qa', today))!;
    expect(client.coverageLabel(today), contains('pendiente: Noviembre 2026'));
    expect((await queries.dashboardData(today)).reviewCount, 1);
    expect(periods(await quote(december)), ['2026-11', '2026-12']);
  });

  test('P15 archived and changed status are blocked; suspended client can pay without reactivation', () async {
    await seed();
    final stale = await quote();
    await clients.changeStatus(
      'qa',
      ServiceStatus.archived,
      today: LocalDate.fromDateTime(november),
    );
    await expectLater(quote(), throwsStateError);
    await expectLater(save(stale), throwsStateError);
    await seed(id: 'suspended', status: ServiceStatus.suspended);
    final suspended = await payments.previewBatch(
      'suspended',
      november,
      count: 2,
    );
    expect(suspended.client.status, 'suspended');
    expect(await payments.historyForClient('suspended'), isEmpty);
    expect(periods(suspended), ['2026-12', '2027-01']);
    await save(suspended);
    expect((await clients.get('suspended')).status, 'suspended');
  });

  for (final count in [1, 2, 3, 6, 12]) {
    test(
      'T09.1 registers $count distinct months and a single remains ungrouped',
      () async {
        await seed();
        final preview = await quote(november, count);
        expect(
          preview.months.map((row) => row.periodKey).toSet(),
          hasLength(count),
        );
        expect(preview.totalMinor, 1500 * count);
        expect(await db.select(db.charges).get(), hasLength(1));
        await save(preview);
        await expectLater(save(preview), throwsStateError);
        final rows = await db.select(db.payments).get();
        expect(rows, hasLength(count));
        expect(rows.map((row) => row.batchId).toSet(), {
          count == 1 ? null : preview.id,
        });
        expect(
          await db.select(db.paymentBatches).get(),
          hasLength(count == 1 ? 0 : 1),
        );
        if (count == 12) {
          expect(preview.months.last.periodKey, '2027-10');
          expect(preview.nextPeriod?.key, '2027-11');
        }
      },
    );
  }

  test('T09.1 rejects out-of-range quantities', () async {
    await seed();
    for (final count in [-1, 0, 13]) {
      await expectLater(quote(november, count), throwsArgumentError);
    }
    expect(await db.select(db.payments).get(), isEmpty);
  });

  test('T09.1 failure on the seventh payment rolls back the twelve-month operation', () async {
    await seed();
    final preview = await quote(november, 12);
    await db.customStatement("""
      CREATE TRIGGER qa_fail_seventh BEFORE INSERT ON payments
      WHEN (SELECT COUNT(*) FROM payments WHERE batch_id = NEW.batch_id) = 6
      BEGIN SELECT RAISE(ABORT, 'synthetic fault'); END
    """);
    await expectLater(save(preview), throwsA(isA<SqliteException>()));
    expect(await db.select(db.paymentBatches).get(), isEmpty);
    expect(await db.select(db.payments).get(), isEmpty);
    expect(await db.select(db.charges).get(), hasLength(1));
  });

  test('T09.1 partial November–February group leaves December due and supports a new payment', () async {
    await seed();
    final preview = await quote(november, 4);
    await save(preview);
    final original = await group(preview.id);
    await expectLater(
      payments.voidPayment(
        original.payments[1].payment.id,
        voidedAt: december,
        expectedBatchId: original.batch.id,
        expectedClientId: 'wrong',
      ),
      throwsStateError,
    );
    await voidMember(original, 1, december);
    final partial = await group(preview.id);
    expect(partial.status, BatchStatus.partiallyVoided);
    expect(partial.batch.voidedAt, isNull);
    expect(partial.batch.totalMinor, 6000);
    expect(partial.activeMinor, 4500);
    expect(partial.voidedMinor, 1500);
    expect(partial.active.map((row) => row.charge.periodKey), [
      '2026-11',
      '2027-01',
      '2027-02',
    ]);
    final today = LocalDate.fromDateTime(december);
    final dashboard = await queries.dashboardData(today);
    expect(dashboard.billing.summary.collectedMinor, 0);
    expect(dashboard.reviewCount, 1);
    expect(
      ReportEntry.fromRow(dashboard.billing.rows.single).status,
      ChargeStatus.suspensionCandidate,
    );
    expect(
      (await queries.clientData('qa', today))!.coverageLabel(today),
      contains('pendiente: Diciembre 2026'),
    );
    final second = await quote(december, 2);
    expect(periods(second), ['2026-12', '2027-03']);
    await save(second, december);
    expect((await group(preview.id)).payments, partial.payments);
    expect(
      (await queries.dashboardData(today)).billing.summary.collectedMinor,
      1500,
    );
    expect((await queries.dashboardData(today)).reviewCount, 0);
  });

  for (final count in [2, 12]) {
    for (final first in [true, false]) {
      test(
        'T09.1 voids only the ${first ? 'first' : 'last'} child of a $count-month group',
        () async {
          await seed();
          final preview = await quote(november, count);
          await save(preview);
          final original = await group(preview.id);
          final index = first ? 0 : count - 1;
          await voidMember(original, index, december);
          final result = await group(preview.id);
          expect(result.active.length, count - 1);
          expect(
            result.payments[index].payment.voidedAt,
            december.millisecondsSinceEpoch,
          );
          expect(
            result.active,
            original.payments.where((row) => row != original.payments[index]),
          );
        },
      );
    }
  }

  test('T09.1 a large twelve-month total stays exact and bulk annulment voids every child', () async {
    const fee = 768614336404564650;
    await seed(fee: fee);
    final preview = await quote(november, 12);
    expect(preview.totalMinor, 9223372036854775800);
    await save(preview);
    final active = await group(preview.id);
    expect(active.activeMinor, preview.totalMinor);
    await payments.voidBatch(
      preview.id,
      voidedAt: december,
      expectedActiveIds: activeIds(active),
    );
    final voided = await group(preview.id);
    expect(voided.activeMinor, 0);
    expect(voided.voidedMinor, preview.totalMinor);
    expect(voided.voidedCount, 12);
  });

  test('T09.1 fault in group annulment preserves all unvoided children and the previous audit', () async {
    await seed();
    final preview = await quote(november, 12);
    await save(preview);
    final active = await group(preview.id);
    await voidMember(active, 2, november);
    final partial = await group(preview.id);
    await db.customStatement("""
      CREATE TRIGGER qa_fail_void BEFORE UPDATE ON payments
      WHEN NEW.voided_at IS NOT NULL AND OLD.batch_id IS NOT NULL
        AND (SELECT COUNT(*) FROM payments WHERE batch_id = OLD.batch_id AND voided_at IS NOT NULL) = 5
      BEGIN SELECT RAISE(ABORT, 'synthetic fault'); END
    """);
    await expectLater(
      payments.voidBatch(
        preview.id,
        voidedAt: december,
        expectedActiveIds: activeIds(partial),
      ),
      throwsA(isA<SqliteException>()),
    );
    final after = await group(preview.id);
    expect(after.batch, partial.batch);
    expect(after.payments, partial.payments);
  });

  test('rejects stale prices, cut changes and signed integer overflow before writing', () async {
    await seed();
    final stale = await quote();
    await clients.changeMonthlyFee(
      'qa',
      9900,
      today: LocalDate.fromDateTime(november),
    );
    await expectLater(save(stale), throwsStateError);
    final refreshed = await quote();
    await expectLater(
      save(refreshed, DateTime(2026, 11, 30, 12)),
      throwsStateError,
    );
    await clients.changeMonthlyFee(
      'qa',
      9223372036854775807,
      today: LocalDate.fromDateTime(november),
    );
    await expectLater(quote(), throwsStateError);
    expect(await db.select(db.paymentBatches).get(), isEmpty);
    expect(await db.select(db.charges).get(), hasLength(1));
  });
}
