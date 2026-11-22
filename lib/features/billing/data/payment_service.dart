import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/record_id.dart';
import '../billing_calendar.dart';
import 'billing_service.dart';

typedef PaymentMonth = ({String chargeId, String periodKey, int amountMinor});
typedef BatchMember = ({ChargeRecord charge, PaymentRecord payment});
const maxPaymentMonths = 12;

class PaymentReviewChanged extends StateError {
  PaymentReviewChanged(super.message);
}

class BatchQuote {
  BatchQuote._(
    this.id,
    this.client,
    this.period,
    this.reviewedAt,
    this.currency,
    List<PaymentMonth> months,
    List<String> remaining,
    this.totalMinor,
    this.nextPeriod,
  ) : months = List.unmodifiable(months),
      remaining = List.unmodifiable(remaining);

  final String id, currency;
  final ClientRecord client;
  final BillingPeriod period;
  final DateTime reviewedAt;
  final List<PaymentMonth> months;
  final List<String> remaining;
  final int totalMinor;
  final BillingPeriod? nextPeriod;
}

enum BatchStatus { active, partiallyVoided, voided }

class BatchHistory {
  const BatchHistory(this.batch, this.payments);
  final PaymentBatchRecord batch;
  final List<BatchMember> payments;
  List<BatchMember> get active =>
      payments.where((row) => row.payment.voidedAt == null).toList();
  int get voidedCount =>
      payments.where((row) => row.payment.voidedAt != null).length;
  int get activeMinor =>
      active.fold(0, (total, row) => total + row.payment.amountMinor);
  int get voidedMinor => batch.totalMinor - activeMinor;
  BatchStatus get status => switch (voidedCount) {
    0 => BatchStatus.active,
    final count when count == payments.length => BatchStatus.voided,
    _ => BatchStatus.partiallyVoided,
  };
}

class PaymentService {
  PaymentService(this.db);

  final AppDatabase db;

  Future<PaymentRecord> register({
    String? id,
    required String chargeId,
    required int amountMinor,
    required DateTime paidAt,
    String? note,
  }) => db.transaction(
    () => _register(
      id: id,
      chargeId: chargeId,
      amountMinor: amountMinor,
      paidAt: paidAt,
      note: note,
    ),
  );

