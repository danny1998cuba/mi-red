import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/clients/data/device_service.dart';

void main() {
  test('Optional IPv4 and IPv6 normalize locally and consistently', () {
    expect(normalizeIpAddress(null), isNull);
    expect(normalizeIpAddress('   '), isNull);
    for (final input in [
      '192.168.1.20',
      '10.0.0.5',
      '0.0.0.0',
      '255.255.255.255',
    ]) {
      expect(normalizeIpAddress(' $input '), input);
    }
    expect(
      normalizeIpAddress(' FE80:0000:0000:0000:0000:0000:0000:0001 '),
      'fe80::1',
    );
    expect(normalizeIpAddress('::1'), '::1');
    expect(normalizeIpAddress('::'), '::');
    expect(
      normalizeIpAddress(normalizeIpAddress('2001:DB8::ABCD')),
      '2001:db8::abcd',
    );
  });

  test(
    'IP rejects names, malformed numerics, ports, CIDR, zones and brackets',
    () {
      for (final input in [
        '192.168.1.999',
        '192.168.1',
        'cliente.local',
        '192.168.1.2:8080',
        '192.168.1.0/24',
        'texto libre',
        'fe80:::1',
        'gggg::1',
        '[fe80::1]',
        '[::1]:8080',
        'fe80::1%eth0',
        '127.1',
        '010.0.0.1',
        '0x7f000001',
        '2001:db8::/64',
        '192. 168.1.1',
      ]) {
        expect(
          () => normalizeIpAddress(input),
          throwsArgumentError,
          reason: input,
        );
      }
    },
  );

  test('IP saves, edits, clears and survives reopening without changing finances or MAC', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mi_red_device_ip_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/devices.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    try {
      final client = await ClientService(db, BillingService(db)).create(
        id: 'ip-client',
        fullName: 'Cliente sintético IP',
        monthlyFeeMinor: 12345,
        today: LocalDate(2026, 12, 2),
      );
      final finances = await db.select(db.charges).get();
      var service = DeviceService(db);
      final ipv4 = (await service.save(
        id: 'ipv4',
        clientId: client.id,
        type: DeviceType.router,
        ipAddress: const Value(' 192.168.1.20 '),
      )).device;
      expect(ipv4.macAddress, isNull);
      expect(ipv4.ipAddress, '192.168.1.20');
      final ipv6 = (await service.save(
        id: 'ipv6',
        clientId: client.id,
        type: DeviceType.ont,
        macAddress: '02aabbccdd01',
        ipAddress: const Value('FE80::1'),
      )).device;
      expect(ipv6.ipAddress, 'fe80::1');
      final noIp = (await service.save(
        id: 'empty',
        clientId: client.id,
        type: DeviceType.other,
        macAddress: '02aabbccdd02',
        ipAddress: const Value('  '),
      )).device;
      expect(noIp.ipAddress, isNull);
      final otherClient = await ClientService(db, BillingService(db)).create(
        id: 'other-ip-context',
        fullName: 'Otro cliente sintético',
        monthlyFeeMinor: 0,
        status: ServiceStatus.suspended,
        today: LocalDate(2026, 12, 2),
      );
      await service.save(
        id: 'same-ip',
        clientId: otherClient.id,
        type: DeviceType.antenna,
        ipAddress: const Value('192.168.1.20'),
      );
      await service.save(
        id: ipv6.id,
        clientId: client.id,
        type: DeviceType.router,
        macAddress: '02aabbccdd03',
        notes: 'Nota editada sin parámetro IP',
      );
      expect(
        (await service.forClient(client.id))
            .singleWhere((row) => row.id == ipv6.id)
            .ipAddress,
        'fe80::1',
      );
      await expectLater(
        service.save(
          id: ipv4.id,
          clientId: client.id,
          type: DeviceType.other,
          ipAddress: const Value('cliente.local'),
        ),
        throwsArgumentError,
      );
      expect(
        (await service.forClient(client.id))
            .singleWhere((row) => row.id == ipv4.id),
        ipv4,
      );
      await service.save(
        id: ipv6.id,
        clientId: client.id,
        type: DeviceType.router,
        macAddress: '02aabbccdd03',
        ipAddress: const Value('10.0.0.5'),
      );
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      service = DeviceService(db);
      final edited = (await service.forClient(client.id))
          .singleWhere((row) => row.id == ipv6.id);
      expect(edited.ipAddress, '10.0.0.5');
      expect(edited.macAddress, '02:AA:BB:CC:DD:03');
      await service.save(
        id: ipv6.id,
        clientId: client.id,
        type: DeviceType.router,
        macAddress: edited.macAddress,
        notes: edited.notes,
        ipAddress: const Value(null),
      );
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      final cleared = (await DeviceService(db).forClient(client.id))
          .singleWhere((row) => row.id == ipv6.id);
      expect(cleared.ipAddress, isNull);
      expect(cleared.macAddress, edited.macAddress);
      expect((await db.select(db.devices).get()).length, 4);
      expect(await db.select(db.charges).get(), finances);
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      await db.close();
    }
  });
}
