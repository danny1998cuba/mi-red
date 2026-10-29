import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android starts all placeholders and opens the private native database',
    (tester) async {
      app.main();
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiRedApp)),
      );
      final db = container.read(databaseProvider);
      final settings = await container.read(settingsServiceProvider).read();
      expect(settings.id, 1);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
      for (final label in ['Clientes', 'Cobros', 'Ajustes', 'Inicio']) {
        await tester.tap(
          find.descendant(
            of: find.byType(FBottomNavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Pantalla provisional'),
          label == 'Clientes' ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
    },
  );
}
