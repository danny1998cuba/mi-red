import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/backups/backup_service.dart';
import 'package:mi_red/features/clients/data/device_service.dart';

import '../../features/backups/backup_fixture.dart';
import '../../generated_migrations/schema.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('v2 file migrates to v3 without changing any data, index or other table', () async {
    final directory = await Directory.systemTemp.createTemp('mi_red_types_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/v2.sqlite');
    final old = GeneratedHelper().databaseForVersion(NativeDatabase(file), 2);
    final fixture = syntheticBackup();
    await old.customSelect('SELECT 1').get();
    for (final entry in fixture.records.entries) {
      for (final row in entry.value) {
        await old.customStatement(
          'INSERT INTO ${entry.key} (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
          row.values.toList(),
        );
      }
    }
    final objects =
        (await old
                .customSelect(
                  "SELECT name, sql FROM sqlite_master WHERE name != 'devices' ORDER BY name",
                )
                .get())
            .map((row) => row.data)
            .toList();
    await old.close();

    for (var reopen = 0; reopen < 2; reopen++) {
      final db = AppDatabase(NativeDatabase(file));
      try {
        await verifier.migrateAndValidate(
          db,
          3,
          options: const ValidationOptions(validateDropped: true),
        );
        expect(
          (await BackupService(db).capture(backupTestDate)).records,
          fixture.records,
        );
        expect(
          (await db
                  .customSelect(
                    "SELECT name, sql FROM sqlite_master WHERE name != 'devices' ORDER BY name",
                  )
                  .get())
              .map((row) => row.data)
              .toList(),
          objects,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
      } finally {
        await db.close();
      }
    }
    final db = AppDatabase(NativeDatabase(file));
    try {
      final result = await DeviceService(db)
          .save(clientId: 'active', type: '  Switch PoE 8 puertos  ');
      expect(result.device.type, 'Switch PoE 8 puertos');
      await expectLater(
        DeviceService(db).save(clientId: 'active', type: '  '),
        throwsArgumentError,
      );
      expect(
        (await db.select(db.devices).get()).length,
        fixture.counts['devices']! + 1,
      );
    } finally {
      await db.close();
    }
  });

  test('invalid v2 foreign keys roll back the complete table rebuild', () async {
    final schema = await verifier.schemaAt(2);
    addTearDown(schema.close);
    final raw = schema.rawDatabase;
    raw.execute('PRAGMA foreign_keys = OFF');
    raw.execute(
      "INSERT INTO devices VALUES ('orphan','missing','router',NULL,NULL,NULL)",
    );
    final sql = raw
        .select("SELECT sql FROM sqlite_master WHERE name = 'devices'")
        .single['sql'];
    final db = AppDatabase(schema.newConnection());
    try {
      await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
      expect(raw.select('PRAGMA user_version').single['user_version'], 2);
      expect(
        raw
            .select("SELECT sql FROM sqlite_master WHERE name = 'devices'")
            .single['sql'],
        sql,
      );
      expect(raw.select('SELECT count(*) AS n FROM devices').single['n'], 1);
    } finally {
      await db.close();
    }
  });
}
