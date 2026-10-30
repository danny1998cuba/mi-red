import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/backups/backup_service.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_queries.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/client_values.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/communications/communication_text.dart';
import 'package:mi_red/features/settings/data/settings_service.dart';

void main() {
  late AppDatabase db;
  final today = LocalDate(2026, 12, 3);
  final now = DateTime(2026, 12, 3, 12);
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('business edits and reopening preserve opt-in, backup date and all financial rows', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp('mi-red-business-');
    final file = File('${directory.path}/business.sqlite');
    db = AppDatabase(NativeDatabase(file));
    final billing = BillingService(db);
    await ClientService(db, billing).create(
      id: 'synthetic',
      fullName: 'Cliente sintético',
      monthlyFeeMinor: 12345,
      today: today,
      recordedAt: now,
    );
    await SettingsService(db).setNotificationsEnabled(true);
    await BackupService(db).markExported(now);
    final before = await BackupService(db).capture(now);
    await SettingsService(db).update(
      businessName: '  Negocio sintético  ',
      currencyLabel: '  XTA  ',
      defaultCallingCode: ' +53 ',
    );
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    final settings = await SettingsService(db).read();
    expect(settings.businessName, 'Negocio sintético');
    expect(settings.currencyLabel, 'XTA');
    expect(settings.defaultCallingCode, '+53');
    expect(settings.notificationsEnabled, isTrue);
    expect(settings.lastBackupAt, now.millisecondsSinceEpoch);
    final after = await BackupService(db).capture(now);
    for (final table in ['clients', 'devices', 'charges', 'payments']) {
      expect(after.records[table], before.records[table]);
    }
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'T07 round trip retains business preferences and other settings exactly',
    () async {
      final settings = SettingsService(db);
      await settings.update(
        businessName: 'Negocio para recuperar',
        currencyLabel: 'Unidad local',
        defaultCallingCode: '+1',
        notificationsEnabled: true,
      );
      await BackupService(db).markExported(now);
      final snapshot = await BackupService(db).capture(now);
      await settings.update(
        businessName: 'Cambio posterior',
        currencyLabel: '',
        defaultCallingCode: null,
        notificationsEnabled: false,
      );
      await BackupService(db).restore(snapshot);
      expect(
        jsonEncode((await BackupService(db).capture(now)).records),
        jsonEncode(snapshot.records),
      );
      expect((await settings.read()).defaultCallingCode, '+1');
      expect((await settings.read()).lastBackupAt, now.millisecondsSinceEpoch);
    },
  );

  for (final invalid in <({String name, String currency, String? prefix})>[
    (name: ' ', currency: '', prefix: null),
    (name: 'n' * 121, currency: '', prefix: null),
    (name: 'Negocio\nno válido', currency: '', prefix: null),
    (name: 'Negocio', currency: 'x' * 49, prefix: null),
    (name: 'Negocio', currency: 'USD\nEUR', prefix: null),
    (name: 'Negocio', currency: '', prefix: '53'),
    (name: 'Negocio', currency: '', prefix: '+01'),
    (name: 'Negocio', currency: '', prefix: '+1234'),
    (name: 'Negocio', currency: '', prefix: '+1 2'),
  ]) {
    test(
      'invalid business input ${invalid.toString()} leaves settings unchanged',
      () async {
        final before = await SettingsService(db).read();
        await expectLater(
          SettingsService(db).update(
            businessName: invalid.name,
            currencyLabel: invalid.currency,
            defaultCallingCode: invalid.prefix,
          ),
          throwsArgumentError,
        );
        expect(await SettingsService(db).read(), before);
      },
    );
  }

  test('custom and empty labels reach all projections, reminders and reports without changing SQL money', () async {
    final billing = BillingService(db);
    final payments = PaymentService(db);
    final queries = BillingQueries(db, billing, payments);
    await ClientService(db, billing).create(
      id: 'labels',
      fullName: 'Cliente sintético',
      monthlyFeeMinor: 12345,
      phone: '2025550123',
      today: today,
      recordedAt: now,
    );
    final initial = await BackupService(db).capture(now);
    for (final currency in ['Unidad local', '']) {
      await SettingsService(db).update(
        businessName: 'Negocio',
        currencyLabel: currency,
        defaultCallingCode: '+1',
      );
      final data = await queries.periodData(currentPeriod(today), today);
      final history = (await queries.clientData('labels', today))!;
      final dashboard = await queries.dashboardData(today);
      expect([
        data.currencyLabel,
        history.currencyLabel,
        dashboard.billing.currencyLabel,
      ], everyElement(currency));
      final money = formatMoneyMinor(12345, currencyLabel: currency);
      expect(money, currency.isEmpty ? '123,45' : '123,45 Unidad local');
      expect(
        reminderMessage('Cliente', data.rows.single.item, data.currencyLabel),
        contains(money),
      );
      final report = BillingReport(
        period: currentPeriod(today),
        scope: ReportScope.fullPeriod,
        generatedAt: now,
        currency: data.currencyLabel,
        entries: data.rows.map(ReportEntry.fromRow).toList(),
      ).render();
      expect(report, contains(money));
      expect(
        () => whatsappUri(history.client.phone!, 'Recordatorio'),
        throwsFormatException,
      );
      final after = await BackupService(db).capture(now);
      for (final table in ['clients', 'devices', 'charges', 'payments']) {
        expect(after.records[table], initial.records[table]);
      }
    }
    await SettingsService(db).update(
      businessName: 'Negocio',
      currencyLabel: '  ',
      defaultCallingCode: ' ',
    );
    expect((await SettingsService(db).read()).currencyLabel, '');
    expect((await SettingsService(db).read()).defaultCallingCode, isNull);
  });
}
