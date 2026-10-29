import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../billing_calendar.dart';
import 'billing_service.dart';
import 'payment_service.dart';

class BillingRow {
  const BillingRow(this.client, this.item, {required this.hasPreviousDebt});
  final ClientRecord client;
  final ChargeWithStatus item;
  final bool hasPreviousDebt;
}

class BillingPeriodData {
  const BillingPeriodData({
    required this.rows,
    required this.summary,
    required this.outstandingMinor,
    required this.currencyLabel,
  });
  final List<BillingRow> rows;
  final PeriodSummary summary;
  final int outstandingMinor;
  final String currencyLabel;
}

class ClientBillingData {
  const ClientBillingData(
    this.client,
    this.charges,
    this.payments,
    this.currencyLabel,
  );
  final ClientRecord client;
  final List<ChargeWithStatus> charges;
  final List<PaymentRecord> payments;
  final String currencyLabel;

  PaymentRecord? get lastValidPayment {
    final valid = payments
        .where((payment) => payment.voidedAt == null)
        .toList();
    return valid.isEmpty ? null : valid.last;
  }
}

/// Read-only projections. All financial transitions remain in the T02 services.
class BillingQueries {
  BillingQueries(this.db, this.billing, this.payments);
  final AppDatabase db;
  final BillingService billing;
  final PaymentService payments;

  Stream<List<QueryRow>> _changes() => db
      .customSelect(
        'SELECT 1',
        readsFrom: {db.clients, db.charges, db.payments, db.appSettings},
      )
      .watch();

  Stream<BillingPeriodData> watchPeriod(
    BillingPeriod period,
    LocalDate today,
  ) => _changes().asyncMap((_) => periodData(period, today));

  Future<BillingPeriodData> periodData(BillingPeriod period, LocalDate today) =>
      db.transaction(() async {
        final charges = await billing.chargesForPeriod(period, today: today);
        final clients = {
          for (final client in await db.select(db.clients).get())
            client.id: client,
        };
        final prior =
            db.select(db.charges).join([
              leftOuterJoin(
                db.payments,
                db.payments.chargeId.equalsExp(db.charges.id) &
                    db.payments.voidedAt.isNull(),
              ),
            ])..where(
              db.charges.periodKey.isSmallerThanValue(period.key) &
                  db.payments.id.isNull(),
            );
        final previousDebtors = (await prior.get())
            .map((row) => row.readTable(db.charges).clientId)
            .toSet();
        final rows = charges
            .map(
              (item) => BillingRow(
                clients[item.charge.clientId]!,
                item,
                hasPreviousDebt: previousDebtors.contains(item.charge.clientId),
              ),
            )
            .toList();
        // Unpaid first, then a deterministic name/ID order. No debt inference from service status.
        rows.sort((a, b) {
          final paidOrder = (a.item.activePayment == null ? 0 : 1).compareTo(
            b.item.activePayment == null ? 0 : 1,
          );
          if (paidOrder != 0) return paidOrder;
          final nameOrder = a.client.fullName.toLowerCase().compareTo(
            b.client.fullName.toLowerCase(),
          );
          return nameOrder != 0
              ? nameOrder
              : a.item.charge.id.compareTo(b.item.charge.id);
        });
        return BillingPeriodData(
          rows: rows,
          summary: await billing.summary(period, today: today),
          outstandingMinor: charges
              .where((row) => row.activePayment == null)
              .fold<int>(0, (sum, row) => sum + row.charge.amountMinor),
          currencyLabel:
              (await db.select(db.appSettings).getSingle()).currencyLabel,
        );
      });

  Stream<ClientBillingData?> watchClient(String id, LocalDate today) =>
      _changes().asyncMap((_) => clientData(id, today));

  Future<ClientBillingData?> clientData(String id, LocalDate today) =>
      db.transaction(() async {
        final client = await (db.select(
          db.clients,
        )..where((row) => row.id.equals(id))).getSingleOrNull();
        if (client == null) return null;
        return ClientBillingData(
          client,
          await billing.historyForClient(id, today: today),
          await payments.historyForClient(id),
          (await db.select(db.appSettings).getSingle()).currencyLabel,
        );
      });
}
