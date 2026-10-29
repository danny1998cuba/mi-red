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

class ReviewClient {
  const ReviewClient(this.id, this.fullName, this.oldestPeriodKey);
  final String id, fullName, oldestPeriodKey;
}

class DashboardData {
  const DashboardData({
    required this.period,
    required this.billing,
    required this.totalClients,
    required this.reviewCount,
    required this.reviewClients,
  });
  final BillingPeriod period;
  final BillingPeriodData billing;
  final int totalClients, reviewCount;
  final List<ReviewClient> reviewClients;
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

  Stream<DashboardData> watchDashboard(LocalDate today) =>
      _changes().asyncMap((_) => dashboardData(today));

  Future<DashboardData> dashboardData(
    LocalDate today,
  ) => db.transaction(() async {
    final period = currentPeriod(today);
    final billing = await periodData(period, today);
    final count = db.clients.id.count();
    final clients = db.selectOnly(db.clients)..addColumns([count]);
    // One row per active client, including older debt even if this period is paid.
    // The window count precedes LIMIT, so the preview never hides the total.
    final review = await db
        .customSelect(
          '''
          WITH review AS (
            SELECT cl.id, cl.full_name, MIN(c.period_key) AS oldest_period_key
            FROM clients cl
            JOIN charges c ON c.client_id = cl.id
            LEFT JOIN payments p ON p.charge_id = c.id AND p.voided_at IS NULL
            WHERE cl.status = 'active' AND p.id IS NULL
              AND c.suspension_candidate_date <= ?
            GROUP BY cl.id
          )
          SELECT *, COUNT(*) OVER () AS review_count FROM review
          ORDER BY oldest_period_key, full_name COLLATE NOCASE, id
          LIMIT 5
        ''',
          variables: [Variable.withString(today.toString())],
        )
        .get();
    return DashboardData(
      period: period,
      billing: billing,
      totalClients: (await clients.getSingle()).read(count) ?? 0,
      reviewCount: review.isEmpty ? 0 : review.first.read<int>('review_count'),
      reviewClients: [
        for (final row in review)
          ReviewClient(
            row.read<String>('id'),
            row.read<String>('full_name'),
            row.read<String>('oldest_period_key'),
          ),
      ],
    );
  });

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
