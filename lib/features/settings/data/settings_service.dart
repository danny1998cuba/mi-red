import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../business_values.dart';

class SettingsService {
  SettingsService(this.db);

  final AppDatabase db;

  Stream<SettingsRecord> watch() => db.select(db.appSettings).watchSingle();

  Future<SettingsRecord> read() => db.select(db.appSettings).getSingle();

  Future<void> setNotificationsEnabled(bool enabled) =>
      db.transaction(() async {
        await (db.update(db.appSettings)..where((row) => row.id.equals(1)))
            .write(AppSettingsCompanion(notificationsEnabled: Value(enabled)));
      });

  Future<void> update({
    required String businessName,
    required String currencyLabel,
    String? defaultCallingCode,
    bool? notificationsEnabled,
  }) => db.transaction(() async {
    for (final error in [
      validateBusinessName(businessName),
      validateCurrencyLabel(currencyLabel),
      validateCallingCode(defaultCallingCode),
    ]) {
      if (error != null) throw ArgumentError(error);
    }
    await (db.update(db.appSettings)..where((row) => row.id.equals(1))).write(
      AppSettingsCompanion(
        businessName: Value(businessName.trim()),
        currencyLabel: Value(currencyLabel.trim()),
        defaultCallingCode: Value(
          defaultCallingCode == null || defaultCallingCode.trim().isEmpty
              ? null
              : defaultCallingCode.trim(),
        ),
        // Business edits omit this column, avoiding stale read/modify/write of opt-in.
        notificationsEnabled: notificationsEnabled == null
            ? const Value.absent()
            : Value(notificationsEnabled),
      ),
    );
  });
}
