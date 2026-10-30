import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../billing_calendar.dart';

class ChargeWithStatus {
  const ChargeWithStatus(this.charge, this.activePayment, this.status);

  final ChargeRecord charge;
  final PaymentRecord? activePayment;
  final ChargeStatus status;
}

class PeriodSummary {
  const PeriodSummary({
    required this.activeClients,
    required this.totalCharges,
    required this.paidCharges,
    required this.pendingCharges,
    required this.suspensionCandidateCharges,
    required this.collectedMinor,
  });

  final int activeClients;
  final int totalCharges;
  final int paidCharges;
  final int pendingCharges;
  final int suspensionCandidateCharges;
  final int collectedMinor;
  int get unpaidCharges => totalCharges - paidCharges;
}

class BillingService {
  BillingService(this.db);

  final AppDatabase db;

  /// Explicit correction of an unpaid current charge, never a fee/history rewrite.
  /// expectedAmountMinor binds the confirmation to the amount the operator reviewed.
  Future<void> correctChargeAmount({
    required String chargeId,
    required int expectedAmountMinor,
    required int amountMinor,
    required LocalDate today,
  }) => db.transaction(() async {
    if (amountMinor < 0 || amountMinor > 9223372036854775807) {
      throw ArgumentError('El importe no es válido.');
    }
    final charge = await (db.select(
      db.charges,
    )..where((row) => row.id.equals(chargeId))).getSingleOrNull();
    if (charge == null) throw StateError('El cargo no existe.');
    if (charge.periodKey != currentPeriod(today).key) {
      throw StateError('Solo se puede corregir el período vigente.');
    }
    final active =
        await (db.select(db.payments)..where(
              (row) => row.chargeId.equals(chargeId) & row.voidedAt.isNull(),
            ))
            .getSingleOrNull();
    if (active != null) throw StateError('El cargo ya tiene un pago vigente.');
    if (charge.amountMinor != expectedAmountMinor) {
      throw StateError(
        'El importe cambió. Cierra y revisa la mensualidad antes de confirmar otra vez.',
      );
    }
    if (amountMinor == charge.amountMinor) {
      throw StateError('El nuevo importe debe ser distinto del actual.');
    }
    await (db.update(db.charges)..where((row) => row.id.equals(chargeId)))
        .write(ChargesCompanion(amountMinor: Value(amountMinor)));
  });

  Future<int> reconcile({required LocalDate today, DateTime? recordedAt}) =>
      db.transaction(() async {
        final clients = await (db.select(
          db.clients,
        )..where((row) => row.status.equals('active'))).get();
        var inserted = 0;
        final timestamp = (recordedAt ?? DateTime.now()).millisecondsSinceEpoch;
        for (final client in clients) {
          inserted += await _generate(client, currentPeriod(today), timestamp);
        }
        return inserted;
      });

  Future<int> reconcileClient(
    String clientId, {
    required LocalDate today,
    DateTime? recordedAt,
  }) => db.transaction(() async {
    final client = await (db.select(
      db.clients,
    )..where((row) => row.id.equals(clientId))).getSingleOrNull();
    if (client == null) throw StateError('El cliente no existe.');
    if (client.status != 'active') return 0;
    return _generate(
      client,
      currentPeriod(today),
      (recordedAt ?? DateTime.now()).millisecondsSinceEpoch,
    );
  });

  Future<int> _generate(
    ClientRecord client,
    BillingPeriod last,
    int timestamp,
  ) async {
    var period = BillingPeriod.parse(client.billingStartPeriod);
    if (period.compareTo(last) > 0) return 0;
    final existing = await (db.select(
      db.charges,
    )..where((row) => row.clientId.equals(client.id))).get();
    final existingPeriods = existing.map((charge) => charge.periodKey).toSet();
    var inserted = 0;
    while (period.compareTo(last) <= 0) {
      if (!existingPeriods.contains(period.key)) {
        // No insert-or-ignore: unrelated SQL errors must roll back the transaction.
        await db
            .into(db.charges)
            .insert(
              ChargesCompanion.insert(
                id: '${client.id}:${period.key}',
                clientId: client.id,
                periodKey: period.key,
                collectionDate: period.collectionDate.toString(),
                suspensionCandidateDate: period.suspensionCandidateDate
                    .toString(),
                amountMinor: client.monthlyFeeMinor,
                createdAt: timestamp,
              ),
            );
        inserted++;
      }
      if (period == last) break;
      period = period.next;
    }
    return inserted;
  }

  Future<List<ChargeWithStatus>> chargesForPeriod(
    BillingPeriod period, {
    required LocalDate today,
  }) => _charges(db.charges.periodKey.equals(period.key), today);

  Future<List<ChargeWithStatus>> historyForClient(
    String clientId, {
    required LocalDate today,
  }) => _charges(db.charges.clientId.equals(clientId), today);

  Future<List<ChargeWithStatus>> _charges(
    Expression<bool> filter,
    LocalDate today,
  ) async {
    final query =
        db.select(db.charges).join([
            leftOuterJoin(
              db.payments,
              db.payments.chargeId.equalsExp(db.charges.id) &
                  db.payments.voidedAt.isNull(),
            ),
          ])
          ..where(filter)
          ..orderBy([
            OrderingTerm.asc(db.charges.periodKey),
            OrderingTerm.asc(db.charges.clientId),
          ]);
    return (await query.get()).map((row) {
      final charge = row.readTable(db.charges);
      final payment = row.readTableOrNull(db.payments);
      return ChargeWithStatus(
        charge,
        payment,
        chargeStatus(
          hasActivePayment: payment != null,
          suspensionCandidateDate: LocalDate.parse(
            charge.suspensionCandidateDate,
          ),
          today: today,
        ),
      );
    }).toList();
  }

  Future<bool> clientHasOverdueDebt(
    String clientId, {
    required LocalDate today,
  }) async {
    final query =
        db.select(db.charges).join([
            leftOuterJoin(
              db.payments,
              db.payments.chargeId.equalsExp(db.charges.id) &
                  db.payments.voidedAt.isNull(),
            ),
          ])
          ..where(
            db.charges.clientId.equals(clientId) &
                db.charges.suspensionCandidateDate.isSmallerOrEqualValue(
                  today.toString(),
                ) &
                db.payments.id.isNull(),
          )
          ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  Future<PeriodSummary> summary(
    BillingPeriod period, {
    required LocalDate today,
  }) => db.transaction(() async {
    final rows = await chargesForPeriod(period, today: today);
    final count = db.clients.id.count();
    final query = db.selectOnly(db.clients)
      ..addColumns([count])
      ..where(db.clients.status.equals('active'));
    return PeriodSummary(
      activeClients: (await query.getSingle()).read(count) ?? 0,
      totalCharges: rows.length,
      paidCharges: rows.where((row) => row.status == ChargeStatus.paid).length,
      pendingCharges: rows
          .where((row) => row.status == ChargeStatus.pending)
          .length,
      suspensionCandidateCharges: rows
          .where((row) => row.status == ChargeStatus.suspensionCandidate)
          .length,
      collectedMinor: rows.fold(
        0,
        (total, row) => total + (row.activePayment?.amountMinor ?? 0),
      ),
    );
  });
}
