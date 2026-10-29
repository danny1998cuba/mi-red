import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_connection.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/billing_values.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:path_provider/path_provider.dart';

const _id = 't04-synthetic-ui-client';
const _name = 'Prueba sintetica T04';

/// Explicit emulator fixture, never imported by the application entry point.
/// No real customer values or exception payloads are logged or written to files.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment('MI_RED_T04_FIXTURE');
  AppDatabase? db;
  var success = false;
  try {
    if (!{'prepare', 'paid', 'voided', 'archive'}.contains(mode)) {
      throw StateError('Explicit mode required');
    }
    final directory = await getApplicationSupportDirectory();
    if (!await File('${directory.path}/mi_red.sqlite').exists()) {
      throw StateError('Populated emulator database required');
    }
    db = AppDatabase(openAppDatabase());
    final before = await _otherRows(db);
    final today = LocalDate.fromDateTime(DateTime.now());
    final previous = adjacentPeriod(currentPeriod(today), -1)!;
    final older = adjacentPeriod(previous, -1)!;
    final clients = ClientService(db, BillingService(db));
    if (mode == 'prepare') {
      if ((await db.select(db.clients).get()).any((row) => row.id == _id)) {
        throw StateError('Fixture already exists; never overwrite history');
      }
      await db.transaction(() async {
        await clients.create(
          id: _id,
          fullName: _name,
          monthlyFeeMinor: 12345,
          today: LocalDate(older.year, older.month, 2),
        );
        await clients.changeStatus(
          _id,
          ServiceStatus.suspended,
          today: LocalDate(previous.year, previous.month, 2),
        );
        await clients.updateProfile(
          _id,
          fullName: _name,
          monthlyFeeMinor: 99999,
          status: ServiceStatus.suspended,
          today: today,
        );
      });
    }
    final client = await clients.get(_id);
    if (client.fullName != _name || client.monthlyFeeMinor != 99999) {
      throw StateError('Fixture identity/tariff mismatch');
    }
    if (mode == 'archive') {
      await clients.changeStatus(_id, ServiceStatus.archived, today: today);
    } else if (client.status != ServiceStatus.suspended.name) {
      throw StateError('Manual service state changed');
    }
    if (await _otherRows(db) != before) {
      throw StateError('Rows outside the fixture changed');
    }
    await db.close();
    db = AppDatabase(openAppDatabase());
    final history = await BillingService(db)
        .historyForClient(_id, today: today);
    final payments = await PaymentService(db).historyForClient(_id);
    if (history.length != 2 ||
        history.any((row) => row.charge.amountMinor != 12345) ||
        history.first.charge.periodKey != older.key ||
        history.last.charge.periodKey != previous.key) {
      throw StateError('Historical charges changed');
    }
    if (mode == 'paid' &&
        (payments.length != 1 ||
            payments.single.voidedAt != null ||
            history.last.status != ChargeStatus.paid ||
            history.first.activePayment != null)) {
      throw StateError('Expected paid period and older unpaid debt');
    }
    if ((mode == 'voided' || mode == 'archive') &&
        (payments.length != 1 ||
            payments.single.voidedAt == null ||
            payments.single.amountMinor != 12345 ||
            payments.single.note != 'Prueba T04' ||
            history.any((row) => row.activePayment != null))) {
      throw StateError('Expected preserved voided audit');
    }
    if ((await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
              'user_version',
            ) !=
            2 ||
        (await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty ||
        (await db.customSelect('PRAGMA integrity_check').getSingle())
                .read<String>('integrity_check') !=
            'ok') {
      throw StateError('Database integrity failure');
    }
    debugPrint('MI_RED_T04_${mode.toUpperCase()}_OK period=${previous.key}');
    success = true;
  } catch (_) {
    debugPrint('MI_RED_T04_FIXTURE_FAILED');
  } finally {
    await db?.close();
  }
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            success ? 'Diagnóstico T04 completado' : 'Diagnóstico T04 fallido',
          ),
        ),
      ),
    ),
  );
}

Future<String> _otherRows(AppDatabase db) async {
  const predicates = {
    'clients': 'id != ?',
    'devices': 'client_id != ?',
    'charges': 'client_id != ?',
    'payments': 'charge_id NOT IN (SELECT id FROM charges WHERE client_id = ?)',
    'app_settings': '1 = 1',
  };
  final snapshot = <String, Object?>{};
  for (final entry in predicates.entries) {
    // The identifier/predicate are fixed constants; only the synthetic ID varies.
    final rows = await db
        .customSelect(
          'SELECT * FROM ${entry.key} WHERE ${entry.value} ORDER BY id',
          variables: entry.key == 'app_settings'
              ? []
              : [Variable.withString(_id)],
        )
        .get();
    snapshot[entry.key] = rows.map((row) => row.data).toList();
  }
  return jsonEncode(snapshot);
}
