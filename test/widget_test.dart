import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';
import 'package:mi_red/features/billing/billing_screen.dart';
import 'package:mi_red/features/clients/clients_screen.dart';
import 'package:mi_red/features/dashboard/dashboard_screen.dart';
import 'package:mi_red/features/settings/settings_screen.dart';

void main() {
  ProviderContainer testContainer() {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    return container;
  }

  testWidgets('Starts on the Spanish dashboard with four destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: testContainer(),
        child: const MiRedApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Inicio')),
      findsOneWidget,
    );
    expect(find.text('Pantalla provisional'), findsNothing);
    expect(find.byKey(const Key('dashboard-active')), findsOneWidget);
    expect(find.text('Añade tu primer cliente'), findsOneWidget);
    final navigation = tester.widget<FBottomNavigationBar>(
      find.byType(FBottomNavigationBar),
    );
    expect(navigation.children, hasLength(4));
    expect(navigation.index, 0);
    expect(
      Localizations.localeOf(tester.element(find.byType(DashboardScreen))),
      const Locale('es'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Navigates to every destination and returns to Inicio', (
    tester,
  ) async {
    final container = testContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await tester.pumpAndSettle();

    final destinations = [
      (label: 'Clientes', type: ClientsScreen, path: '/clients', index: 1),
      (label: 'Cobros', type: BillingScreen, path: '/billing', index: 2),
      (label: 'Ajustes', type: SettingsScreen, path: '/settings', index: 3),
      (label: 'Inicio', type: DashboardScreen, path: '/', index: 0),
    ];
    for (final destination in destinations) {
      await tester.tap(
        find.descendant(
          of: find.byType(FBottomNavigationBar),
          matching: find.text(destination.label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(destination.type), findsOneWidget);
      expect(find.text('Pantalla provisional'), findsNothing);
      if (destination.type == SettingsScreen) {
        expect(find.text('Recordatorios'), findsOneWidget);
      }
      if (destination.type == DashboardScreen) {
        expect(find.byKey(const Key('dashboard-active')), findsOneWidget);
      }
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        destination.path,
      );
      expect(
        tester
            .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
            .index,
        destination.index,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Direct navigation updates the selected destination', (
    tester,
  ) async {
    final container = testContainer();

    container.read(appRouterProvider).go('/billing');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BillingScreen), findsOneWidget);
    expect(
      tester
          .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
          .index,
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unknown route shows a Spanish error and recovers', (
    tester,
  ) async {
    final container = testContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/missing');
    await tester.pumpAndSettle();

    expect(find.text('No se pudo abrir esta pantalla'), findsOneWidget);
    await tester.tap(find.text('Volver a Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Uses Material 3 with the system $brightness theme', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer(),
          child: const MiRedApp(),
        ),
      );
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.byType(DashboardScreen)));
      expect(theme.brightness, brightness);
      expect(theme.useMaterial3, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Small screen and large text keep every destination usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = testContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await tester.pumpAndSettle();

    for (final entry in const {
      'clients': 'Clientes',
      'billing': 'Cobros',
      'settings': 'Ajustes',
      'home': 'Inicio',
    }.entries) {
      final label = entry.value;
      await tester.tap(find.byKey(ValueKey('navigation-${entry.key}')));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla provisional'), findsNothing);
      if (label == 'Ajustes') {
        expect(find.text('Recordatorios'), findsOneWidget);
      }
      if (label == 'Inicio') {
        expect(find.byKey(const Key('dashboard-active')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
