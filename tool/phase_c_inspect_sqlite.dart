import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

// Inspect only closed copies from the explicitly synthetic Phase C installations.
// Output contains counts, integrity and fingerprints, never customer field values.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    throw ArgumentError('Expected a synthetic SQLite copy');
  }
  final file = File(File(arguments.single).resolveSymbolicLinksSync());
  final allowed = Directory('build/phase-c').resolveSymbolicLinksSync();
  if (!file.path.startsWith('$allowed${Platform.pathSeparator}')) {
    throw ArgumentError('Use an explicitly synthetic file under build/phase-c');
  }
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    const tables = [
      'clients',
      'devices',
      'charges',
      'payments',
      'app_settings',
    ];
    final records = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      final result = db.select('SELECT * FROM $table ORDER BY id');
      records[table] = [
        for (final row in result)
          {for (final column in result.columnNames) column: row[column]},
      ];
    }
    final schema = db.select('PRAGMA user_version').single.values.single;
    final integrity = db.select('PRAGMA integrity_check').single.values.single;
    final foreignKeyErrors = db.select('PRAGMA foreign_key_check').length;
    final fullHash = await Sha256().hash(utf8.encode(jsonEncode(records)));
    // Exporting intentionally changes this one field after the captured snapshot.
    for (final settings in records['app_settings']!) {
      settings['last_backup_at'] = null;
    }
    final stableHash = await Sha256().hash(utf8.encode(jsonEncode(records)));
    String hex(List<int> bytes) =>
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    stdout.writeln(
      jsonEncode({
        'schema': schema,
        'integrity': integrity,
        'foreignKeyErrors': foreignKeyErrors,
        'counts': {
          for (final entry in records.entries) entry.key: entry.value.length,
        },
        'allTablesSha256': hex(fullHash.bytes),
        'allTablesExceptLastBackupSha256': hex(stableHash.bytes),
      }),
    );
    if (schema != 2 || integrity != 'ok' || foreignKeyErrors != 0) exitCode = 1;
  } finally {
    db.close();
  }
}
