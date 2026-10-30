import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A modal backup workflow pauses lifecycle writes, including returns from SAF.
/// SQL transactions remain the serialization boundary for database operations.
class DatabaseMaintenance {
  bool _active = false;
  bool get active => _active;
  void begin() {
    if (_active) throw StateError('Ya hay una operación de datos en curso.');
    _active = true;
  }

  void end() => _active = false;
}

final databaseMaintenanceProvider = Provider((ref) => DatabaseMaintenance());
