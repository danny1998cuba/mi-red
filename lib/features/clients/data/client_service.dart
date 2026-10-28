import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/record_id.dart';
import '../../billing/billing_calendar.dart';
import '../../billing/data/billing_service.dart';

enum ServiceStatus { active, suspended, archived }

class ClientService {
  ClientService(this.db, this.billing);

  final AppDatabase db;
  final BillingService billing;

  Future<ClientRecord> get(String id) async {
    final client = await (db.select(
      db.clients,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (client == null) throw StateError('El cliente no existe.');
    return client;
  }

  Future<List<ClientRecord>> list({ServiceStatus? status}) {
    final query = db.select(db.clients)
      ..orderBy([
        (row) => OrderingTerm.asc(row.fullName),
        (row) => OrderingTerm.asc(row.id),
      ]);
    if (status != null) query.where((row) => row.status.equals(status.name));
    return query.get();
  }

  Future<ClientRecord> create({
    String? id,
    required String fullName,
    required int monthlyFeeMinor,
    required LocalDate today,
    DateTime? recordedAt,
    String? phone,
    String? address,
    String? notes,
    ServiceStatus status = ServiceStatus.active,
  }) => db.transaction(() async {
    if (fullName.trim().isEmpty) {
      throw ArgumentError('El nombre es obligatorio.');
    }
    if (monthlyFeeMinor < 0) {
      throw ArgumentError('La mensualidad no puede ser negativa.');
    }
    final clientId = id ?? newRecordId();
    final timestamp = (recordedAt ?? DateTime.now()).millisecondsSinceEpoch;
    await db
        .into(db.clients)
        .insert(
          ClientsCompanion.insert(
            id: clientId,
            fullName: fullName.trim(),
            monthlyFeeMinor: monthlyFeeMinor,
            status: status.name,
            phone: Value(phone),
            address: Value(address),
            notes: Value(notes),
            createdAt: timestamp,
            updatedAt: timestamp,
            archivedAt: Value(
              status == ServiceStatus.archived ? timestamp : null,
            ),
            billingStartPeriod: currentPeriod(today).key,
          ),
        );
    await billing.reconcileClient(
      clientId,
      today: today,
      recordedAt: recordedAt,
    );
    return get(clientId);
  });

  Future<void> updateContactDetails(
    String id, {
    required String fullName,
    String? phone,
    String? address,
    String? notes,
    DateTime? recordedAt,
  }) => db.transaction(() async {
    await get(id);
    if (fullName.trim().isEmpty) {
      throw ArgumentError('El nombre es obligatorio.');
    }
    await (db.update(db.clients)..where((row) => row.id.equals(id))).write(
      ClientsCompanion(
        fullName: Value(fullName.trim()),
        phone: Value(phone),
        address: Value(address),
        notes: Value(notes),
        updatedAt: Value((recordedAt ?? DateTime.now()).millisecondsSinceEpoch),
      ),
    );
  });

  Future<void> changeMonthlyFee(
    String id,
    int amountMinor, {
    required LocalDate today,
    DateTime? recordedAt,
  }) => db.transaction(() async {
    if (amountMinor < 0) {
      throw ArgumentError('La mensualidad no puede ser negativa.');
    }
    await get(id);
    // Finish the previous interval before changing the tariff snapshot source.
    await billing.reconcileClient(id, today: today, recordedAt: recordedAt);
    await (db.update(db.clients)..where((row) => row.id.equals(id))).write(
      ClientsCompanion(
        monthlyFeeMinor: Value(amountMinor),
        updatedAt: Value((recordedAt ?? DateTime.now()).millisecondsSinceEpoch),
      ),
    );
  });

  Future<void> changeStatus(
    String id,
    ServiceStatus status, {
    required LocalDate today,
    DateTime? recordedAt,
  }) => db.transaction(() async {
    final client = await get(id);
    if (client.status == status.name) return;
    if (client.status == ServiceStatus.active.name) {
      await billing.reconcileClient(id, today: today, recordedAt: recordedAt);
    }
    final timestamp = (recordedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final current = currentPeriod(today);
    final start = BillingPeriod.parse(client.billingStartPeriod);
    await (db.update(db.clients)..where((row) => row.id.equals(id))).write(
      ClientsCompanion(
        status: Value(status.name),
        archivedAt: Value(status == ServiceStatus.archived ? timestamp : null),
        updatedAt: Value(timestamp),
        billingStartPeriod: status == ServiceStatus.active
            ? Value(current.compareTo(start) > 0 ? current.key : start.key)
            : const Value.absent(),
      ),
    );
    if (status == ServiceStatus.active) {
      await billing.reconcileClient(id, today: today, recordedAt: recordedAt);
    }
  });
}
