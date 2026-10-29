import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class SettingsService {
  SettingsService(this.db);

  final AppDatabase db;

  Stream<SettingsRecord> watch() => db.select(db.appSettings).watchSingle();

  Future<SettingsRecord> read() => db.select(db.appSettings).getSingle();

  Future<void> update({
    required String businessName,
    required String currencyLabel,
    String? defaultCallingCode,
    required bool notificationsEnabled,
  }) => db.transaction(() async {
    if (businessName.trim().isEmpty) {
      throw ArgumentError('El nombre del negocio es obligatorio.');
    }
    await (db.update(db.appSettings)..where((row) => row.id.equals(1))).write(
      AppSettingsCompanion(
        businessName: Value(businessName.trim()),
        currencyLabel: Value(currencyLabel.trim()),
        defaultCallingCode: Value(defaultCallingCode),
        notificationsEnabled: Value(notificationsEnabled),
      ),
    );
  });
}
