import 'package:flutter/material.dart';
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
import 'package:mi_red/main.dart' as app;

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
    app.main();
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Mi Red'), findsOneWidget);
    expect(find.text('Pantalla provisional'), findsOneWidget);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(4));
    expect(navigation.selectedIndex, 0);
    expect(
      Localizations.localeOf(tester.element(find.byType(DashboardScreen))),
      const Locale('es'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Navigates to every placeholder and returns to Inicio', (
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
          of: find.byType(NavigationBar),
          matching: find.text(destination.label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(destination.type), findsOneWidget);
      expect(
        find.text('Pantalla provisional'),
        destination.type == ClientsScreen ? findsNothing : findsOneWidget,
      );
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
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        destination.index,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Direct navigation updates the selected destination', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appRouterProvider).go('/billing');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BillingScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unknown route shows a Spanish error and recovers', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
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
      await tester.pumpWidget(const ProviderScope(child: MiRedApp()));
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

    for (final label in ['Clientes', 'Cobros', 'Ajustes', 'Inicio']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
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
  });
}
