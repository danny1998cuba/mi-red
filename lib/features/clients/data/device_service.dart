import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/record_id.dart';

enum DeviceType { antenna, ont, router, other }

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
    String? notes,
  }) => db.transaction(() async {
    final deviceId = id ?? newRecordId();
    final mac = normalizeMacAddress(macAddress);
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
    final data = DevicesCompanion.insert(
      id: deviceId,
      clientId: clientId,
      type: type.name,
      macAddress: Value(mac),
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

  Future<void> remove(String id) async {
    final deleted = await (db.delete(
      db.devices,
    )..where((row) => row.id.equals(id))).go();
    if (deleted == 0) throw StateError('El dispositivo no existe.');
  }
}
