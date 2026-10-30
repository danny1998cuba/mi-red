// Opt-in diagnostic for a NEW, isolated AVD only. Never imported by main.dart.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/material.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_connection.dart';
import 'package:mi_red/features/backups/backup_cipher.dart';
import 'package:mi_red/features/backups/backup_service.dart';

import '../test/features/backups/backup_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment('MI_RED_T07_FIXTURE');
  if (mode != 'prepare' && mode != 'check') {
    debugPrint('MI_RED_T07_FIXTURE_NOT_AUTHORIZED');
    return;
  }
  final db = AppDatabase(openAppDatabase());
  var phase = 'database';
  try {
    final service = BackupService(db);
    final counts = await service.counts();
    if (mode == 'prepare' &&
        counts.entries.any(
          (entry) => entry.key != 'app_settings' && entry.value != 0,
        )) {
      debugPrint('MI_RED_T07_FIXTURE_REQUIRES_EMPTY_DATABASE');
      return;
    }
    final fixture = syntheticBackup();
    if (mode == 'prepare') {
      await insertSyntheticBackup(db, fixture);
    } else {
      if (jsonEncode((await service.capture(backupTestDate)).records) !=
          jsonEncode(fixture.records)) {
        debugPrint('MI_RED_T07_FIXTURE_CHECK_REQUIRES_EXACT_SYNTHETIC_DATA');
        return;
      }
    }
    // Synthetic benchmark only; these values are not a user's backup password.
    const testPhrase = 'Synthetic interoperability 👋 T07';
    phase = 'kdf';
    final cost = Stopwatch()..start();
    final key = await FlutterPbkdf2(
      macAlgorithm: Hmac.sha256(),
      bits: 256,
      iterations: backupKdfIterations,
    ).deriveKeyFromPassword(password: testPhrase, nonce: List.filled(16, 7));
    cost.stop();
    debugPrint(
      'MI_RED_T07_KDF_OK iterations=$backupKdfIterations elapsedMs=${cost.elapsedMilliseconds}',
    );
    final dartKey = await DartPbkdf2(
      macAlgorithm: Hmac.sha256(),
      bits: 256,
      iterations: backupKdfIterations,
    ).deriveKeyFromPassword(password: testPhrase, nonce: List.filled(16, 7));
    final nativeBytes = await key.extractBytes(),
        dartBytes = await dartKey.extractBytes();
    debugPrint(
      'MI_RED_T07_KDF_INTEROP match=${List.generate(nativeBytes.length, (i) => nativeBytes[i] == dartBytes[i]).every((v) => v)}',
    );
    key.destroy();
    dartKey.destroy();
    phase = 'native-encrypt';
    final native = AuthenticatedBackupCipher(nativeAndroid: true);
    final encrypted = await native.encrypt(fixture, testPhrase);
    phase = 'dart-decrypt';
    final portable = await AuthenticatedBackupCipher().decrypt(
      encrypted,
      testPhrase,
    );
    phase = 'portable-compare';
    if (jsonEncode(portable.toJson()) != jsonEncode(fixture.toJson())) {
      throw StateError('Interoperability mismatch');
    }
    phase = 'native-decrypt';
    final nativeDecoded = await native.decrypt(encrypted, testPhrase);
    if (jsonEncode(nativeDecoded.toJson()) != jsonEncode(fixture.toJson())) {
      throw StateError('Native round trip mismatch');
    }
    encrypted.fillRange(0, encrypted.length, 0);
    debugPrint('MI_RED_T07_CRYPTO_INTEROP_OK');
    debugPrint(
      'MI_RED_T07_FIXTURE_OK clients=3 devices=4 charges=4 payments=4 settings=1',
    );
  } catch (error) {
    debugPrint(
      'MI_RED_T07_FIXTURE_FAILED phase=$phase type=${error.runtimeType}',
    );
  } finally {
    await db.close();
  }
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Fixture sintética T07 lista'))),
    ),
  );
}
