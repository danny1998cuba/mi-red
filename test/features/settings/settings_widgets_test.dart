import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';
import 'package:mi_red/features/backups/backup_service.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/communications/communication_actions.dart';
import 'package:mi_red/features/reminders/reminder_scheduler.dart';
import 'package:mi_red/features/settings/about_screen.dart';
import 'package:mi_red/features/settings/appearance.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../billing/billing_widgets_test.dart' show pumpBilling;
import '../communications/communication_widgets_test.dart'
    show pressCommunication, reachCommunication;
import '../communications/fake_communication_actions.dart';
import '../reminders/fake_reminder_scheduler.dart';
import 'fake_appearance.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  late AppDatabase db;
  late ProviderContainer container;
  late FakeAppearanceRepository preferences;
  late FakeReminderScheduler scheduler;
  late FakeCommunicationActions actions;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    preferences = FakeAppearanceRepository();
    scheduler = FakeReminderScheduler();
    actions = FakeCommunicationActions();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clientClockProvider.overrideWithValue(() => DateTime(2026, 12, 3, 12)),
        appearanceRepositoryProvider.overrideWithValue(preferences),
        nativeAppearanceProvider.overrideWithValue(FakeNativeAppearance()),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        communicationActionsProvider.overrideWithValue(actions),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'Mi Red',
            packageName: 'com.mired.offline',
            version: '9.8.7',
            buildNumber: '654',
          ),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester tester, String route) async {
    container.read(appRouterProvider).go(route);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await pumpBilling(tester);
  }

  Future<void> go(WidgetTester tester, String route) async {
    container.read(appRouterProvider).go(route);
    await pumpBilling(tester);
  }

  final pages = {
    'business': 'Mi negocio',
    'appearance': 'Apariencia',
    'reminders': 'Recordatorios',
    'backups': 'Copias de seguridad',
    'about': 'Acerca de Mi Red',
  };

  testWidgets(
    'all five categories push one header and no tabs, back selects Settings; tabs remain usable',
    (tester) async {
      await open(tester, '/settings');
      for (final entry in pages.entries) {
        expect(find.byType(AppBar), findsOneWidget);
        expect(
          tester
              .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
              .index,
          3,
        );
        await reachCommunication(tester, 'settings-${entry.key}');
        expect(
          tester.getSize(find.byKey(Key('settings-${entry.key}'))).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byKey(Key('settings-${entry.key}')));
        await pumpBilling(tester);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(FBottomNavigationBar), findsNothing);
        expect(find.text(entry.value), findsOneWidget);
        await tester.tap(find.byTooltip('Atrás'));
        await pumpBilling(tester);
        expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/settings',
        );
      }
      for (final title in ['Inicio', 'Clientes', 'Cobros', 'Ajustes']) {
        final bar = find.byType(FBottomNavigationBar);
        await tester.tap(find.descendant(of: bar, matching: find.text(title)));
        await pumpBilling(tester);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(FBottomNavigationBar), findsOneWidget);
      }
      expect(scheduler.requests, 0);
      expect(actions.opened, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'each secondary deep link has a working fallback back without duplicate headers',
    (tester) async {
      for (final name in pages.keys) {
        await open(tester, '/settings/$name');
        expect(find.byType(FBottomNavigationBar), findsNothing);
        await tester.tap(find.byTooltip('Atrás'));
        await pumpBilling(tester);
        expect(find.byType(AppBar), findsOneWidget);
        expect(
          tester
              .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
              .index,
          3,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all appearance modes update Material, Forui and system bars; automatic follows live OS and resume',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await open(tester, '/settings/appearance');
      void verify(Brightness expected) {
        final context = tester.element(
          find.byKey(const Key('appearance-system')),
        );
        expect(Theme.brightnessOf(context), expected);
        expect(FTheme.of(context).colors.brightness, expected);
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(
          region.value.systemNavigationBarIconBrightness,
          expected == Brightness.dark ? Brightness.light : Brightness.dark,
        );
      }

      verify(Brightness.light);
      await pressCommunication(tester, 'appearance-dark');
      verify(Brightness.dark);
      await go(tester, '/settings');
      expect(
        FTheme.of(tester.element(find.byType(FBottomNavigationBar)))
            .colors
            .brightness,
        Brightness.dark,
      );
      await go(tester, '/settings/appearance');
      await pressCommunication(tester, 'appearance-light');
      verify(Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await pumpBilling(tester);
      verify(Brightness.light);
      await pressCommunication(tester, 'appearance-system');
      verify(Brightness.dark);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpBilling(tester);
      verify(Brightness.light);
      expect(preferences.mode, ThemeMode.system);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'routing and appearance never mutate financial tables or opt-in and do not duplicate reminders',
    (tester) async {
      await open(tester, '/settings/reminders');
      await pressCommunication(tester, 'reminders-switch');
      expect(scheduler.pending, hasLength(10));
      final before = (await BackupService(
        db,
      ).capture(DateTime.utc(2026, 12, 3))).records;
      final calls = scheduler.scheduledCalls;
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        await go(tester, '/settings/appearance');
        await pressCommunication(tester, 'appearance-${mode.name}');
        for (final route in [
          '/settings/backups',
          '/settings/reminders',
          '/settings',
        ]) {
          await go(tester, route);
        }
      }
      expect(
        (await BackupService(db).capture(DateTime.utc(2026, 12, 3))).records,
        before,
      );
      expect(scheduler.scheduledCalls, calls);
      expect(scheduler.pending, hasLength(10));
      expect(scheduler.requests, 1);
      expect(scheduler.initializations, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'About uses installed package metadata, accessible explicit link and retry on launcher failure',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await open(tester, '/settings/about');
        expect(find.text('Versión 9.8.7 (654)'), findsOneWidget);
        expect(find.text('Desarrollado por CoreX4Dev'), findsOneWidget);
        expect(actions.opened, isEmpty);
        await pressCommunication(tester, 'about-website');
        expect(actions.opened.single, Uri.https('corex4dev.com'));
        expect(
          find.textContaining('No se pudo abrir el sitio'),
          findsOneWidget,
        );
        final link = tester.getSemantics(
          find.byKey(const Key('about-website-link')),
        );
        expect(link.getSemanticsData().flagsCollection.isLink, isTrue);
        actions.openResult = true;
        actions.gate = Completer<void>();
        await reachCommunication(tester, 'about-website');
        await tester.tap(find.byKey(const Key('about-website')));
        await tester.pump();
        expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('about-website')))
              .onPressed,
          isNull,
        );
        actions.gate!.complete();
        await pumpBilling(tester);
        expect(find.textContaining('No se pudo abrir el sitio'), findsNothing);
        expect(actions.opened, hasLength(2));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'Settings pages at $width/$scale/$brightness retain targets, full labels and keyboard scrolling',
          (tester) async {
            tester.view.physicalSize = Size(width, 640);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetViewInsets);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(
              tester.platformDispatcher.clearPlatformBrightnessTestValue,
            );
            await open(tester, '/settings');
            for (final entry in pages.entries) {
              await reachCommunication(tester, 'settings-${entry.key}');
              expect(
                tester.getSize(find.byKey(Key('settings-${entry.key}'))).height,
                greaterThanOrEqualTo(48),
              );
              expect(find.text(entry.value), findsOneWidget);
              final title = tester.renderObject<RenderParagraph>(
                find.text(entry.value),
              );
              expect(title.maxLines, isNull);
              expect(title.overflow, TextOverflow.visible);
              final descriptions = find.descendant(
                of: find.byKey(Key('settings-${entry.key}')),
                matching: find.byType(Text),
              );
              final subtitle = tester.renderObject<RenderParagraph>(
                descriptions.last,
              );
              expect(subtitle.maxLines, isNull);
              expect(subtitle.overflow, TextOverflow.visible);
              await tester.tap(find.byKey(Key('settings-${entry.key}')));
              await pumpBilling(tester);
              expect(tester.takeException(), isNull);
              tester.view.viewInsets = const FakeViewPadding(bottom: 240);
              await pumpBilling(tester);
              if (entry.key == 'appearance') {
                preferences.failWrite = true;
                await pressCommunication(tester, 'appearance-dark');
                expect(
                  find.textContaining('No se pudo guardar la apariencia'),
                  findsOneWidget,
                );
                preferences.failWrite = false;
                await pressCommunication(tester, 'appearance-light');
              } else if (entry.key == 'about') {
                await reachCommunication(tester, 'about-website');
                expect(
                  tester.getSize(find.byKey(const Key('about-website'))).height,
                  greaterThanOrEqualTo(48),
                );
                await tester.tap(find.byKey(const Key('about-website')));
                await pumpBilling(tester);
                expect(
                  find.textContaining('No se pudo abrir el sitio'),
                  findsOneWidget,
                );
              }
              expect(tester.takeException(), isNull);
              await tester.tap(find.byTooltip('Atrás'));
              tester.view.resetViewInsets();
              await pumpBilling(tester);
              expect(
                tester
                    .widget<FBottomNavigationBar>(
                      find.byType(FBottomNavigationBar),
                    )
                    .index,
                3,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
