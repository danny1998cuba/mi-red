import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/backups/backup_cipher.dart';
import 'package:mi_red/features/backups/backup_documents.dart';
import 'package:mi_red/features/backups/backup_service.dart';
import 'package:mi_red/features/backups/backup_snapshot.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';

import 'backup_fixture.dart';

void main() {
  late AppDatabase db;
  late BackupService service;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);
  });
  tearDown(() => db.close());
  Future<String> fingerprint() async =>
      jsonEncode((await service.capture(backupTestDate)).records);

  for (final schema in [2, 3, 4]) {
    test(
      'P18 format 1 schema $schema file restores all legacy data intact',
      () async {
        final legacyJson =
            (schema == 4
                    ? syntheticGroupedV4Backup()
                    : syntheticBackup(schema: schema))
                .toJson();
        final legacy = BackupSnapshot.fromJson(legacyJson);
        final cipher = AuthenticatedBackupCipher();
        const password = 'Clave sintética anterior 2026';
        final dir = await Directory.systemTemp.createTemp('mi-red-t09-legacy-');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/legacy.miredbk');
        await file.writeAsBytes(await cipher.encrypt(legacy, password));
        final imported = await cipher.decrypt(
          await file.readAsBytes(),
          password,
        );
        expect(imported.sourceSchemaVersion, schema);
        expect(imported.toJson(), legacyJson);
        await service.restore(imported);
        final captured = await service.capture(backupTestDate);
        expect(captured.sourceSchemaVersion, 5);
        expect(captured.records, legacy.currentRecords);
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          5,
        );
      },
    );
  }

  test('P19/P20 restores active and voided groups and rejects invalid copies atomically', () async {
    await service.restore(syntheticBackup(schema: 3));
    final payments = PaymentService(db);
    final when = DateTime(2026, 10, 29, 12);
    final first = await payments.previewBatch('active', when, count: 2);
    await payments.registerBatch(first, paidAt: when);
    final second = await payments.previewBatch('active', when, count: 2);
    await payments.registerBatch(second, paidAt: when);
    await payments.voidBatch(
      first.id,
      voidedAt: when.add(const Duration(minutes: 1)),
      expectedActiveIds: (await payments.batchesForClient('active'))
          .firstWhere((group) => group.batch.id == first.id)
          .active
          .map((row) => row.payment.id)
          .toSet(),
    );
    final snapshot = await service.capture(when);
    expect(snapshot.counts['payment_batches'], 2);
    expect(
      snapshot.records['payments']!.where((row) => row['batch_id'] != null),
      hasLength(4),
    );
    final cipher = AuthenticatedBackupCipher();
    const password = 'Clave sintética agrupada 2026';
    final dir = await Directory.systemTemp.createTemp('mi-red-t09-current-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/current.miredbk');
    await file.writeAsBytes(await cipher.encrypt(snapshot, password));
    await service.restore(syntheticBackup());
    final bytes = await file.readAsBytes();
    await service.restore(await cipher.decrypt(bytes, password));
    expect((await service.capture(when)).toJson(), snapshot.toJson());
    final groups = await payments.batchesForClient('active');
    expect(groups.where((group) => group.batch.voidedAt == null), hasLength(1));
    expect(groups.every((group) => group.payments.length == 2), isTrue);
    final before = await fingerprint();
    await expectLater(
      cipher.decrypt(bytes, 'Incorrecta'),
      throwsA(isA<BackupException>()),
    );
    bytes[bytes.length - 1] ^= 1;
    await expectLater(
      cipher.decrypt(bytes, password),
      throwsA(isA<BackupException>()),
    );
    for (final field in ['total_minor', 'client_id', 'voided_at', 'paid_at']) {
      final invalid =
          jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>;
      invalid['records']['payment_batches'][0][field] = field == 'client_id'
          ? 'archived'
          : 1;
      expect(
        () => BackupSnapshot.fromJson(invalid),
        throwsA(isA<BackupException>()),
      );
    }
    final incomplete =
        jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>;
    (incomplete['records']['payments'] as List).removeWhere(
      (row) => row['batch_id'] == first.id,
    );
    incomplete['counts']['payments'] -= 2;
    expect(
      () => BackupSnapshot.fromJson(incomplete),
      throwsA(isA<BackupException>()),
    );
    expect(await fingerprint(), before);
  });

  test('T09.1 schema 5 authenticated backup preserves all three group states and survives SQLite reopen', () async {
    final disk = await Directory.systemTemp.createTemp('mi-red-t091-restore-');
    addTearDown(() => disk.delete(recursive: true));
    final dbFile = File('${disk.path}/roundtrip.sqlite');
    final old = syntheticGroupedV4Backup();
    await service.restore(old);
    final payments = PaymentService(db);
    final date = DateTime(2026, 10, 29, 12);
    final quote = await payments.previewBatch('active', date, count: 12);
    await payments.registerBatch(quote, paidAt: date);
    final group = (await payments.batchesForClient('active'))
        .singleWhere((row) => row.batch.id == quote.id);
    await payments.voidPayment(
      group.payments[4].payment.id,
      expectedBatchId: group.batch.id,
      expectedClientId: group.batch.clientId,
      voidedAt: date,
    );
    final snapshot = await service.capture(date);
    expect(snapshot.sourceSchemaVersion, 5);
    final cipher = AuthenticatedBackupCipher();
    const password = 'Clave sintética T09.1 para pruebas';
    final file = File('${disk.path}/roundtrip.miredbk');
    await file.writeAsBytes(await cipher.encrypt(snapshot, password));
    await db.close();
    final target = AppDatabase(NativeDatabase(dbFile));
    try {
      await BackupService(target)
          .restore(await cipher.decrypt(await file.readAsBytes(), password));
    } finally {
      await target.close();
    }
    final reopened = AppDatabase(NativeDatabase(dbFile));
    try {
      expect(
        (await BackupService(reopened).capture(date)).toJson(),
        snapshot.toJson(),
      );
      final histories = await PaymentService(reopened)
          .batchesForClient('active');
      expect(
        histories.map((row) => row.status),
        unorderedEquals(BatchStatus.values),
      );
      expect(
        histories
            .where((row) => row.status == BatchStatus.partiallyVoided)
            .single
            .active,
        hasLength(11),
      );
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await reopened.close();
    }
    final mislabeled = snapshot.toJson()..['sourceSchemaVersion'] = 4;
    expect(
      () => BackupSnapshot.fromJson(mislabeled),
      throwsA(isA<BackupException>()),
    );
  });

  test(
    'schema 5 free device types survive encryption, restore and re-export',
    () async {
      final json = jsonDecode(
        jsonEncode(syntheticBackup().toJson()),
      ) as Map<String, dynamic>;
      json['records']['devices'][0]['type'] = 'Switch PoE · 8 puertos';
      final custom = BackupSnapshot.fromJson(json);
      final cipher = AuthenticatedBackupCipher();
      const password = 'Clave sintética equipos nuevos';
      final bytes = await cipher.encrypt(custom, password);
      await service.restore(await cipher.decrypt(bytes, password));
      expect((await service.capture(backupTestDate)).toJson(), custom.toJson());
    },
  );

  test('consistent six-table snapshot retains every exact raw column, integer, ID and nullable IP', () async {
    final fixture = syntheticBackup();
    await insertSyntheticBackup(db, fixture);
    final captured = await service.capture(backupTestDate);
    expect(captured.toJson(), fixture.toJson());
    expect(BackupSnapshot.decode(captured.encode()).toJson(), fixture.toJson());
    expect(
      captured.records['payments']!.where((p) => p['voided_at'] != null),
      hasLength(2),
    );
  });

  test('restore replaces existing data, preserves archived gaps and never reconciles during import', () async {
    final fixture = syntheticBackup();
    await db.customStatement(
      "INSERT INTO clients VALUES ('other','Otra alta sintética',NULL,NULL,77,'suspended',NULL,1,1,NULL,'2026-10')",
    );
    await service.restore(fixture);
    expect(await fingerprint(), jsonEncode(fixture.records));
    expect(await service.counts(), fixture.counts);
    await service.restore(fixture);
    expect(await fingerprint(), jsonEncode(fixture.records));
    // Reconciliation is a distinct, subsequent action using unchanged T02 rules.
    await BillingService(db)
        .reconcile(today: LocalDate(2026, 12, 3), recordedAt: backupTestDate);
    final after = await service.capture(backupTestDate);
    expect(after.records['payments'], fixture.records['payments']);
    expect(
      after.records['charges']!.where((c) => c['client_id'] == 'active'),
      hasLength(4),
    );
    expect(
      after.records['charges']!.where((c) => c['client_id'] == 'archived'),
      hasLength(1),
    );
  });

  test('empty installation and empty backup round trip including exact singleton settings', () async {
    final empty = await service.capture(backupTestDate);
    await service.restore(syntheticBackup());
    await service.restore(empty);
    expect(await fingerprint(), jsonEncode(empty.records));
  });

  test(
    'signed 64-bit money retains exact precision through JSON and SQLite',
    () async {
      final json = jsonDecode(
        jsonEncode(syntheticBackup().toJson()),
      ) as Map<String, dynamic>;
      json['records']['clients'][0]['monthly_fee_minor'] = 9223372036854775807;
      json['records']['charges'][1]['amount_minor'] = 9223372036854775807;
      final snapshot = BackupSnapshot.fromJson(json);
      final decoded = BackupSnapshot.decode(snapshot.encode());
      await service.restore(decoded);
      expect((await service.capture(backupTestDate)).records, snapshot.records);
      expect(
        decoded.records['charges']![1]['amount_minor'],
        9223372036854775807,
      );
    },
  );

  test('failure halfway through real file transaction rolls back all tables and survives reopen', () async {
    await db.close();
    final dir = await Directory.systemTemp.createTemp('mi-red-t07-rollback-');
    final file = File('${dir.path}/rollback.sqlite');
    db = AppDatabase(NativeDatabase(file));
    service = BackupService(db);
    await insertSyntheticBackup(db, syntheticBackup());
    final before = await fingerprint();
    final replacement = syntheticBackup(notifications: false);
    // The injected exception occurs after new parents/devices are inserted and every old table deleted.
    final failing = BackupService(
      db,
      afterTableImported: (table) async {
        if (table == 'devices') {
          throw StateError('Injected import interruption');
        }
      },
    );
    await expectLater(failing.restore(replacement), throwsStateError);
    expect(await fingerprint(), before);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    service = BackupService(db);
    expect(await fingerprint(), before);
    expect((await db.customSelect('PRAGMA foreign_key_check').get()), isEmpty);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      5,
    );
    await db.close();
    await dir.delete(recursive: true);
  });

  test('watchers receive committed replacement without intermediate empty or mixed data', () async {
    final emitted = <List<String>>[];
    final subscription = db
        .select(db.clients)
        .watch()
        .listen((rows) => emitted.add(rows.map((r) => r.id).toList()..sort()));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final gate = Completer<void>(), entered = Completer<void>();
    final restoring = BackupService(
      db,
      afterTableImported: (table) async {
        if (table == 'clients') {
          entered.complete();
          await gate.future;
        }
      },
    ).restore(syntheticBackup());
    await entered.future;
    expect(emitted, [<String>[]]);
    gate.complete();
    await restoring;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(emitted.last, ['active', 'archived', 'suspended']);
    expect(emitted, hasLength(2));
    await subscription.cancel();
  });

  test('export date only changes after confirmed external save and is distinct from captured source settings', () async {
    final initial = await service.capture(backupTestDate);
    await service.markExported(backupTestDate);
    expect(
      (await db.select(db.appSettings).getSingle()).lastBackupAt,
      backupTestDate.millisecondsSinceEpoch,
    );
    await service.restore(initial);
    expect((await db.select(db.appSettings).getSingle()).lastBackupAt, isNull);
  });

  final corruptions = <String, void Function(Map<String, dynamic>)>{
    'future format': (j) => j['backupFormatVersion'] = 99,
    'floating format': (j) => j['backupFormatVersion'] = 1.0,
    'future schema': (j) => j['sourceSchemaVersion'] = 6,
    'floating schema': (j) => j['sourceSchemaVersion'] = 3.0,
    'empty device type': (j) => j['records']['devices'][0]['type'] = '  ',
    'null device type': (j) => j['records']['devices'][0]['type'] = null,
    'non-text device type': (j) => j['records']['devices'][0]['type'] = 42,
    'legacy missing IP': (j) => j['records']['devices'][0].remove('ip_address'),
    'different app': (j) => j['appIdentifier'] = 'another.app',
    'broken foreign key': (j) =>
        j['records']['devices'][0]['client_id'] = 'missing',
    'negative money': (j) => j['records']['charges'][0]['amount_minor'] = -1,
    'floating money': (j) =>
        j['records']['clients'][0]['monthly_fee_minor'] = 1.5,
    'required column missing': (j) =>
        j['records']['clients'][0].remove('full_name'),
    'duplicate primary key': (j) =>
        j['records']['clients'][0]['id'] = j['records']['clients'][1]['id'],
    'duplicate client period': (j) {
      j['records']['charges'][0] = {
        ...j['records']['charges'][1],
        'id': 'duplicate-period-charge',
      };
    },
    'invalid date': (j) =>
        j['records']['charges'][0]['collection_date'] = '2026-02-30',
    'invalid service status': (j) =>
        j['records']['clients'][0]['status'] = 'deleted',
    'invalid active payment amount': (j) =>
        j['records']['payments'][0]['amount_minor'] = 999,
    'two active payments': (j) {
      j['records']['payments'].add({
        ...j['records']['payments'][0],
        'id': 'another-active-payment',
      });
      j['counts']['payments']++;
    },
    'incorrect count': (j) => j['counts']['devices'] = 99,
    'unexpected column': (j) => j['records']['devices'][0]['new_column'] = 1,
  };
  for (final entry in corruptions.entries) {
    test('rejects ${entry.key} before writing any data', () async {
      final before = await fingerprint();
      final json = jsonDecode(
        jsonEncode(syntheticBackup().toJson()),
      ) as Map<String, dynamic>;
      entry.value(json);
      expect(
        () => BackupSnapshot.fromJson(json),
        throwsA(isA<BackupException>()),
      );
      expect(await fingerprint(), before);
    });
  }

  test('legacy schema 2 still rejects free-text device types before replacing data', () async {
    final before = await fingerprint();
    final json = jsonDecode(
      jsonEncode(syntheticBackup(schema: 2).toJson()),
    ) as Map<String, dynamic>;
    json['records']['devices'][0]['type'] = 'Switch';
    expect(
      () => BackupSnapshot.fromJson(json),
      throwsA(isA<BackupException>()),
    );
    expect(await fingerprint(), before);
  });

  test('private cache cleanup removes owned interrupted copies and preserves unrelated files', () async {
    final cache = await Directory.systemTemp.createTemp(
      'mi-red-t07-cache-test-',
    );
    try {
      final exportDir = await Directory('${cache.path}/mi_red_backup-test')
          .create();
      final importDir = await Directory('${cache.path}/file_dialog-test')
          .create();
      await File('${exportDir.path}/encrypted.miredbk').writeAsBytes([1, 2, 3]);
      await File('${importDir.path}/picked.miredbk').writeAsBytes([4, 5, 6]);
      final legacy = File('${cache.path}/MiRed-20261030T010000Z.miredbk123456');
      await legacy.writeAsBytes([7]);
      final keep = File('${cache.path}/unrelated.miredbk');
      await keep.writeAsBytes([8]);
      final unrelated = await Directory('${cache.path}/other-cache').create();
      await cleanBackupCache(cache);
      expect(await exportDir.exists(), isFalse);
      expect(await importDir.exists(), isFalse);
      expect(await legacy.exists(), isFalse);
      expect(await keep.readAsBytes(), [8]);
      expect(await unrelated.exists(), isTrue);
    } finally {
      await cache.delete(recursive: true);
    }
  });

  group('authenticated encrypted format', () {
    const password = 'Contraseña sintética 👋 T07';
    late AuthenticatedBackupCipher cipher;
    late Uint8List encrypted;
    setUpAll(() async {
      cipher = AuthenticatedBackupCipher();
      encrypted = await cipher.encrypt(syntheticBackup(), password);
    });
    test('AES-256-GCM / PBKDF2 round trip with Unicode password and fresh salt/nonce/ciphertext', () async {
      final another = await cipher.encrypt(syntheticBackup(), password);
      expect(another.sublist(16, 32), isNot(encrypted.sublist(16, 32)));
      expect(another.sublist(32, 44), isNot(encrypted.sublist(32, 44)));
      expect(another.sublist(44), isNot(encrypted.sublist(44)));
      expect(
        (await cipher.decrypt(encrypted, password)).toJson(),
        syntheticBackup().toJson(),
      );
      final visible = latin1.decode(encrypted);
      for (final value in [
        '+12025550123',
        '192.0.2.7',
        '2001:db8::7',
        'monthly_fee_minor',
        'Prueba T07',
      ]) {
        expect(visible.contains(value), isFalse);
      }
    });
    test('wrong password and byte changes in ciphertext, salt, nonce or tag cannot touch DB', () async {
      final before = await fingerprint();
      await expectLater(
        cipher.decrypt(encrypted, 'Contraseña incorrecta'),
        throwsA(isA<BackupException>()),
      );
      for (final offset in [16, 32, 44, encrypted.length - 1]) {
        final changed = Uint8List.fromList(encrypted);
        changed[offset] ^= 1;
        await expectLater(
          cipher.decrypt(changed, password),
          throwsA(isA<BackupException>()),
        );
      }
      expect(await fingerprint(), before);
    });
    test(
      'empty/truncated/oversized and altered KDF/version headers fail safely',
      () async {
        for (final bytes in [
          Uint8List(0),
          encrypted.sublist(0, 20),
          encrypted.sublist(0, encrypted.length - 1),
          Uint8List(maxBackupFileBytes + 1),
        ]) {
          await expectLater(
            cipher.decrypt(bytes, password),
            throwsA(isA<BackupException>()),
          );
        }
        for (final offset in [0, 8, 12]) {
          final changed = Uint8List.fromList(encrypted);
          changed[offset] ^= 1;
          await expectLater(
            cipher.decrypt(changed, password),
            throwsA(isA<BackupException>()),
          );
        }
        expect(
          () => BackupSnapshot.decode(List.filled(maxBackupPlainBytes + 1, 0)),
          throwsA(isA<BackupException>()),
        );
      },
    );
    test(
      'password minimum and bounded payload encoder prevent unbounded export',
      () async {
        await expectLater(
          cipher.encrypt(syntheticBackup(), 'short'),
          throwsA(isA<BackupException>()),
        );
        final json = jsonDecode(
          jsonEncode(syntheticBackup().toJson()),
        ) as Map<String, dynamic>;
        final rows = json['records']['clients'] as List;
        final original = rows.first as Map;
        for (var i = 0; i < 260; i++) {
          rows.add({
            ...original,
            'id': 'large-$i',
            'notes': List.filled(65536, 'x').join(),
          });
        }
        json['counts']['clients'] = rows.length;
        final large = BackupSnapshot.fromJson(json);
        expect(() => large.encode(), throwsA(isA<BackupException>()));
      },
    );
    test(
      'read-only plaintext buffers from platform adapters remain recoverable',
      () async {
        final compatible = AuthenticatedBackupCipher(cipher: _ReadOnlyAesGcm());
        expect(
          (await compatible.decrypt(encrypted, password)).toJson(),
          syntheticBackup().toJson(),
        );
      },
    );
    test('API 24/25 unsupported native KDF falls back without changing key or format', () async {
      final compatible = AuthenticatedBackupCipher(
        keyDerivation: _UnsupportedPbkdf2(),
      );
      expect(
        (await compatible.decrypt(encrypted, password)).toJson(),
        syntheticBackup().toJson(),
      );
    });
  });
}

