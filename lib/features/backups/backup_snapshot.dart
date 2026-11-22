import 'dart:convert';
import 'dart:typed_data';

import '../billing/billing_calendar.dart';
import '../clients/data/device_service.dart';

const backupFormatVersion = 1;
const backupAppIdentifier = 'com.mired.offline';
const maxBackupPlainBytes = 16 * 1024 * 1024;
const maxBackupRows = 100000;

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

// Column names and insertion order come from this allowlist, never the file.
const _commonColumns = <String, List<String>>{
  'clients': [
    'id',
    'full_name',
    'phone',
    'address',
    'monthly_fee_minor',
    'status',
    'notes',
    'created_at',
    'updated_at',
    'archived_at',
    'billing_start_period',
  ],
  'devices': ['id', 'client_id', 'type', 'mac_address', 'notes', 'ip_address'],
  'charges': [
    'id',
    'client_id',
    'period_key',
    'collection_date',
    'suspension_candidate_date',
    'amount_minor',
    'created_at',
  ],
  'app_settings': [
    'id',
    'business_name',
    'currency_label',
    'default_calling_code',
    'notifications_enabled',
    'last_backup_at',
  ],
};

const _legacyPayments = [
  'id',
  'charge_id',
  'amount_minor',
  'paid_at',
  'note',
  'voided_at',
];
const legacyBackupColumns = {..._commonColumns, 'payments': _legacyPayments};

const backupColumns = <String, List<String>>{
  ..._commonColumns,
  'payment_batches': ['id', 'client_id', 'paid_at', 'total_minor', 'voided_at'],
  'payments': [..._legacyPayments, 'batch_id'],
};

class BackupSnapshot {
  BackupSnapshot._(this.createdAtUtc, this.records, this.sourceSchemaVersion);
  final int sourceSchemaVersion;
  final DateTime createdAtUtc;
  final Map<String, List<Map<String, Object?>>> records;
  Map<String, List<Map<String, Object?>>> get currentRecords =>
      sourceSchemaVersion >= 4
      ? records
      : {
          for (final table in backupColumns.keys)
            table: switch (table) {
              'payment_batches' => const [],
              'payments' => [
                for (final row in records[table]!) {...row, 'batch_id': null},
              ],
              _ => records[table]!,
            },
        };
  Map<String, int> get counts => {
    for (final entry in records.entries) entry.key: entry.value.length,
  };

  factory BackupSnapshot.create({
    required DateTime createdAt,
    required Map<String, List<Map<String, Object?>>> records,
  }) => BackupSnapshot.fromJson({
    'format': 'mi-red-backup',
    'backupFormatVersion': backupFormatVersion,
    'sourceSchemaVersion': 5,
    'createdAtUtc': createdAt.toUtc().toIso8601String(),
    'appIdentifier': backupAppIdentifier,
    'counts': {
      for (final entry in records.entries) entry.key: entry.value.length,
    },
    'records': records,
  });

  factory BackupSnapshot.decode(List<int> bytes) {
    if (bytes.length > maxBackupPlainBytes) {
      throw const BackupException('La copia supera el límite de 16 MiB.');
    }
    try {
      return BackupSnapshot.fromJson(jsonDecode(utf8.decode(bytes)));
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('El contenido de la copia no es válido.');
    }
  }

