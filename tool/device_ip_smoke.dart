import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_connection.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/clients/data/device_service.dart';
import 'package:mi_red/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const _clientId = 't032-synthetic-smoke-client';
const _deviceId = 't032-synthetic-smoke-device';
const _tables = ['clients', 'devices', 'charges', 'payments', 'app_settings'];

/// Opt-in emulator-only diagnostic, never used by lib/main.dart.
/// Write mode requires a preexisting v1 file. Customer values stay in memory.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment('MI_RED_IP_SMOKE');
  AppDatabase? db;
  try {
    if (mode != 'write' && mode != 'check') throw StateError('Mode required');
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/mi_red.sqlite');
    if (!await file.exists()) throw StateError('Existing database required');
    final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
    late final String before;
    late final Map<String, int> counts;
    try {
      final version = raw.select('PRAGMA user_version').single['user_version'];
      if (version != (mode == 'write' ? 1 : 3)) {
        throw StateError('Unexpected version');
      }
      before = jsonEncode({
        for (final table in _tables)
          table: raw
              .select('SELECT * FROM $table ORDER BY id')
              .map((row) => Map<String, Object?>.from(row))
              .toList(),
      });
      counts = {
        for (final table in _tables)
          table:
              raw.select('SELECT count(*) AS n FROM $table').single['n'] as int,
      };
      if (counts['clients']! < 1 || counts['devices']! < 1) {
        throw StateError('Existing data required');
      }
    } finally {
      raw.close();
    }
    db = AppDatabase(openAppDatabase());
    await db.customSelect('SELECT 1').get();
    if (mode == 'write') {
      final after = <String, Object?>{};
      for (final table in _tables) {
        final projection = table == 'devices'
            ? 'id, client_id, type, mac_address, notes'
            : '*';
        after[table] =
            (await db
                    .customSelect('SELECT $projection FROM $table ORDER BY id')
                    .get())
                .map((row) => row.data)
                .toList();
      }
      if (jsonEncode(after) != before) {
        throw StateError('Previous data changed');
      }
      if ((await db.select(db.devices).get()).any(
        (row) => row.ipAddress != null,
      )) {
        throw StateError('Legacy IP must be null');
      }
      if ((await db.customSelect('PRAGMA foreign_key_check').get())
          .isNotEmpty) {
        throw StateError('Invalid foreign keys');
      }
      debugPrint(
        'MI_RED_IP_V1_PRESERVED clients=${counts['clients']} devices=${counts['devices']} charges=${counts['charges']} payments=${counts['payments']} settings=${counts['app_settings']}',
      );
      final clients = ClientService(db, BillingService(db));
      await clients.create(
        id: _clientId,
        fullName: 'Prueba sintética T03.2',
        monthlyFeeMinor: 0,
        status: ServiceStatus.suspended,
        today: LocalDate.fromDateTime(DateTime.now()),
      );
      await DeviceService(db).save(
        id: _deviceId,
        clientId: _clientId,
        type: 'router',
        macAddress: '02:00:00:03:02:01',
        ipAddress: const Value('192.0.2.32'),
        notes: 'Dispositivo sintético del smoke T03.2',
      );
      await db.close();
      db = AppDatabase(openAppDatabase());
    }
    final device = (await DeviceService(db).forClient(_clientId)).single;
    if (device.id != _deviceId ||
        device.ipAddress != '192.0.2.32' ||
        device.macAddress != '02:00:00:03:02:01') {
      throw StateError('IP not persisted');
    }
    if ((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty ||
        (await db.customSelect('PRAGMA integrity_check').getSingle())
                .read<String>('integrity_check') !=
            'ok') {
      throw StateError('Integrity failure');
    }
    debugPrint(
      mode == 'write'
          ? 'MI_RED_IP_WRITE_REOPEN_OK'
          : 'MI_RED_IP_COLD_RESTART_OK',
    );
  } catch (_) {
    // Never log SQL rows, real MACs or exception payloads containing customer data.
    debugPrint('MI_RED_IP_SMOKE_FAILED');
  } finally {
    await db?.close();
  }
  app.main();
}
