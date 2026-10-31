import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  Future<void>? _closing;

  @override
  Future<void> close() => _closing ??= super.close();

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await into(appSettings).insert(const AppSettingsCompanion(id: Value(1)));
    }),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from > 2 || to != 3) {
        throw StateError('Falta una migración de la versión $from a $to.');
      }
      await customStatement('PRAGMA foreign_keys = OFF');
      try {
        await transaction(() async {
          if (from == 1) {
            await migrator.addColumn(devices, devices.ipAddress);
          }
          // No inbound foreign keys reference devices. Preserve all rows and
          // indices while removing the closed type allowlist.
          await migrator.alterTable(TableMigration(devices));
          if ((await customSelect(
            'PRAGMA foreign_key_check',
          ).get()).isNotEmpty) {
            throw StateError('La base de datos tiene relaciones inválidas.');
          }
        });
      } finally {
        await customStatement('PRAGMA foreign_keys = ON');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
