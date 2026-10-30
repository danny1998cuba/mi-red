import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';

import '../features/billing/billing_widgets_test.dart' show pumpBilling;

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final width in [320.0, 400.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'navigation at $width dp/200%/$brightness never splits words and retains names, targets and routes',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final db = AppDatabase(NativeDatabase.memory());
          final container = ProviderContainer(
            overrides: [databaseProvider.overrideWithValue(db)],
          );
          addTearDown(() async {
            container.dispose();
            await db.close();
          });
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: const MiRedApp(),
              ),
            );
            await pumpBilling(tester);
            final bar = find.byType(FBottomNavigationBar);
            for (final entry in const {
              'clients': ('Clientes', '/clients', 1),
              'billing': ('Cobros', '/billing', 2),
              'settings': ('Ajustes', '/settings', 3),
              'home': ('Inicio', '/', 0),
            }.entries) {
              final (label, path, index) = entry.value;
              final visibleLabel = find.descendant(
                of: bar,
                matching: find.text(label),
              );
              if (visibleLabel.evaluate().isNotEmpty) {
                final paragraph = tester.renderObject<RenderParagraph>(
                  visibleLabel,
                );
                expect(
                  paragraph.getBoxesForSelection(
                    TextSelection(baseOffset: 0, extentOffset: label.length),
                  ),
                  hasLength(1),
                  reason: 'A destination name must stay whole.',
                );
              }
              final target = find.byKey(ValueKey('navigation-${entry.key}'));
              expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
              expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
              expect(
                find.descendant(
                  of: bar,
                  matching: find.bySemanticsLabel(RegExp('^$label\\nPestaña')),
                ),
                findsOneWidget,
              );
              await tester.tap(target);
              await pumpBilling(tester);
              expect(
                container
                    .read(appRouterProvider)
                    .routeInformationProvider
                    .value
                    .uri
                    .path,
                path,
              );
              expect(tester.widget<FBottomNavigationBar>(bar).index, index);
              expect(
                MediaQuery.textScalerOf(tester.element(bar)).scale(12),
                24,
              );
            }
            await tester.longPress(find.byKey(const Key('navigation-clients')));
            await tester.pump(const Duration(milliseconds: 800));
            final tooltip = find.text('Clientes');
            expect(tooltip, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(tooltip);
            expect(
              paragraph.getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 8),
              ),
              hasLength(1),
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
