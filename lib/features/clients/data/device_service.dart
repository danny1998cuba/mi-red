import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/record_id.dart';

enum DeviceType { antenna, ont, router, other }

/// Parses numeric addresses locally; never resolves names or opens a socket.
String? normalizeIpAddress(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  // Exclude ports, CIDR, brackets, zones and ambiguous shortened/octal IPv4.
  final numericSyntax = text.contains(':')
      ? RegExp(r'^[0-9a-fA-F:.]+$').hasMatch(text)
      : RegExp(r'^(?:0|[1-9][0-9]{0,2})(?:\.(?:0|[1-9][0-9]{0,2})){3}$')
            .hasMatch(text);
  final address = numericSyntax ? InternetAddress.tryParse(text) : null;
  if (address == null) {
    throw ArgumentError(
      'Introduce una dirección IPv4 o IPv6 válida, sin puerto ni prefijo de red.',
    );
  }
  return InternetAddress.fromRawAddress(address.rawAddress).address
      .toLowerCase();
}

String? normalizeMacAddress(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final mac = value.trim().toUpperCase();
  if (!RegExp(
    r'^(?:[0-9A-F]{12}|(?:[0-9A-F]{2}:){5}[0-9A-F]{2}|(?:[0-9A-F]{2}-){5}[0-9A-F]{2})$',
  ).hasMatch(mac)) {
    throw ArgumentError('La dirección MAC no es válida.');
  }
  final compact = mac.replaceAll(RegExp('[:-]'), '');
  return List.generate(
    6,
    (index) => compact.substring(index * 2, index * 2 + 2),
  ).join(':');
}

class DeviceWriteResult {
  const DeviceWriteResult(this.device, {required this.hasDuplicateMac});

  final DeviceRecord device;
  final bool hasDuplicateMac;
}

class DeviceService {
  DeviceService(this.db);

  final AppDatabase db;

  Stream<List<DeviceRecord>> watchForClient(String clientId) =>
      (db.select(db.devices)
            ..where((row) => row.clientId.equals(clientId))
            ..orderBy([(row) => OrderingTerm.asc(row.id)]))
          .watch();

  Future<bool> hasDuplicateMac(String? value, {String? excludingId}) async {
    final mac = normalizeMacAddress(value);
    if (mac == null) return false;
    final query = db.select(db.devices)
      ..where((row) => row.macAddress.equals(mac));
    if (excludingId != null) {
      query.where((row) => row.id.equals(excludingId).not());
    }
    return (await (query..limit(1)).get()).isNotEmpty;
  }

  Future<void> _checkEditable(String clientId) async {
    final client = await (db.select(
      db.clients,
    )..where((row) => row.id.equals(clientId))).getSingleOrNull();
    if (client == null || client.status == 'archived') {
      throw StateError('El cliente no existe o está archivado.');
    }
  }

  Future<List<DeviceRecord>> forClient(String clientId) =>
      (db.select(db.devices)
            ..where((row) => row.clientId.equals(clientId))
            ..orderBy([(row) => OrderingTerm.asc(row.id)]))
          .get();

  Future<DeviceWriteResult> save({
    String? id,
    required String clientId,
    required DeviceType type,
    String? macAddress,
    Value<String?> ipAddress = const Value.absent(),
    String? notes,
    bool allowArchived = true,
  }) => db.transaction(() async {
    if (!allowArchived) await _checkEditable(clientId);
    final deviceId = id ?? newRecordId();
    final mac = normalizeMacAddress(macAddress);
    final ip = ipAddress.present
        ? Value(normalizeIpAddress(ipAddress.value))
        : const Value<String?>.absent();
    final duplicates = mac == null
        ? <DeviceRecord>[]
        : await (db.select(db.devices)..where(
                (row) =>
                    row.macAddress.equals(mac) & row.id.equals(deviceId).not(),
              ))
              .get();
    final existing = await (db.select(
      db.devices,
    )..where((row) => row.id.equals(deviceId))).getSingleOrNull();
    if (existing != null && existing.clientId != clientId) {
      throw StateError('El dispositivo pertenece a otro cliente.');
    }
    final data = DevicesCompanion.insert(
      id: deviceId,
      clientId: clientId,
      type: type.name,
      macAddress: Value(mac),
      ipAddress: ip,
      notes: Value(notes),
    );
    if (existing == null) {
      await db.into(db.devices).insert(data);
    } else {
      await (db.update(
        db.devices,
      )..where((row) => row.id.equals(deviceId))).write(data);
    }
    final device = await (db.select(
      db.devices,
    )..where((row) => row.id.equals(deviceId))).getSingle();
    return DeviceWriteResult(device, hasDuplicateMac: duplicates.isNotEmpty);
  });

  Future<void> remove(String id, {bool allowArchived = true}) =>
      db.transaction(() async {
        if (!allowArchived) {
          final device = await (db.select(
            db.devices,
          )..where((row) => row.id.equals(id))).getSingleOrNull();
          if (device == null) throw StateError('El dispositivo no existe.');
          await _checkEditable(device.clientId);
        }
        final deleted = await (db.delete(
          db.devices,
        )..where((row) => row.id.equals(id))).go();
        if (deleted == 0) throw StateError('El dispositivo no existe.');
      });
}