  factory BackupSnapshot.fromJson(Object? value) {
    try {
      final root = _map(value);
      _keys(root, const [
        'format',
        'backupFormatVersion',
        'sourceSchemaVersion',
        'createdAtUtc',
        'appIdentifier',
        'counts',
        'records',
      ]);
      final schema = root['sourceSchemaVersion'];
      if (root['backupFormatVersion'] is! int ||
          schema is! int ||
          root['format'] != 'mi-red-backup' ||
          root['appIdentifier'] != backupAppIdentifier ||
          root['backupFormatVersion'] != backupFormatVersion ||
          !const [2, 3, 4, 5].contains(schema)) {
        throw const BackupException(
          'Formato, aplicación o versión de copia incompatible. Se requiere formato 1 y esquema del 2 al 5.',
        );
      }
      final createdText = root['createdAtUtc'];
      if (createdText is! String || !createdText.endsWith('Z')) _invalid();
      final created = DateTime.parse(createdText);
      if (!created.isUtc ||
          created.year < 1 ||
          created.year > 9999 ||
          created.toIso8601String() != createdText) {
        _invalid();
      }
      final rawRecords = _map(root['records']);
      final rawCounts = _map(root['counts']);
      final columns = schema >= 4 ? backupColumns : legacyBackupColumns;
      _keys(rawRecords, columns.keys);
      _keys(rawCounts, columns.keys);
      final records = <String, List<Map<String, Object?>>>{};
      var total = 0;
      for (final table in columns.entries) {
        final rows = rawRecords[table.key];
        if (rows is! List ||
            rawCounts[table.key] is! int ||
            rawCounts[table.key] != rows.length) {
          _invalid();
        }
        total += rows.length;
        if (total > maxBackupRows) {
          throw const BackupException(
            'La copia supera el límite de 100000 registros.',
          );
        }
        final ids = <Object?>{};
        final result = <Map<String, Object?>>[];
        for (final value in rows) {
          final row = _map(value);
          _keys(row, table.value);
          if (table.key == 'app_settings') {
            if (row['id'] is! int || row['id'] != 1) _invalid();
          } else {
            _text(row['id'], required: true, maxLength: 1024);
          }
          if (!ids.add(row['id'])) _invalid();
          result.add(
            Map.unmodifiable({
              for (final column in table.value) column: row[column],
            }),
          );
        }
        result.sort((a, b) => a['id'].toString().compareTo(b['id'].toString()));
        records[table.key] = List.unmodifiable(result);
      }
      _validateRows(records, schema);
      return BackupSnapshot._(created, Map.unmodifiable(records), schema);
    } on BackupException {
      rethrow;
    } catch (_) {
      _invalid();
    }
  }

  Map<String, Object?> toJson() => {
    'format': 'mi-red-backup',
    'backupFormatVersion': backupFormatVersion,
    'sourceSchemaVersion': sourceSchemaVersion,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'appIdentifier': backupAppIdentifier,
    'counts': counts,
    'records': records,
  };
  List<int> encode() {
    final sink = _LimitedJsonBytes();
    final encoder = JsonUtf8Encoder().startChunkedConversion(sink);
    encoder.add(toJson());
    encoder.close();
    return sink.bytes.takeBytes();
  }
}

class _LimitedJsonBytes implements Sink<List<int>> {
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > maxBackupPlainBytes) {
      throw const BackupException('La copia supera el límite de 16 MiB.');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

Never _invalid() => throw const BackupException(
  'La copia contiene datos, relaciones o valores inválidos. No se ha reemplazado la base actual.',
);
Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) _invalid();
  return Map<String, Object?>.from(value);
}

void _keys(Map<String, Object?> value, Iterable<String> keys) {
  if (value.length != keys.length ||
      keys.any((key) => !value.containsKey(key))) {
    _invalid();
  }
}

void _text(Object? value, {bool required = false, int maxLength = 65536}) {
  if (value == null && !required) return;
  if (value is! String ||
      value.length > maxLength ||
      (required && value.trim().isEmpty)) {
    _invalid();
  }
}

void _money(Object? value) {
  if (value is! int || value < 0 || value > 9223372036854775807) _invalid();
}

void _instant(Object? value, {bool nullable = false}) {
  if (value == null && nullable) return;
  if (value is! int || value < -62135596800000 || value > 253402300799999) {
    _invalid();
  }
}

