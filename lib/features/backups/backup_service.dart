import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import 'backup_snapshot.dart';

class BackupService {
  BackupService(this.db, {this.afterTableImported});
  final AppDatabase db;
  // Fault injection exercises rollback of the real transaction, never a mocked DB.
  final Future<void> Function(String table)? afterTableImported;

  Future<BackupSnapshot> capture(DateTime createdAt) =>
      db.transaction(() async {
        await _checkIntegrity();
        return _capture(createdAt);
      });

  Future<BackupSnapshot> _capture(DateTime createdAt) async {
    final records = <String, List<Map<String, Object?>>>{};
    var total = 0;
    var rawBytes = 0;
    for (final entry in backupColumns.entries) {
      final size = await db
          .customSelect(
            'SELECT COUNT(*) AS n, COALESCE(SUM(${entry.value.map((column) => "length(CAST(COALESCE($column, '') AS BLOB))").join('+')}), 0) AS bytes FROM ${entry.key}',
          )
          .getSingle();
      rawBytes += size.read<int>('bytes');
      if (rawBytes > maxBackupPlainBytes ||
          total + size.read<int>('n') > maxBackupRows) {
        throw const BackupException(
          'La base supera los límites de 16 MiB o 100000 registros por copia.',
        );
      }
      // LIMIT bounds allocation before validation, even for a very large local DB.
      final rows = await db
          .customSelect(
            'SELECT ${entry.value.join(',')} FROM ${entry.key} ORDER BY id LIMIT ${maxBackupRows + 1}',
          )
          .get();
      total += rows.length;
      if (total > maxBackupRows) {
        throw const BackupException(
          'La base supera el límite de 100000 registros por copia.',
        );
      }
      records[entry.key] = rows
          .map((row) => Map<String, Object?>.from(row.data))
          .toList();
    }
    return BackupSnapshot.create(createdAt: createdAt, records: records);
  }

  Future<Map<String, int>> counts() => db.transaction(
    () async => {
      for (final table in backupColumns.keys)
        table:
            (await db
                    .customSelect('SELECT COUNT(*) AS n FROM $table')
                    .getSingle())
                .read<int>('n'),
    },
  );

  Future<void> restore(BackupSnapshot snapshot) async {
    // Revalidate the immutable import before the first DELETE.
    final checked = BackupSnapshot.fromJson(snapshot.toJson());
    await db.transaction(() async {
      // Consistent pre-replacement in-memory copy; SQLite itself retains the old pages until commit.
      await _capture(snapshot.createdAtUtc);
      await db.delete(db.payments).go();
      await db.delete(db.devices).go();
      await db.delete(db.charges).go();
      await db.delete(db.clients).go();
      await db.delete(db.appSettings).go();
      for (final table in backupColumns.entries) {
        final columns = table.value;
        await db.batch((batch) {
          for (final row in checked.records[table.key]!) {
            batch.customStatement(
              'INSERT INTO ${table.key} (${columns.join(',')}) VALUES (${List.filled(columns.length, '?').join(',')})',
              columns.map((column) => row[column]).toList(),
            );
          }
        });
        await afterTableImported?.call(table.key);
      }
      await _checkIntegrity();
      final actual = await _capture(checked.createdAtUtc);
      if (jsonEncode(actual.records) != jsonEncode(checked.records)) {
        throw const BackupException(
          'La verificación final no coincide. Se conserva la base anterior.',
        );
      }
      // Drift delivers updates only after the transaction commits, including custom INSERTs.
      db.markTablesUpdated(db.allTables.toSet());
    });
  }

  Future<void> markExported(DateTime createdAt) => db.transaction(() async {
    await (db.update(db.appSettings)..where((row) => row.id.equals(1))).write(
      AppSettingsCompanion(
        lastBackupAt: Value(createdAt.millisecondsSinceEpoch),
      ),
    );
  });

  Future<void> _checkIntegrity() async {
    final integrity = await db.customSelect('PRAGMA integrity_check').get();
    final foreignKeys = await db.customSelect('PRAGMA foreign_key_check').get();
    if (integrity.length != 1 ||
        integrity.single.data.values.single != 'ok' ||
        foreignKeys.isNotEmpty) {
      throw const BackupException(
        'La base no supera la comprobación de integridad o relaciones.',
      );
    }
  }
}
