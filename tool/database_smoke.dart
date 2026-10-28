import 'package:flutter/widgets.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_connection.dart';
import 'package:mi_red/features/settings/data/settings_service.dart';
import 'package:mi_red/main.dart' as app;

/// Android diagnostic entry point. Never inserts or logs customer data.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  for (var attempt = 0; attempt < 2; attempt++) {
    final db = AppDatabase(openAppDatabase());
    try {
      final settings = await SettingsService(db).read();
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      final foreignKeys = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      final violations = await db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      final integrity = await db
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      if (settings.id != 1 ||
          version.read<int>('user_version') != 1 ||
          foreignKeys.read<int>('foreign_keys') != 1 ||
          violations.isNotEmpty ||
          integrity.read<String>('integrity_check') != 'ok') {
        throw StateError('Falló la verificación local de SQLite.');
      }
    } finally {
      await db.close();
    }
  }
  debugPrint('MI_RED_SQLITE_SMOKE_OK');
  app.main();
}
