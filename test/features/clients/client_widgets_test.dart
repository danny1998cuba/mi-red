import 'dart:async' show StreamController;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/app.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/core/navigation/app_router.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/clients/client_providers.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/clients/data/device_service.dart';

Future<void> settleClientData(WidgetTester tester) async {
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}

Future<void> showControl(WidgetTester tester, Key key) async {
  await settleClientData(tester);
  final finder = find.byKey(key);
  final lists = find.byType(ListView);
  final scrollable = lists.evaluate().isNotEmpty
      ? find.descendant(of: lists.last, matching: find.byType(Scrollable)).first
      : find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  for (var attempt = 0; finder.evaluate().isEmpty && attempt < 50; attempt++) {
    final rect = tester.getRect(scrollable);
    // Drag the form margin; dragging a multiline field scrolls its own text.
    await tester.dragFrom(
      Offset(rect.left + 8, rect.center.dy),
      const Offset(0, -180),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
}

Future<void> fillClientField(
  WidgetTester tester,
  String key,
  String value,
) async {
  await showControl(tester, Key(key));
  await tester.enterText(find.byKey(Key(key)), value);
  await tester.pump();
}

Future<void> pressClientControl(WidgetTester tester, String key) async {
  await showControl(tester, Key(key));
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.tap(find.byKey(Key(key)));
  await settleClientData(tester);
}

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime(2026, 12, 2, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clientClockProvider.overrideWithValue(() => now),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<ClientRecord> seed(
    String id, {
    String? name,
    String? address,
    String? phone,
    String? notes,
    ServiceStatus status = ServiceStatus.active,
  }) => container
      .read(clientServiceProvider)
      .create(
        id: id,
        fullName: name ?? 'Cliente de prueba $id',
        address: address,
        phone: phone,
        notes: notes,
        monthlyFeeMinor: 125050,
        status: status,
        today: LocalDate.fromDateTime(now),
        recordedAt: now,
      );

  Future<void> open(WidgetTester tester, [String location = '/clients']) async {
    container.read(appRouterProvider).go(location);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiRedApp()),
    );
    await settleClientData(tester);
  }

  testWidgets(
    'Empty list validates and creates one client even with a repeated save tap',
    (tester) async {
      await open(tester);
      expect(find.text('No hay clientes en este filtro'), findsOneWidget);
      await pressClientControl(tester, 'add-client');
      await pressClientControl(tester, 'client-save');
      expect(await container.read(clientServiceProvider).list(), isEmpty);
      await fillClientField(
        tester,
        'client-name',
        '  Cliente de prueba nuevo  ',
      );
      await fillClientField(tester, 'client-phone', '+000 (000) 000-000');
      await fillClientField(tester, 'client-fee', '1250,50');
      await showControl(tester, const Key('client-save'));
      await tester.tap(find.byKey(const Key('client-save')));
      await tester.tap(find.byKey(const Key('client-save')));
      await settleClientData(tester);
      final clients = await container.read(clientServiceProvider).list();
      expect(clients.length, 1);
      expect(clients.single.fullName, 'Cliente de prueba nuevo');
      expect(clients.single.monthlyFeeMinor, 125050);
      expect(clients.single.phone, '+000 (000) 000-000');
      expect(find.text('Ficha de cliente'), findsOneWidget);
      expect(find.text('1250,50 al mes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Search, state filters and external edits refresh the list without relaunch',
    (tester) async {
      final first = await seed(
        'a',
        name: 'Alfa de prueba',
        phone: '+000 123456',
        address: 'Calle Ejemplo',
      );
      await seed('b', name: 'Beta de prueba');
      await seed(
        'c',
        name: 'Archivado de prueba',
        status: ServiceStatus.archived,
      );
      await open(tester);
      expect(find.text('Alfa de prueba'), findsOneWidget);
      expect(find.text('Archivado de prueba'), findsNothing);
      for (final query in [' alfa ', '123456', 'calle']) {
        await fillClientField(tester, 'client-search', query);
        expect(find.text('Alfa de prueba'), findsOneWidget);
        expect(find.text('Beta de prueba'), findsNothing);
      }
      await fillClientField(tester, 'client-search', 'sin coincidencias');
      expect(find.text('No hay resultados'), findsOneWidget);
      await fillClientField(tester, 'client-search', '');
      await container
          .read(clientServiceProvider)
          .updateProfile(
            first.id,
            fullName: 'Nombre actualizado',
            monthlyFeeMinor: 100,
            status: ServiceStatus.active,
            today: LocalDate.fromDateTime(now),
          );
      await settleClientData(tester);
      expect(find.text('Nombre actualizado'), findsOneWidget);
      await pressClientControl(tester, 'client-filters');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Archivados'));
      await settleClientData(tester);
      expect(find.text('Archivado de prueba'), findsOneWidget);
      expect(find.text('Nombre actualizado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Back asks to discard and continuing editing retains the draft', (
    tester,
  ) async {
    final client = await seed('draft');
    await open(tester, '/clients/${client.id}');
    await pressClientControl(tester, 'edit-client');
    await fillClientField(tester, 'client-name', 'Borrador sin guardar');
    await tester.tap(find.byTooltip('Volver'));
    await settleClientData(tester);
    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await settleClientData(tester);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('client-name')))
          .controller!
          .text,
      'Borrador sin guardar',
    );
    await tester.tap(find.byTooltip('Volver'));
    await settleClientData(tester);
    await tester.tap(find.text('Descartar cambios'));
    await settleClientData(tester);
    expect(
      (await container.read(clientServiceProvider).get(client.id)).fullName,
      client.fullName,
    );
    expect(find.text('Ficha de cliente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Editing a fee updates detail reactively and keeps the original charge',
    (tester) async {
      final client = await seed('fee');
      final original = await db.select(db.charges).get();
      await container
          .read(settingsServiceProvider)
          .update(
            businessName: 'Prueba',
            currencyLabel: 'unidad',
            notificationsEnabled: false,
          );
      await open(tester, '/clients/${client.id}/edit');
      await fillClientField(tester, 'client-fee', '999.01');
      await pressClientControl(tester, 'client-save');
      expect(find.text('999,01 unidad al mes'), findsOneWidget);
      expect(await db.select(db.charges).get(), original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Archive and reactivate require confirmation and update filters',
    (tester) async {
      final client = await seed('archive');
      await open(tester);
      await pressClientControl(tester, 'client-${client.id}');
      await pressClientControl(tester, 'archive-client');
      await tester.tap(find.text('Cancelar'));
      await settleClientData(tester);
      expect(
        (await container.read(clientServiceProvider).get(client.id)).status,
        'active',
      );
      await pressClientControl(tester, 'archive-client');
      await tester.tap(find.text('Archivar'));
      await settleClientData(tester);
      expect(find.byKey(const Key('edit-client')), findsNothing);
      expect(find.byKey(const Key('add-device')), findsNothing);
      await tester.tap(find.byTooltip('Atrás'));
      await settleClientData(tester);
      expect(find.text(client.fullName), findsNothing);
      await pressClientControl(tester, 'client-filters');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Archivados'));
      await settleClientData(tester);
      await pressClientControl(tester, 'client-${client.id}');
      await pressClientControl(tester, 'archive-client');
      await tester.tap(find.text('Reactivar'));
      await settleClientData(tester);
      expect(
        (await container.read(clientServiceProvider).get(client.id)).status,
        'active',
      );
      expect(find.byKey(const Key('edit-client')), findsOneWidget);
      expect((await db.select(db.charges).get()).length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Device duplicate warning permits review or explicit continued saving without duplicates',
    (tester) async {
      final client = await seed('duplicate');
      await open(tester, '/clients/${client.id}');
      await pressClientControl(tester, 'add-device');
      await fillClientField(tester, 'device-mac', '02-aa-bb-cc-dd-01');
      await pressClientControl(tester, 'device-save');
      expect(find.text('02:AA:BB:CC:DD:01'), findsOneWidget);
      await pressClientControl(tester, 'add-device');
      await fillClientField(tester, 'device-mac', '02aabbccdd01');
      await pressClientControl(tester, 'device-save');
      expect(find.text('MAC ya registrada'), findsOneWidget);
      await tester.tap(find.text('Revisar'));
      await settleClientData(tester);
      expect(
        (await container.read(deviceServiceProvider).forClient(client.id))
            .length,
        1,
      );
      await pressClientControl(tester, 'device-save');
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar de todos modos'),
      );
      confirm.onPressed!();
      confirm.onPressed!();
      await settleClientData(tester);
      expect(
        (await container.read(deviceServiceProvider).forClient(client.id))
            .length,
        2,
      );
      expect(find.text('Ficha de cliente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Device editing and deletion confirm and preserve the client and charges',
    (tester) async {
      final client = await seed('devices');
      final device =
          (await container
                  .read(deviceServiceProvider)
                  .save(
                    clientId: client.id,
                    type: DeviceType.antenna,
                    macAddress: '02aabbccdd01',
                  ))
              .device;
      final original = await db.select(db.charges).get();
      await open(tester, '/clients/${client.id}/devices/${device.id}/edit');
      await fillClientField(tester, 'device-notes', 'Nota de prueba editada');
      await fillClientField(tester, 'device-mac', '02aabbccdd02');
      await tester.tap(find.byKey(const Key('device-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Router').last);
      await tester.pumpAndSettle();
      await pressClientControl(tester, 'device-save');
      await tester.tap(find.text('Guardar cambios'));
      await settleClientData(tester);
      final edited =
          (await container.read(deviceServiceProvider).forClient(client.id))
              .single;
      expect(edited.type, 'router');
      expect(edited.macAddress, '02:AA:BB:CC:DD:02');
      expect(edited.notes, 'Nota de prueba editada');
      await pressClientControl(tester, 'delete-device-${device.id}');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await settleClientData(tester);
      expect(
        await container.read(deviceServiceProvider).forClient(client.id),
        isEmpty,
      );
      expect(
        await container.read(clientServiceProvider).get(client.id),
        client,
      );
      expect(await db.select(db.charges).get(), original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Missing or archived direct routes are safe and read only', (
    tester,
  ) async {
    await open(tester, '/clients/missing/edit');
    expect(find.text('Cliente no encontrado'), findsOneWidget);
    final client = await seed('readonly', status: ServiceStatus.archived);
    container.read(appRouterProvider).go('/clients/${client.id}/devices/new');
    await settleClientData(tester);
    expect(find.byKey(const Key('device-save')), findsNothing);
    expect(
      find.text('Reactiva el cliente antes de editar sus dispositivos.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Small dark screen and text 200 percent keep detail and forms scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final client = await seed(
        'layout',
        name: 'Cliente de prueba con nombre considerablemente largo para comprobar la lectura',
        address: 'Dirección de prueba extensa para pantalla pequeña',
        notes: 'Notas de prueba ' * 20,
      );
      await open(tester, '/clients/${client.id}');
      await pressClientControl(tester, 'edit-client');
      expect(find.byKey(const Key('client-name')), findsOneWidget);
      await fillClientField(
        tester,
        'client-notes',
        'Texto de prueba accesible',
      );
      await pressClientControl(tester, 'client-save');
      await pressClientControl(tester, 'add-device');
      await fillClientField(tester, 'device-mac', 'invalid');
      await pressClientControl(tester, 'device-save');
      expect(
        find.text('Introduce una MAC válida de 12 caracteres hexadecimales.'),
        findsOneWidget,
      );
      expect(
        await container.read(deviceServiceProvider).forClient(client.id),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'List loading, storage error and explicit retry have usable states',
    (tester) async {
      final stream = StreamController<List<ClientRecord>>();
      addTearDown(stream.close);
      container.dispose();
      var attempts = 0;
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clientsProvider.overrideWith(
            (ref) => ++attempts == 1
                ? stream.stream
                : Stream.value(<ClientRecord>[]),
          ),
        ],
      );
      await open(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      stream.addError(StateError('Fallo sintético de lectura'));
      await settleClientData(tester);
      expect(find.text('No se pudieron cargar los clientes'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await settleClientData(tester);
      expect(find.text('No hay clientes en este filtro'), findsOneWidget);
      expect(attempts, 2);
    },
  );

  testWidgets(
    'Device IP validates, creates without MAC, edits and clears in detail',
    (tester) async {
      final client = await seed('ip-ui');
      await open(tester, '/clients/${client.id}/devices/new');
      await fillClientField(tester, 'device-ip', 'cliente.local');
      await pressClientControl(tester, 'device-save');
      expect(
        find.text(
          'Introduce una dirección IPv4 o IPv6 válida, sin puerto ni prefijo de red.',
        ),
        findsOneWidget,
      );
      expect(
        await container.read(deviceServiceProvider).forClient(client.id),
        isEmpty,
      );
      await fillClientField(tester, 'device-ip', '192.168.1.20');
      await pressClientControl(tester, 'device-save');
      expect(find.text('IP: 192.168.1.20'), findsOneWidget);
      final device =
          (await container.read(deviceServiceProvider).forClient(client.id))
              .single;
      expect(device.macAddress, isNull);
      await pressClientControl(tester, 'edit-device-${device.id}');
      await showControl(tester, const Key('device-ip'));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('device-ip')))
            .controller!
            .text,
        '192.168.1.20',
      );
      await fillClientField(tester, 'device-ip', '10.0.0.5');
      await pressClientControl(tester, 'device-save');
      await tester.tap(find.text('Guardar cambios'));
      await settleClientData(tester);
      expect(find.text('IP: 10.0.0.5'), findsOneWidget);
      await pressClientControl(tester, 'edit-device-${device.id}');
      await fillClientField(tester, 'device-ip', '   ');
      await pressClientControl(tester, 'device-save');
      await tester.tap(find.text('Guardar cambios'));
      await settleClientData(tester);
      final cleared =
          (await container.read(deviceServiceProvider).forClient(client.id))
              .single;
      expect(cleared.id, device.id);
      expect(cleared.ipAddress, isNull);
      expect(find.text('IP: 10.0.0.5'), findsNothing);
      expect(find.textContaining('0.0.0.0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Device IPv6 and MAC remain independent when editing notes and MAC',
    (tester) async {
      final client = await seed('ipv6-ui');
      await open(tester, '/clients/${client.id}/devices/new');
      await fillClientField(tester, 'device-mac', '02aabbccdd09');
      await fillClientField(
        tester,
        'device-ip',
        'FE80:0000:0000:0000:0000:0000:0000:0001',
      );
      await pressClientControl(tester, 'device-save');
      expect(find.text('IP: fe80::1'), findsOneWidget);
      final device =
          (await container.read(deviceServiceProvider).forClient(client.id))
              .single;
      await pressClientControl(tester, 'edit-device-${device.id}');
      await fillClientField(tester, 'device-mac', '02aabbccdd08');
      await fillClientField(
        tester,
        'device-notes',
        'Nota sintética con IP conservada',
      );
      await pressClientControl(tester, 'device-save');
      await tester.tap(find.text('Guardar cambios'));
      await settleClientData(tester);
      expect(find.text('02:AA:BB:CC:DD:08'), findsOneWidget);
      expect(find.text('IP: fe80::1'), findsOneWidget);
      expect(find.text('Nota sintética con IP conservada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Filters start collapsed and preserve selection with search and clearing',
    (tester) async {
      await seed('active', name: 'Activo de prueba');
      await seed(
        'archived',
        name: 'Archivado de prueba',
        status: ServiceStatus.archived,
      );
      await open(tester);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Filtros · Activo'), findsOneWidget);
      await pressClientControl(tester, 'client-filters');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Archivados'));
      await settleClientData(tester);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Archivados'))
            .selected,
        isTrue,
      );
      await pressClientControl(tester, 'client-filters');
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Filtros · Archivado'), findsOneWidget);
      await fillClientField(tester, 'client-search', 'activo');
      expect(find.text('No hay resultados'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await settleClientData(tester);
      expect(find.text('Archivado de prueba'), findsOneWidget);
      expect(find.text('Activo de prueba'), findsNothing);
      await pressClientControl(tester, 'client-filters');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Archivados'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'Client list at $width dp, text $scale and $brightness remains usable',
          (tester) async {
            tester.view.physicalSize = Size(width, 640);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(
              tester.platformDispatcher.clearPlatformBrightnessTestValue,
            );
            await seed(
              'layout-list',
              name:
                  'Cliente sintético con nombre largo para revisar la lectura',
            );
            await open(tester);
            expect(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.text('Clientes'),
              ),
              findsOneWidget,
            );
            expect(find.text('Mi Red'), findsNothing);
            if (scale == 1) {
              expect(
                tester.getSize(find.byKey(const Key('client-search'))).height,
                inInclusiveRange(48, 56),
              );
            }
            final theme = Theme.of(tester.element(find.byType(AppBar)));
            expect(
              theme.appBarTheme.systemOverlayStyle!.statusBarIconBrightness,
              brightness == Brightness.light
                  ? Brightness.dark
                  : Brightness.light,
            );
            await pressClientControl(tester, 'client-filters');
            await tester.ensureVisible(
              find.widgetWithText(ChoiceChip, 'Todos'),
            );
            await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
            await settleClientData(tester);
            await pressClientControl(tester, 'client-filters');
            await pressClientControl(tester, 'add-client');
            expect(find.text('Añadir cliente'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
      testWidgets(
        'Forms retain typed drafts through focus, theme and keyboard resize at $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await open(tester, '/clients/new');
          await fillClientField(
            tester,
            'client-name',
            'Borrador sintético persistente',
          );
          final nameController = tester
              .widget<TextFormField>(find.byKey(const Key('client-name')))
              .controller;
          await tester.testTextInput.receiveAction(TextInputAction.next);
          await tester.pump();
          final focused = tester
              .widgetList<EditableText>(find.byType(EditableText))
              .where((field) => field.focusNode.hasFocus)
              .single;
          expect(focused.keyboardType, TextInputType.phone);
          await tester.enterText(
            find.byKey(const Key('client-phone')),
            '+000 000000',
          );
          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark;
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          await settleClientData(tester);
          await showControl(tester, const Key('client-name'));
          expect(
            tester
                .widget<TextFormField>(find.byKey(const Key('client-name')))
                .controller,
            same(nameController),
          );
          expect(nameController!.text, 'Borrador sintético persistente');
          await fillClientField(tester, 'client-fee', '30,25');
          await fillClientField(
            tester,
            'client-notes',
            'Nota que sigue visible al desplazar',
          );
          await showControl(tester, const Key('client-save'));
          final saveRect = tester.getRect(find.byKey(const Key('client-save')));
          expect(saveRect.bottom, lessThanOrEqualTo(400));
          await pressClientControl(tester, 'client-save');
          tester.view.resetViewInsets();
          await settleClientData(tester);
          final client =
              (await container.read(clientServiceProvider).list()).single;
          expect(client.fullName, nameController.text);
          expect(client.monthlyFeeMinor, 3025);
          await pressClientControl(tester, 'add-device');
          await fillClientField(tester, 'device-mac', '02-aa-bb-cc-dd-05');
          await fillClientField(tester, 'device-ip', 'FE80::1');
          final ipController = tester
              .widget<TextFormField>(find.byKey(const Key('device-ip')))
              .controller;
          final macController = tester
              .widget<TextFormField>(find.byKey(const Key('device-mac')))
              .controller;
          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.light;
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          await settleClientData(tester);
          await fillClientField(
            tester,
            'device-notes',
            'Dispositivo de prueba',
          );
          await showControl(tester, const Key('device-mac'));
          expect(
            tester
                .widget<TextFormField>(find.byKey(const Key('device-mac')))
                .controller,
            same(macController),
          );
          expect(macController!.text, '02-aa-bb-cc-dd-05');
          await showControl(tester, const Key('device-ip'));
          final ipField = tester.widget<TextFormField>(
            find.byKey(const Key('device-ip')),
          );
          expect(ipField.controller, same(ipController));
          expect(ipField.controller!.text, 'FE80::1');
          expect(
            tester
                .widget<TextField>(
                  find.descendant(
                    of: find.byKey(const Key('device-ip')),
                    matching: find.byType(TextField),
                  ),
                )
                .keyboardType,
            TextInputType.text,
          );
          await showControl(tester, const Key('device-save'));
          expect(
            tester.getRect(find.byKey(const Key('device-save'))).bottom,
            lessThanOrEqualTo(400),
          );
          await pressClientControl(tester, 'device-save');
          tester.view.resetViewInsets();
          await settleClientData(tester);
          expect(
            (await container.read(deviceServiceProvider).forClient(client.id))
                .single
                .macAddress,
            '02:AA:BB:CC:DD:05',
          );
          expect(
            (await container.read(deviceServiceProvider).forClient(client.id))
                .single
                .ipAddress,
            'fe80::1',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Failed writes keep the form draft and allow a successful retry',
    (tester) async {
      final client = await seed('retry');
      await db.customStatement(
        "CREATE TRIGGER test_fail_edit BEFORE UPDATE ON clients BEGIN SELECT RAISE(ABORT, 'Fallo de prueba'); END",
      );
      await open(tester, '/clients/${client.id}/edit');
      await fillClientField(tester, 'client-name', 'Borrador recuperable');
      await pressClientControl(tester, 'client-save');
      expect(
        find.text(
          'No se pudo guardar el cliente. Tus cambios siguen aquí; vuelve a intentarlo.',
        ),
        findsOneWidget,
      );
      expect(
        (await container.read(clientServiceProvider).get(client.id)).fullName,
        client.fullName,
      );
      await showControl(tester, const Key('client-name'));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('client-name')))
            .controller!
            .text,
        'Borrador recuperable',
      );
      await db.customStatement('DROP TRIGGER test_fail_edit');
      await pressClientControl(tester, 'client-save');
      expect(find.text('Borrador recuperable'), findsOneWidget);
      expect(find.text('Ficha de cliente'), findsOneWidget);
    },
  );
}
