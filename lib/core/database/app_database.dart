import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  Future<void>? _closing;

  @override
  Future<void> close() => _closing ??= super.close();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await into(appSettings).insert(const AppSettingsCompanion(id: Value(1)));
    }),
    onUpgrade: (migrator, from, to) async {
      if (from != 1 || to != 2) {
        throw StateError('Falta una migración de la versión $from a $to.');
      }
      await transaction(() async {
        await migrator.addColumn(devices, devices.ipAddress);
        if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
          throw StateError('La base de datos tiene relaciones inválidas.');
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