  Future<PaymentRecord> _register({
    String? id,
    required String chargeId,
    required int amountMinor,
    required DateTime paidAt,
    String? note,
    String? batchId,
  }) async {
    final charge = await (db.select(
      db.charges,
    )..where((row) => row.id.equals(chargeId))).getSingleOrNull();
    if (charge == null) throw StateError('El cargo no existe.');
    if (amountMinor < 0 || amountMinor != charge.amountMinor) {
      throw ArgumentError('El pago debe cubrir el importe exacto del cargo.');
    }
    final active =
        await (db.select(db.payments)..where(
              (row) => row.chargeId.equals(chargeId) & row.voidedAt.isNull(),
            ))
            .getSingleOrNull();
    if (active != null) throw StateError('El cargo ya tiene un pago vigente.');
    final paymentId = id ?? newRecordId();
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            id: paymentId,
            chargeId: chargeId,
            amountMinor: amountMinor,
            paidAt: paidAt.millisecondsSinceEpoch,
            note: Value(note),
            batchId: Value(batchId),
          ),
        );
    return (db.select(
      db.payments,
    )..where((row) => row.id.equals(paymentId))).getSingle();
  }

  Future<BatchQuote> previewBatch(
    String clientId,
    DateTime now, {
    required int count,
  }) => db.transaction(() async {
    if (count < 1 || count > maxPaymentMonths) {
      throw ArgumentError.value(
        count,
        'count',
        'Selecciona entre 1 y 12 mensualidades.',
      );
    }
    final (quote, _) = await _plan(clientId, now, newRecordId(), count);
    return quote;
  });

  Future<(BatchQuote, List<ChargeRecord>)> _plan(
    String clientId,
    DateTime now,
    String id,
    int count,
  ) async {
    final client = await (db.select(
      db.clients,
    )..where((row) => row.id.equals(clientId))).getSingleOrNull();
    if (client == null || client.status == 'archived') {
      throw StateError('El cliente no existe o está archivado.');
    }
    final today = LocalDate.fromDateTime(now);
    final period = currentPeriod(today);
    final billing = BillingService(db);
    final history = await billing.historyForClient(clientId, today: today);
    final existing = history.map((row) => row.charge.periodKey).toSet();
    final pending = [
      for (final row in history)
        if (row.activePayment == null) row.charge,
      if (client.status == 'active')
        ...billing.missingCharges(
          client,
          period,
          existing,
          now.millisecondsSinceEpoch,
        ),
    ]..sort((a, b) => a.periodKey.compareTo(b.periodKey));
    final chosen = pending.take(count).toList();
    final start = BillingPeriod.parse(client.billingStartPeriod);
    final future = <ChargeRecord>[];
    if (chosen.length < count) {
      var next = period.next;
      if (next.compareTo(start) < 0) next = start;
      while (true) {
        if (!existing.contains(next.key)) {
          final charge = billing.plannedCharge(
            client,
            next,
            now.millisecondsSinceEpoch,
          );
          future.add(charge);
          chosen.add(charge);
          if (chosen.length == count) break;
        }
        next = next.next;
      }
    }
    chosen.sort((a, b) => a.periodKey.compareTo(b.periodKey));
    var total = 0;
    for (final charge in chosen) {
      if (total > 9223372036854775807 - charge.amountMinor) {
        throw StateError('El total supera el importe permitido.');
      }
      total += charge.amountMinor;
    }
    final remaining = pending
        .skip(count)
        .map((charge) => charge.periodKey)
        .toList();
    final coveredKeys = {
      for (final row in history)
        if (row.activePayment != null) row.charge.periodKey,
      for (final charge in chosen) charge.periodKey,
    };
    BillingPeriod? next = start.compareTo(period) > 0 ? start : period;
    if (client.status == 'suspended' &&
        next == period &&
        !existing.contains(period.key)) {
      next = period.next;
    }
    while (next != null && coveredKeys.contains(next.key)) {
      next = next.key == '9999-12' ? null : next.next;
    }
    if (remaining.isNotEmpty &&
        (next == null || remaining.first.compareTo(next.key) < 0)) {
      next = BillingPeriod.parse(remaining.first);
    }
    final currency =
        (await db.select(db.appSettings).getSingle()).currencyLabel;
    return (
      BatchQuote._(
        id,
        client,
        period,
        now,
        currency,
        [
          for (final charge in chosen)
            (
              chargeId: charge.id,
              periodKey: charge.periodKey,
              amountMinor: charge.amountMinor,
            ),
        ],
        remaining,
        total,
        next,
      ),
      future,
    );
  }

  Future<void> registerBatch(
    BatchQuote expected, {
    required DateTime paidAt,
    String? note,
  }) => db.transaction(() async {
    final previousBatch = await (db.select(
      db.paymentBatches,
    )..where((row) => row.id.equals(expected.id))).getSingleOrNull();
    final previousPayment = await (db.select(
      db.payments,
    )..where((row) => row.id.equals(expected.id))).getSingleOrNull();
    if (previousBatch != null || previousPayment != null) {
      throw StateError('Esta operación ya fue registrada.');
    }
    await BillingService(db).reconcileClient(
      expected.client.id,
      today: LocalDate.fromDateTime(paidAt),
      recordedAt: paidAt,
    );
    final (actual, future) = await _plan(
      expected.client.id,
      paidAt,
      expected.id,
      expected.months.length,
    );
    if (actual.client.status != expected.client.status ||
        actual.client.fullName != expected.client.fullName ||
        actual.period != expected.period ||
        LocalDate.fromDateTime(paidAt) !=
            LocalDate.fromDateTime(expected.reviewedAt) ||
        actual.currency != expected.currency ||
        !_same(actual.months, expected.months) ||
        !_same(actual.remaining, expected.remaining) ||
        actual.nextPeriod != expected.nextPeriod) {
      throw PaymentReviewChanged(
        'Los cobros cambiaron. Revisa los períodos e importes de nuevo.',
      );
    }
    for (final charge in future) {
      await db.into(db.charges).insert(charge);
    }
    final single = actual.months.length == 1;
    if (!single) {
      await db
          .into(db.paymentBatches)
          .insert(
            PaymentBatchesCompanion.insert(
              id: actual.id,
              clientId: actual.client.id,
              paidAt: paidAt.millisecondsSinceEpoch,
              totalMinor: actual.totalMinor,
            ),
          );
    }
    for (final month in actual.months) {
      await _register(
        id: single ? actual.id : null,
        chargeId: month.chargeId,
        amountMinor: month.amountMinor,
        paidAt: paidAt,
        note: single ? note : null,
        batchId: single ? null : actual.id,
      );
    }
  });

  Future<List<BatchHistory>> batchesForClient(String clientId) async {
    final query =
        db.select(db.paymentBatches).join([
            innerJoin(
              db.payments,
              db.payments.batchId.equalsExp(db.paymentBatches.id),
            ),
            innerJoin(
              db.charges,
              db.charges.id.equalsExp(db.payments.chargeId),
            ),
          ])
          ..where(db.paymentBatches.clientId.equals(clientId))
          ..orderBy([
            OrderingTerm.desc(db.paymentBatches.paidAt),
            OrderingTerm.asc(db.paymentBatches.id),
            OrderingTerm.asc(db.charges.periodKey),
          ]);
    final groups = <String, BatchHistory>{};
    for (final row in await query.get()) {
      final batch = row.readTable(db.paymentBatches);
      groups.putIfAbsent(batch.id, () => BatchHistory(batch, [])).payments.add((
        charge: row.readTable(db.charges),
        payment: row.readTable(db.payments),
      ));
    }
    return groups.values.toList();
  }

  Future<void> voidBatch(
    String id, {
    required DateTime voidedAt,
    required Set<String> expectedActiveIds,
  }) => db.transaction(() async {
    final active = await (db.select(
      db.payments,
    )..where((row) => row.batchId.equals(id) & row.voidedAt.isNull())).get();
    if (active.isEmpty ||
        expectedActiveIds.length != active.length ||
        active.any((row) => !expectedActiveIds.contains(row.id))) {
      throw PaymentReviewChanged(
        'Los pagos vigentes del grupo cambiaron. Revisa la anulación.',
      );
    }
    final affected =
        await (db.update(
          db.paymentBatches,
        )..where((row) => row.id.equals(id) & row.voidedAt.isNull())).write(
          PaymentBatchesCompanion(
            voidedAt: Value(voidedAt.millisecondsSinceEpoch),
          ),
        );
    if (affected != 1) throw StateError('El grupo no existe o ya fue anulado.');
    // The SQLite trigger voids only the still-active children.
    db.markTablesUpdated({db.payments});
  });

  Future<void> voidPayment(
    String id, {
    required DateTime voidedAt,
    String? expectedBatchId,
    String? expectedClientId,
  }) => db.transaction(() async {
    final existing = await (db.select(
      db.payments,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing == null || existing.voidedAt != null) {
      throw StateError('El pago no existe o ya fue anulado.');
    }
    if (existing.batchId != expectedBatchId) {
      throw StateError('El pago no corresponde a la operación seleccionada.');
    }
    if (expectedBatchId != null) {
      final group = await (db.select(
        db.paymentBatches,
      )..where((row) => row.id.equals(expectedBatchId))).getSingleOrNull();
      if (group == null ||
          group.clientId != expectedClientId ||
          group.voidedAt != null) {
        throw StateError(
          'El pago no corresponde al grupo o cliente seleccionado.',
        );
      }
    }
    final affected =
        await (db.update(
          db.payments,
        )..where((row) => row.id.equals(id) & row.voidedAt.isNull())).write(
          PaymentsCompanion(voidedAt: Value(voidedAt.millisecondsSinceEpoch)),
        );
    if (affected != 1) throw StateError('El pago no existe o ya fue anulado.');
  });

  Future<List<PaymentRecord>> historyForCharge(String chargeId) =>
      (db.select(db.payments)
            ..where((row) => row.chargeId.equals(chargeId))
            ..orderBy([
              (row) => OrderingTerm.asc(row.paidAt),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .get();

  Future<List<PaymentRecord>> historyForClient(String clientId) async {
    final query =
        db.select(db.payments).join([
            innerJoin(
              db.charges,
              db.charges.id.equalsExp(db.payments.chargeId),
            ),
          ])
          ..where(db.charges.clientId.equals(clientId))
          ..orderBy([
            OrderingTerm.asc(db.payments.paidAt),
            OrderingTerm.asc(db.payments.id),
          ]);
    return (await query.get())
        .map((row) => row.readTable(db.payments))
        .toList();
  }
}

bool _same<T>(List<T> a, List<T> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