void _validateRows(Map<String, List<Map<String, Object?>>> tables, int schema) {
  final clients = {for (final row in tables['clients']!) row['id']: row};
  final charges = {for (final row in tables['charges']!) row['id']: row};
  for (final row in clients.values) {
    _text(row['full_name'], required: true);
    for (final field in ['phone', 'address', 'notes']) {
      _text(row[field]);
    }
    _money(row['monthly_fee_minor']);
    if (!const ['active', 'suspended', 'archived'].contains(row['status']) ||
        (row['status'] == 'archived') != (row['archived_at'] != null)) {
      _invalid();
    }
    _instant(row['created_at']);
    _instant(row['updated_at']);
    _instant(row['archived_at'], nullable: true);
    BillingPeriod.parse(row['billing_start_period'] as String);
  }
  for (final row in tables['devices']!) {
    if (!clients.containsKey(row['client_id']) ||
        (schema == 2 &&
            !const [
              'antenna',
              'ont',
              'router',
              'other',
            ].contains(row['type']))) {
      _invalid();
    }
    _text(row['type'], required: true);
    _text(row['mac_address']);
    _text(row['ip_address']);
    _text(row['notes']);
    final mac = row['mac_address'] as String?;
    if (mac != null && normalizeMacAddress(mac) != mac) _invalid();
    final ip = row['ip_address'] as String?;
    if (ip != null && normalizeIpAddress(ip) == null) _invalid();
  }
  final periods = <(Object?, Object?)>{};
  for (final row in charges.values) {
    if (!clients.containsKey(row['client_id']) ||
        !periods.add((row['client_id'], row['period_key']))) {
      _invalid();
    }
    final period = BillingPeriod.parse(row['period_key'] as String);
    final collection = LocalDate.parse(row['collection_date'] as String);
    final candidate = LocalDate.parse(
      row['suspension_candidate_date'] as String,
    );
    if (collection != period.collectionDate ||
        candidate != period.suspensionCandidateDate) {
      _invalid();
    }
    _money(row['amount_minor']);
    _instant(row['created_at']);
  }
  final activePayments = <Object?>{};
  final batches = {
    for (final row in tables['payment_batches'] ?? <Map<String, Object?>>[])
      row['id']: row,
  };
  final batchPayments = <Object?, List<Map<String, Object?>>>{};
  for (final batch in batches.values) {
    if (!clients.containsKey(batch['client_id'])) _invalid();
    _money(batch['total_minor']);
    _instant(batch['paid_at']);
    _instant(batch['voided_at'], nullable: true);
  }
  for (final row in tables['payments']!) {
    final charge = charges[row['charge_id']];
    if (charge == null) _invalid();
    _money(row['amount_minor']);
    _instant(row['paid_at']);
    _instant(row['voided_at'], nullable: true);
    _text(row['note']);
    final batchId = row['batch_id'];
    if (batchId != null) {
      final batch = batches[batchId];
      if (batch == null ||
          charge['client_id'] != batch['client_id'] ||
          row['paid_at'] != batch['paid_at'] ||
          (schema == 4 && row['voided_at'] != batch['voided_at']) ||
          (batch['voided_at'] != null && row['voided_at'] == null)) {
        _invalid();
      }
      (batchPayments[batchId] ??= []).add(row);
    }
    // An annulled payment may retain a different historical amount after a correction.
    if (row['voided_at'] == null &&
        (!activePayments.add(row['charge_id']) ||
            row['amount_minor'] != charge['amount_minor'])) {
      _invalid();
    }
  }
  for (final batch in batches.values) {
    final children = batchPayments[batch['id']];
    if (children == null ||
        children.length < 2 ||
        children.length > (schema == 4 ? 2 : 12) ||
        children.map((row) => row['charge_id']).toSet().length !=
            children.length) {
      _invalid();
    }
    var remaining = batch['total_minor'] as int;
    for (final row in children) {
      final amount = row['amount_minor'] as int;
      if (amount > remaining) _invalid();
      remaining -= amount;
    }
    final groupVoidedAt = batch['voided_at'];
    if (remaining != 0 ||
        (groupVoidedAt != null &&
            !children.any((row) => row['voided_at'] == groupVoidedAt))) {
      _invalid();
    }
  }
  final settings = tables['app_settings']!;
  if (settings.length != 1) _invalid();
  final row = settings.single;
  _text(row['business_name'], required: true);
  _text(row['currency_label'], required: false);
  if (row['currency_label'] == null) _invalid();
  _text(row['default_calling_code']);
  _instant(row['last_backup_at'], nullable: true);
  if (row['notifications_enabled'] is! int ||
      !const [0, 1].contains(row['notifications_enabled'])) {
    _invalid();
  }
}
