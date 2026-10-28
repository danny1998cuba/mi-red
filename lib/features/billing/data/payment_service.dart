import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/record_id.dart';

class PaymentService {
  PaymentService(this.db);

  final AppDatabase db;

  Future<PaymentRecord> register({
    String? id,
    required String chargeId,
    required int amountMinor,
    required DateTime paidAt,
    String? note,
  }) => db.transaction(() async {
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
          ),
        );
    return (db.select(
      db.payments,
    )..where((row) => row.id.equals(paymentId))).getSingle();
  });

  Future<void> voidPayment(
    String id, {
    required DateTime voidedAt,
  }) => db.transaction(() async {
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
