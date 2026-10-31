import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../generated_migrations/schema.dart';

const _tables = ['clients', 'devices', 'charges', 'payments', 'app_settings'];

void seedVersionOne(Database raw) {
  raw.execute('PRAGMA foreign_keys = ON');
  raw.execute("""
    INSERT INTO clients VALUES ('legacy-client', 'Cliente sintético v1', '+000 000000',
      'Dirección de prueba', 12550, 'active', 'Nota v1', 1700000000123,
      1700000000456, NULL, '2026-11');
    INSERT INTO devices VALUES ('legacy-a', 'legacy-client', 'antenna', '02:00:00:00:00:01', 'Antena v1');
    INSERT INTO devices VALUES ('legacy-b', 'legacy-client', 'router', '02:00:00:00:00:02', 'Router v1');
    INSERT INTO charges VALUES ('legacy-nov', 'legacy-client', '2026-11', '2026-10-30', '2026-11-03', 10000, 1700000000789);
    INSERT INTO charges VALUES ('legacy-dec', 'legacy-client', '2026-12', '2026-11-30', '2026-12-03', 12550, 1700000000890);
    INSERT INTO payments VALUES ('legacy-void', 'legacy-nov', 10000, 1700000000900, 'Anulado de prueba', 1700000000950);
    INSERT INTO payments VALUES ('legacy-paid', 'legacy-nov', 10000, 1700000000990, 'Pago de prueba', NULL);
    INSERT INTO app_settings VALUES (1, 'Negocio sintético', 'unidad', '+000', 0, 1700000000999);
  """);
}

Map<String, Object?> snapshotData(Database raw) => {
  for (final table in _tables)
    table: raw
        .select('SELECT * FROM $table ORDER BY id')
        .map((row) => Map<String, Object?>.from(row))
        .toList(),
};

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test(
    'v1 file migrates to v3, preserves every old value and reopens repeatedly',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mi_red_ip_migration_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/legacy.sqlite');
      final old = GeneratedHelper().databaseForVersion(NativeDatabase(file), 1);
      await old.customSelect('SELECT 1').get();
      await old.close();
      final raw = sqlite3.open(file.path);
      seedVersionOne(raw);
      expect(raw.select('PRAGMA user_version').single['user_version'], 1);
      expect(
        raw
            .select('PRAGMA table_info(devices)')
            .any((row) => row['name'] == 'ip_address'),
        isFalse,
      );
      final before = snapshotData(raw);
      final oldSchema = raw
          .select(
            "SELECT name, sql FROM sqlite_master WHERE name != 'devices' ORDER BY name",
          )
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      raw.close();

      for (var reopen = 0; reopen < 3; reopen++) {
        final db = AppDatabase(NativeDatabase(file));
        try {
          await verifier.migrateAndValidate(
            db,
            3,
            options: const ValidationOptions(validateDropped: true),
          );
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            3,
          );
          expect(
            (await db.customSelect('PRAGMA foreign_keys').getSingle())
                .read<int>('foreign_keys'),
            1,
          );
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          expect(
            (await db.customSelect('PRAGMA integrity_check').getSingle())
                .read<String>('integrity_check'),
            'ok',
          );
          expect(
            (await db.select(db.devices).get()).map(
              (device) => device.ipAddress,
            ),
            [null, null],
          );
          final columns = await db
              .customSelect('PRAGMA table_info(devices)')
              .get();
          expect(
            columns
                .where((row) => row.data['name'] == 'ip_address')
                .single
                .data['notnull'],
            0,
          );
          final after = <String, Object?>{};
          for (final table in _tables) {
            after[table] =
                (await db
                        .customSelect('SELECT * FROM $table ORDER BY id')
                        .get())
                    .map((row) {
                      final data = Map<String, Object?>.from(row.data);
                      if (table == 'devices') data.remove('ip_address');
                      return data;
                    })
                    .toList();
          }
          expect(after, before);
          expect(
            (await db
                    .customSelect(
                      "SELECT name, sql FROM sqlite_master WHERE name != 'devices' ORDER BY name",
                    )
                    .get())
                .map((row) => row.data)
                .toList(),
            oldSchema,
          );
        } finally {
          await db.close();
        }
      }
    },
  );

  test('Invalid v1 foreign keys abort and roll back the added column', () async {
    final schema = await verifier.schemaAt(1);
    addTearDown(schema.close);
    final raw = schema.rawDatabase;
    raw.execute('PRAGMA foreign_keys = OFF');
    raw.execute(
      "INSERT INTO devices VALUES ('orphan', 'missing', 'router', NULL, NULL)",
    );
    final db = AppDatabase(schema.newConnection());
    try {
      await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
      expect(raw.select('PRAGMA user_version').single['user_version'], 1);
      expect(
        raw
            .select('PRAGMA table_info(devices)')
            .any((row) => row['name'] == 'ip_address'),
        isFalse,
      );
      expect(raw.select('SELECT count(*) AS n FROM devices').single['n'], 1);
    } finally {
      await db.close();
    }
  });

  test('v2 snapshot only appends a nullable IP column to v1 devices', () {
    final v1 = jsonDecode(
      File('drift_schemas/drift_schema_v1.json').readAsStringSync(),
    ) as Map;
    final v2 = jsonDecode(
      File('drift_schemas/drift_schema_v2.json').readAsStringSync(),
    ) as Map;
    final oldSql = (v1['fixed_sql'] as List)
        .where((entry) => entry['name'] != 'devices')
        .toList();
    final newSql = (v2['fixed_sql'] as List)
        .where((entry) => entry['name'] != 'devices')
        .toList();
    expect(newSql, oldSql);
  });
}
