import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/design_system/app_design.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + 0.05) / (second + 0.05)
      : (second + 0.05) / (first + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Forui and Material share accessible $brightness tokens and local font',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final db = AppDatabase(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MiRedApp(),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(FBottomNavigationBar));
        final p = AppPalette.of(context);
        final material = Theme.of(context);
        final forui = FTheme.of(context);
        expect(forui.colors.brightness, brightness);
        expect(forui.colors.background, p.canvas);
        expect(material.scaffoldBackgroundColor, p.canvas);
        expect(forui.colors.card, material.colorScheme.surface);
        expect(forui.colors.primary, material.colorScheme.primary);
        expect(material.textTheme.bodyMedium!.fontFamily, contains('Inter'));
        expect(contrast(p.text, p.canvas), greaterThanOrEqualTo(4.5));
        expect(contrast(p.secondary, p.canvas), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
        for (final color in [p.success, p.warning, p.danger]) {
          expect(contrast(color, p.surface), greaterThanOrEqualTo(4.5));
        }
        final navigation = tester.widget<FBottomNavigationBar>(
          find.byType(FBottomNavigationBar),
        );
        expect(navigation.children, hasLength(4));
        expect(navigation.index, 0);
        expect(find.text('Pantalla provisional'), findsNothing);
        expect(find.byKey(const Key('dashboard-active')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
