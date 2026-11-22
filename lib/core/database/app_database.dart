import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  Future<void>? _closing;

  @override
  Future<void> close() => _closing ??= super.close();

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await into(appSettings).insert(const AppSettingsCompanion(id: Value(1)));
    }),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from > 4 || to != 5) {
        throw StateError('Falta una migración de la versión $from a $to.');
      }
      await customStatement('PRAGMA foreign_keys = OFF');
      try {
        await transaction(() async {
          if (from == 1) {
            await migrator.addColumn(devices, devices.ipAddress);
          }
          if (from < 3) {
            await migrator.alterTable(TableMigration(devices));
          }
          if (from < 4) {
            await migrator.createTable(paymentBatches);
            await migrator.addColumn(payments, payments.batchId);
          }
          const triggers = {
            'payments_match_batch',
            'payments_immutable',
            'payment_batches_immutable',
            'payment_batches_void_children',
          };
          for (final name in triggers) {
            await customStatement('DROP TRIGGER IF EXISTS $name');
          }
          for (final entity in allSchemaEntities) {
            if (triggers.contains(entity.entityName) ||
                (from < 4 &&
                    const {
                      'payment_batches_client',
                      'payments_batch_charge',
                    }.contains(entity.entityName))) {
              await migrator.create(entity);
            }
          }
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
