import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  Future<void>? _closing;

  @override
  Future<void> close() => _closing ??= super.close();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await into(appSettings).insert(const AppSettingsCompanion(id: Value(1)));
    }),
    // Fail closed until a reviewed incremental migration exists. Never reset data.
    onUpgrade: (migrator, from, to) async {
      throw StateError('Falta una migración de la versión $from a $to.');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
