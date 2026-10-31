import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/client_values.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/clients/data/device_service.dart';

void main() {
  final today = LocalDate(2026, 12, 2);
  final now = DateTime(2026, 12, 2, 12);
  group('T03 service access', () {
    late AppDatabase db;
    late ClientService clients;
    late DeviceService devices;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      clients = ClientService(db, BillingService(db));
      devices = DeviceService(db);
    });
    tearDown(() => db.close());
    Future<ClientRecord> create(
      String id, {
      ServiceStatus status = ServiceStatus.active,
    }) => clients.create(
      id: id,
      fullName: 'Cliente de prueba $id',
      monthlyFeeMinor: 125050,
      today: today,
      recordedAt: now,
      status: status,
    );

    test('Profile tariff editing does not reconcile, mutate charges or rewrite payments', () async {
      final client = await clients.create(
        fullName: 'Cliente de prueba',
        monthlyFeeMinor: 10000,
        today: LocalDate(2026, 9, 5),
      );
      final charge = (await db.select(db.charges).get()).single;
      final payment = await PaymentService(db).register(
        chargeId: charge.id,
        amountMinor: charge.amountMinor,
        paidAt: now,
      );
      await clients.updateProfile(
        client.id,
        fullName: 'Cliente editado',
        monthlyFeeMinor: 250050,
        status: ServiceStatus.active,
        today: today,
      );
      expect(await db.select(db.charges).get(), [charge]);
      expect(await PaymentService(db).historyForClient(client.id), [payment]);
      expect((await clients.get(client.id)).monthlyFeeMinor, 250050);
    });
    test('Client and device watches emit edits on the same database', () async {
      final client = await create('watch');
      final iterator = StreamIterator(clients.watchById(client.id));
      final deviceIterator = StreamIterator(devices.watchForClient(client.id));
      try {
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current!.fullName, client.fullName);
        expect(await deviceIterator.moveNext(), isTrue);
        expect(deviceIterator.current, isEmpty);
        await clients.updateProfile(
          client.id,
          fullName: 'Nombre actualizado',
          monthlyFeeMinor: 101,
          status: ServiceStatus.active,
          today: today,
        );
        expect(
          await iterator.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(iterator.current!.fullName, 'Nombre actualizado');
        await devices.save(
          clientId: client.id,
          type: 'router',
          allowArchived: false,
        );
        expect(
          await deviceIterator.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(deviceIterator.current.length, 1);
      } finally {
        await iterator.cancel();
        await deviceIterator.cancel();
      }
    });
    test('Search covers name, phone, address, case, whitespace, state and stable order', () async {
      final a = await clients.create(
        id: 'a',
        fullName: 'ÁNGELA Prueba',
        phone: '+000 000000',
        address: 'Calle Ejemplo',
        monthlyFeeMinor: 0,
        today: today,
      );
      final b = await clients.create(
        id: 'b',
        fullName: 'beatriz Prueba',
        monthlyFeeMinor: 0,
        today: today,
        status: ServiceStatus.suspended,
      );
      final c = await clients.create(
        id: 'c',
        fullName: 'BEATRIZ Prueba',
        monthlyFeeMinor: 0,
        today: today,
      );
      final all = [c, a, b];
      expect(filterClients(all, query: ' ángela ', status: null), [a]);
      expect(filterClients(all, query: '000000', status: null), [a]);
      expect(filterClients(all, query: 'CALLE', status: null), [a]);
      expect(filterClients(all, query: '', status: ServiceStatus.suspended), [
        b,
      ]);
      expect(filterClients(all, query: 'beatriz', status: null), [b, c]);
      expect(
        filterClients(all, query: 'sin coincidencias', status: null),
        isEmpty,
      );
    });
    test('Manual service changes preserve existing finances and reactivation boundary', () async {
      final client = await create('status');
      final charge = (await db.select(db.charges).get()).single;
      await clients.updateProfile(
        client.id,
        fullName: client.fullName,
        monthlyFeeMinor: client.monthlyFeeMinor,
        status: ServiceStatus.suspended,
        today: today,
      );
      expect(await db.select(db.charges).get(), [charge]);
      await clients.updateProfile(
        client.id,
        fullName: client.fullName,
        monthlyFeeMinor: client.monthlyFeeMinor,
        status: ServiceStatus.active,
        today: today,
      );
      expect(await db.select(db.charges).get(), [charge]);
      await clients.changeStatus(
        client.id,
        ServiceStatus.archived,
        today: today,
      );
      expect(
        filterClients(
          await clients.list(),
          query: '',
          status: ServiceStatus.active,
        ),
        isEmpty,
      );
      expect(
        filterClients(
          await clients.list(),
          query: '',
          status: ServiceStatus.archived,
        ).length,
        1,
      );
      await clients.changeStatus(
        client.id,
        ServiceStatus.active,
        today: LocalDate(2027, 4, 10),
      );
      expect((await clients.get(client.id)).billingStartPeriod, '2027-04');
      expect((await db.select(db.charges).get()).map((row) => row.periodKey), [
        '2026-12',
        '2027-04',
      ]);
    });
    test(
      'Archived clients are read-only in the UI-facing write methods',
      () async {
        final client = await create('archived');
        final device = await devices.save(clientId: client.id, type: 'router');
        await clients.changeStatus(
          client.id,
          ServiceStatus.archived,
          today: today,
        );
        await expectLater(
          clients.updateProfile(
            client.id,
            fullName: 'Otro',
            monthlyFeeMinor: 10,
            status: ServiceStatus.active,
            today: today,
          ),
          throwsStateError,
        );
        await expectLater(
          devices.save(clientId: client.id, type: 'ont', allowArchived: false),
          throwsStateError,
        );
        await expectLater(
          devices.remove(device.device.id, allowArchived: false),
          throwsStateError,
        );
        expect((await devices.forClient(client.id)).length, 1);
      },
    );
    test(
      'Device edits, duplicate checks and deletion preserve client finances',
      () async {
        final client = await create('devices');
        final charge = (await db.select(db.charges).get()).single;
        final payment = await PaymentService(db).register(
          chargeId: charge.id,
          amountMinor: charge.amountMinor,
          paidAt: now,
        );
        final first = await devices.save(
          clientId: client.id,
          type: 'antenna',
          macAddress: '02-aa-bb-cc-dd-01',
          allowArchived: false,
        );
        final second = await devices.save(
          clientId: client.id,
          type: 'router',
          macAddress: '02aabbccdd02',
          allowArchived: false,
        );
        expect(await devices.hasDuplicateMac('02aabbccdd01'), isTrue);
        expect(
          await devices.hasDuplicateMac(
            '02aabbccdd01',
            excludingId: first.device.id,
          ),
          isFalse,
        );
        await devices.save(
          id: second.device.id,
          clientId: client.id,
          type: 'other',
          macAddress: '02:AA:BB:CC:DD:03',
          notes: 'Nota de prueba',
          allowArchived: false,
        );
        expect((await devices.forClient(client.id)).length, 2);
        await devices.remove(first.device.id, allowArchived: false);
        expect(await clients.get(client.id), client);
        expect(await db.select(db.charges).get(), [charge]);
        expect(await PaymentService(db).historyForClient(client.id), [payment]);
      },
    );
  });

  test(
    'Two clients with distinct exact fees survive closing and reopening a file',
    () async {
      final directory = await Directory.systemTemp.createTemp('mi_red_t03_');
      final file = File(
        '${directory.path}${Platform.pathSeparator}clients.sqlite',
      );
      AppDatabase? db;
      try {
        db = AppDatabase(NativeDatabase(file));
        final service = ClientService(db, BillingService(db));
        await service.create(
          fullName: 'Cliente de prueba A',
          monthlyFeeMinor: parseMoneyMinor('1250,50'),
          today: today,
        );
        await service.create(
          fullName: 'Cliente de prueba B',
          monthlyFeeMinor: parseMoneyMinor('987.65'),
          today: today,
        );
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        expect(
          (await ClientService(
            db,
            BillingService(db),
          ).list()).map((row) => row.monthlyFeeMinor),
          [125050, 98765],
        );
      } finally {
        await db?.close();
        if (await directory.parent.resolveSymbolicLinks() !=
            await Directory.systemTemp.resolveSymbolicLinks()) {
          throw StateError('Carpeta temporal inesperada.');
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