class _UnsupportedPbkdf2 extends Pbkdf2 {
  _UnsupportedPbkdf2() : super.constructor();
  @override
  int get bits => 256;
  @override
  int get iterations => backupKdfIterations;
  @override
  MacAlgorithm get macAlgorithm => Hmac.sha256();
  @override
  Future<SecretKey> deriveKey({
    required SecretKey secretKey,
    required List<int> nonce,
  }) => throw PlatformException(code: 'UNSUPPORTED_ALGORITHM');
}

class _ReadOnlyAesGcm extends AesGcm {
  _ReadOnlyAesGcm() : super.constructor();
  final _delegate = DartAesGcm(secretKeyLength: 32);
  @override
  int get secretKeyLength => 32;
  @override
  int get nonceLength => 12;
  @override
  Future<SecretBox> encrypt(
    List<int> clearText, {
    required SecretKey secretKey,
    List<int>? nonce,
    List<int> aad = const [],
    Uint8List? possibleBuffer,
  }) => _delegate.encrypt(
    clearText,
    secretKey: secretKey,
    nonce: nonce,
    aad: aad,
  );
  @override
  Future<List<int>> decrypt(
    SecretBox box, {
    required SecretKey secretKey,
    List<int> aad = const [],
    Uint8List? possibleBuffer,
  }) async => List<int>.unmodifiable(
    await _delegate.decrypt(box, secretKey: secretKey, aad: aad),
  );
}
