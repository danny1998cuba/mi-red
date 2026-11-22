import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/backups/backup_snapshot.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';

final backupTestDate = DateTime.utc(2026, 10, 29, 12);

BackupSnapshot syntheticBackup({bool notifications = true, int schema = 5}) {
  final instant = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch;
  Map<String, Object?> client(String id, String status) => {
    'id': id,
    'full_name': 'Prueba T07 $id · José & Ana',
    'phone': '+12025550123',
    'address': 'Dirección sintética de prueba',
    'monthly_fee_minor': 99999,
    'status': status,
    'notes': 'Nota sintética\ncon acento y 👋',
    'created_at': instant,
    'updated_at': instant + 1234,
    'archived_at': status == 'archived' ? instant + 1000 : null,
    'billing_start_period': '2026-10',
  };
  Map<String, Object?> device(
    String id,
    String parent,
    String type,
    String? mac,
    String? ip,
  ) => {
    'id': id,
    'client_id': parent,
    'type': type,
    'mac_address': mac,
    'notes': 'Equipo sintético $id',
    'ip_address': ip,
  };
  Map<String, Object?> charge(
    String id,
    String parent,
    String key,
    int amount,
  ) {
    final period = BillingPeriod.parse(key);
    return {
      'id': id,
      'client_id': parent,
      'period_key': key,
      'collection_date': period.collectionDate.toString(),
      'suspension_candidate_date': period.suspensionCandidateDate.toString(),
      'amount_minor': amount,
      'created_at': instant,
    };
  }

  Map<String, Object?> payment(
    String id,
    String charge,
    int amount,
    bool voided,
  ) => {
    'id': id,
    'charge_id': charge,
    'amount_minor': amount,
    'paid_at': instant + 10,
    'note': 'Auditoría sintética $id',
    'voided_at': voided ? instant + 100 : null,
    if (schema >= 4) 'batch_id': null,
  };
  final records = <String, List<Map<String, Object?>>>{
    'clients': [
      client('active', 'active'),
      client('suspended', 'suspended'),
      client('archived', 'archived'),
    ],
    'devices': [
      device('device-1', 'active', 'antenna', '02:00:00:00:07:01', '192.0.2.7'),
      device('device-2', 'active', 'ont', '02:00:00:00:07:02', '2001:db8::7'),
      device('device-3', 'suspended', 'router', null, null),
      device('device-4', 'archived', 'other', null, null),
    ],
    'charges': [
      charge('old-charge', 'active', '2026-09', 1000),
      charge('current-charge', 'active', '2026-10', 2000),
      charge('zero-charge', 'suspended', '2026-10', 0),
      charge('archived-charge', 'archived', '2026-07', 3333),
    ],
    'payments': [
      payment('voided-old', 'old-charge', 1500, true),
      payment('active-old', 'old-charge', 1000, false),
      payment('voided-current', 'current-charge', 2000, true),
      payment('active-zero', 'zero-charge', 0, false),
    ],
    'app_settings': [
      {
        'id': 1,
        'business_name': 'Prueba T07',
        'currency_label': 'XTS',
        'default_calling_code': '+1',
        'notifications_enabled': notifications ? 1 : 0,
        'last_backup_at': instant - 1000,
      },
    ],
    if (schema >= 4) 'payment_batches': [],
  };
  return BackupSnapshot.fromJson({
    'format': 'mi-red-backup',
    'backupFormatVersion': 1,
    'sourceSchemaVersion': schema,
    'createdAtUtc': backupTestDate.toIso8601String(),
    'appIdentifier': backupAppIdentifier,
    'counts': {
      for (final entry in records.entries) entry.key: entry.value.length,
    },
    'records': records,
  });
}

BackupSnapshot syntheticGroupedV4Backup() {
  final base = syntheticBackup(schema: 4);
  final records = {
    for (final entry in base.records.entries)
      entry.key: [for (final row in entry.value) Map<String, Object?>.of(row)],
  };
  final legacy = records['payments']!.singleWhere(
    (row) => row['id'] == 'active-old',
  );
  final paidAt = legacy['paid_at'] as int;
  for (final (id, voidedAt) in [
    ('group-old-active', null),
    ('group-old-voided', paidAt + 200),
  ]) {
    records['payment_batches']!.add({
      'id': id,
      'client_id': 'active',
      'paid_at': paidAt,
      'total_minor': 3000,
      'voided_at': voidedAt,
    });
    for (final (chargeId, amount) in [
      ('old-charge', 1000),
      ('current-charge', 2000),
    ]) {
      records['payments']!.add({
        'id': '$id-$chargeId',
        'charge_id': chargeId,
        'amount_minor': amount,
        'paid_at': paidAt,
        'note': null,
        'voided_at': voidedAt,
        'batch_id': id,
      });
    }
  }
  records['payments']!.remove(legacy);
  return BackupSnapshot.fromJson({
    ...base.toJson(),
    'counts': {
      for (final entry in records.entries) entry.key: entry.value.length,
    },
    'records': records,
  });
}

Future<void> insertSyntheticBackup(
  AppDatabase db,
  BackupSnapshot snapshot,
) => db.transaction(() async {
  await db.delete(db.appSettings).go();
  for (final table in backupColumns.entries) {
    for (final row in snapshot.currentRecords[table.key]!) {
      await db.customStatement(
        'INSERT INTO ${table.key} (${table.value.join(',')}) VALUES (${List.filled(table.value.length, '?').join(',')})',
        table.value.map((column) => row[column]).toList(),
      );
    }
  }
  db.markTablesUpdated(db.allTables.toSet());
});
