import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/core/database/database_providers.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/clients/data/device_service.dart';
import 'package:mi_red/features/settings/data/settings_service.dart';

void main() {
  late AppDatabase db;
  late BillingService billing;
  late ClientService clients;
  late PaymentService payments;
  late DeviceService devices;
  late SettingsService settings;
  final opening = LocalDate(2026, 11, 30);
  final audit = DateTime.parse('2026-11-30T16:00:00Z');

  group('In-memory SQLite', () {
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      billing = BillingService(db);
      clients = ClientService(db, billing);
      payments = PaymentService(db);
      devices = DeviceService(db);
      settings = SettingsService(db);
    });
    tearDown(() => db.close());

    Future<ClientRecord> create({
      String id = 'synthetic-a',
      int fee = 10000,
      LocalDate? today,
      ServiceStatus status = ServiceStatus.active,
    }) => clients.create(
      id: id,
      fullName: 'Cliente de prueba $id',
      monthlyFeeMinor: fee,
      today: today ?? opening,
      recordedAt: audit,
      status: status,
    );

    Future<ChargeRecord> charge(String clientId, String period) =>
        (db.select(db.charges)..where(
              (row) =>
                  row.clientId.equals(clientId) & row.periodKey.equals(period),
            ))
            .getSingle();

    test('Current schema enables FKs and initializes exactly one safe settings row', () async {
      final initial = await settings.read();
      expect(initial.id, 1);
      expect(initial.businessName, 'Mi Red');
      expect(initial.currencyLabel, isEmpty);
      expect(initial.defaultCallingCode, isNull);
      expect(initial.notificationsEnabled, isFalse);
      expect(initial.lastBackupAt, isNull);
      expect(
        (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<int>(
          'foreign_keys',
        ),
        1,
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        3,
      );
      await expectLater(
        db.customStatement('INSERT INTO app_settings(id) VALUES (2)'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.customStatement('INSERT INTO app_settings(id) VALUES (1)'),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });

    test('SQLite rejects negative fees, fractional money, invalid names and statuses', () async {
      final client = await create();
      for (final assignment in [
        "monthly_fee_minor = -1",
        "monthly_fee_minor = 1.5",
        "full_name = ' '",
        "status = 'paid'",
        "billing_start_period = '2026-13'",
      ]) {
        await expectLater(
          db.customStatement('UPDATE clients SET $assignment WHERE id = ?', [
            client.id,
          ]),
          throwsA(isA<SqliteException>()),
        );
      }
      expect(await clients.get(client.id), client);
      await expectLater(create(id: 'invalid', fee: -1), throwsArgumentError);
      expect((await clients.list()).length, 1);
    });

    test('Individual tariffs generate distinct snapshots and explicit period dates', () async {
      final first = await create();
      final second = await create(id: 'synthetic-b', fee: 23501);
      final rows = await billing.chargesForPeriod(
        BillingPeriod(2026, 12),
        today: opening,
      );
      expect(rows.map((row) => row.charge.amountMinor), [10000, 23501]);
      for (final client in [first, second]) {
        final stored = await charge(client.id, '2026-12');
        expect(stored.collectionDate, '2026-11-30');
        expect(stored.suspensionCandidateDate, '2026-12-03');
        expect(stored.createdAt, audit.millisecondsSinceEpoch);
      }
      expect((await db.select(db.charges).get()).length, 2);
    });

    test('Reconciliation catches up missed months and is idempotent without altering paid rows', () async {
      final client = await create(today: LocalDate(2026, 9, 5));
      final original = await charge(client.id, '2026-09');
      final payment = await payments.register(
        chargeId: original.id,
        amountMinor: original.amountMinor,
        paidAt: audit,
      );
      expect(
        await billing.reconcile(
          today: LocalDate(2026, 12, 3),
          recordedAt: audit,
        ),
        3,
      );
      expect(await billing.reconcile(today: LocalDate(2026, 12, 3)), 0);
      expect(await billing.reconcile(today: LocalDate(2026, 12, 3)), 0);
      final history = await billing.historyForClient(
        client.id,
        today: LocalDate(2026, 12, 3),
      );
      expect(history.map((row) => row.charge.periodKey), [
        '2026-09',
        '2026-10',
        '2026-11',
        '2026-12',
      ]);
      expect(await charge(client.id, '2026-09'), original);
      expect(await payments.historyForCharge(original.id), [payment]);
    });

    test('Late registration gets only the current period and clock reversal creates no earlier charges', () async {
      final client = await create(today: LocalDate(2026, 12, 10));
      expect(await billing.reconcile(today: LocalDate(2026, 12, 29)), 0);
      expect(await billing.reconcile(today: LocalDate(2026, 10, 1)), 0);
      expect(
        (await billing.historyForClient(
          client.id,
          today: opening,
        )).map((row) => row.charge.periodKey),
        ['2026-12'],
      );
      expect(await billing.reconcile(today: LocalDate(2026, 12, 31)), 1);
      expect((await charge(client.id, '2027-01')).collectionDate, '2026-12-30');
    });

    test('Tariff updates never rewrite existing charges or payments', () async {
      final client = await create();
      final december = await charge(client.id, '2026-12');
      final payment = await payments.register(
        chargeId: december.id,
        amountMinor: december.amountMinor,
        paidAt: audit,
      );
      await clients.changeMonthlyFee(
        client.id,
        25000,
        today: LocalDate(2026, 12, 10),
      );
      await billing.reconcile(today: LocalDate(2026, 12, 30));
      expect(await charge(client.id, '2026-12'), december);
      expect((await charge(client.id, '2027-01')).amountMinor, 25000);
      expect(await payments.historyForCharge(december.id), [payment]);
    });

    test(
      'Changing a tariff first settles missing periods at the previous tariff',
      () async {
        final client = await create(today: LocalDate(2026, 9, 5));
        await clients.changeMonthlyFee(
          client.id,
          25000,
          today: LocalDate(2026, 11, 29),
        );
        for (final key in ['2026-09', '2026-10', '2026-11']) {
          expect((await charge(client.id, key)).amountMinor, 10000);
        }
        await billing.reconcile(today: opening);
        expect((await charge(client.id, '2026-12')).amountMinor, 25000);
      },
    );

    test('Archiving retains history, stops charges, and reactivation skips inactive months', () async {
      final client = await create();
      final december = await charge(client.id, '2026-12');
      final payment = await payments.register(
        chargeId: december.id,
        amountMinor: december.amountMinor,
        paidAt: audit,
      );
      await clients.changeStatus(
        client.id,
        ServiceStatus.archived,
        today: LocalDate(2026, 12, 10),
        recordedAt: audit,
      );
      expect(
        (await clients.get(client.id)).archivedAt,
        audit.millisecondsSinceEpoch,
      );
      expect(await billing.reconcile(today: LocalDate(2027, 3, 10)), 0);
      expect(await payments.historyForClient(client.id), [payment]);
      await clients.changeStatus(
        client.id,
        ServiceStatus.active,
        today: LocalDate(2027, 4, 10),
      );
      await clients.changeStatus(
        client.id,
        ServiceStatus.active,
        today: LocalDate(2027, 4, 11),
      );
      expect(await billing.reconcile(today: LocalDate(2027, 4, 11)), 0);
      expect((await clients.get(client.id)).archivedAt, isNull);
      expect(
        (await billing.historyForClient(
          client.id,
          today: LocalDate(2027, 4, 11),
        )).map((row) => row.charge.periodKey),
        ['2026-12', '2027-04'],
      );
      expect(await charge(client.id, '2026-12'), december);
      expect(await billing.reconcile(today: LocalDate(2027, 5, 10)), 1);
    });

    test('Suspended service does not generate charges and reactivates from the current period', () async {
      final client = await create(status: ServiceStatus.suspended);
      expect(await billing.reconcile(today: LocalDate(2027, 2, 10)), 0);
      expect(await db.select(db.charges).get(), isEmpty);
      await clients.changeStatus(
        client.id,
        ServiceStatus.active,
        today: LocalDate(2027, 2, 10),
      );
      expect((await db.select(db.charges).get()).single.periodKey, '2027-02');
    });

    test('Day 2 is pending and day 3 is a candidate without changing service status', () async {
      final client = await create();
      for (final entry in [
        (day: 2, status: ChargeStatus.pending),
        (day: 3, status: ChargeStatus.suspensionCandidate),
      ]) {
        final rows = await billing.chargesForPeriod(
          BillingPeriod(2026, 12),
          today: LocalDate(2026, 12, entry.day),
        );
        expect(rows.single.status, entry.status);
        expect((await clients.get(client.id)).status, 'active');
      }
    });

    test('Full payments, voiding, and replacement preserve the original audit trail', () async {
      final client = await create();
      final stored = await charge(client.id, '2026-12');
      for (final amount in [-1, 9999, 10001]) {
        await expectLater(
          payments.register(
            chargeId: stored.id,
            amountMinor: amount,
            paidAt: audit,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        payments.register(
          chargeId: 'missing',
          amountMinor: 10000,
          paidAt: audit,
        ),
        throwsStateError,
      );
      final first = await payments.register(
        chargeId: stored.id,
        amountMinor: 10000,
        paidAt: audit,
        note: 'Registro de prueba',
      );
      expect(
        (await billing.chargesForPeriod(
          BillingPeriod(2026, 12),
          today: LocalDate(2026, 12, 3),
        )).single.status,
        ChargeStatus.paid,
      );
      await expectLater(
        payments.register(
          chargeId: stored.id,
          amountMinor: 10000,
          paidAt: audit,
        ),
        throwsStateError,
      );
      final voidedAt = audit.add(const Duration(hours: 1));
      await payments.voidPayment(first.id, voidedAt: voidedAt);
      expect(
        (await billing.chargesForPeriod(
          BillingPeriod(2026, 12),
          today: LocalDate(2026, 12, 2),
        )).single.status,
        ChargeStatus.pending,
      );
      expect(
        (await billing.chargesForPeriod(
          BillingPeriod(2026, 12),
          today: LocalDate(2026, 12, 3),
        )).single.status,
        ChargeStatus.suspensionCandidate,
      );
      expect(
        (await payments.historyForCharge(stored.id)).single,
        first.copyWith(voidedAt: Value(voidedAt.millisecondsSinceEpoch)),
      );
      await expectLater(
        payments.voidPayment(first.id, voidedAt: voidedAt),
        throwsStateError,
      );
      await expectLater(
        payments.voidPayment('missing', voidedAt: voidedAt),
        throwsStateError,
      );
      final replacement = await payments.register(
        chargeId: stored.id,
        amountMinor: 10000,
        paidAt: voidedAt,
      );
      expect(replacement.id, isNot(first.id));
      expect((await payments.historyForCharge(stored.id)).length, 2);
      final summary = await billing.summary(
        BillingPeriod(2026, 12),
        today: LocalDate(2026, 12, 3),
      );
      expect(summary.paidCharges, 1);
      expect(summary.collectedMinor, 10000);
    });

    test(
      'Zero tariff stays unpaid until an explicit full zero payment',
      () async {
        final client = await create(fee: 0);
        final stored = await charge(client.id, '2026-12');
        expect(
          (await billing.chargesForPeriod(
            BillingPeriod(2026, 12),
            today: opening,
          )).single.status,
          ChargeStatus.pending,
        );
        await payments.register(
          chargeId: stored.id,
          amountMinor: 0,
          paidAt: audit,
        );
        expect(
          (await billing.chargesForPeriod(
            BillingPeriod(2026, 12),
            today: opening,
          )).single.status,
          ChargeStatus.paid,
        );
      },
    );

    test(
      'Paying the current period does not clear an older overdue debt',
      () async {
        final client = await create();
        final today = LocalDate(2027, 1, 3);
        await billing.reconcile(today: today);
        final january = await charge(client.id, '2027-01');
        await payments.register(
          chargeId: january.id,
          amountMinor: january.amountMinor,
          paidAt: audit,
        );
        expect(
          await billing.clientHasOverdueDebt(client.id, today: today),
          isTrue,
        );
        final december = await charge(client.id, '2026-12');
        await payments.register(
          chargeId: december.id,
          amountMinor: december.amountMinor,
          paidAt: audit,
        );
        expect(
          await billing.clientHasOverdueDebt(client.id, today: today),
          isFalse,
        );
        expect(
          (await billing.historyForClient(client.id, today: today)).length,
          2,
        );
      },
    );

    test('Summaries retain archived finances, count active clients separately and exclude voids', () async {
      final first = await create();
      final second = await create(id: 'synthetic-b', fee: 20000);
      final third = await create(id: 'synthetic-c', fee: 30000);
      final stored = await charge(first.id, '2026-12');
      final voided = await payments.register(
        chargeId: stored.id,
        amountMinor: 10000,
        paidAt: audit,
      );
      await payments.voidPayment(voided.id, voidedAt: audit);
      await payments.register(
        chargeId: stored.id,
        amountMinor: 10000,
        paidAt: audit,
      );
      await clients.changeStatus(
        second.id,
        ServiceStatus.archived,
        today: opening,
      );
      await clients.changeStatus(
        third.id,
        ServiceStatus.suspended,
        today: opening,
      );
      final pending = await billing.summary(
        BillingPeriod(2026, 12),
        today: LocalDate(2026, 12, 2),
      );
      expect(pending.activeClients, 1);
      expect(pending.totalCharges, 3);
      expect(pending.paidCharges, 1);
      expect(pending.pendingCharges, 2);
      expect(pending.unpaidCharges, 2);
      expect(pending.suspensionCandidateCharges, 0);
      expect(pending.collectedMinor, 10000);
      final overdue = await billing.summary(
        BillingPeriod(2026, 12),
        today: LocalDate(2026, 12, 3),
      );
      expect(overdue.pendingCharges, 0);
      expect(overdue.suspensionCandidateCharges, 2);
      expect(
        await billing.clientHasOverdueDebt(
          second.id,
          today: LocalDate(2026, 12, 3),
        ),
        isTrue,
      );
    });

    test('Device access normalizes MAC, warns on duplicates and permits multiple devices', () async {
      final client = await create();
      final first = await devices.save(
        clientId: client.id,
        type: 'antenna',
        macAddress: '02-aa-bb-cc-dd-01',
      );
      expect(first.device.macAddress, '02:AA:BB:CC:DD:01');
      expect(first.hasDuplicateMac, isFalse);
      final duplicate = await devices.save(
        clientId: client.id,
        type: 'router',
        macAddress: '02aabbccdd01',
      );
      expect(duplicate.hasDuplicateMac, isTrue);
      await devices.save(clientId: client.id, type: 'ont');
      expect((await devices.forClient(client.id)).length, 3);
      final edited = await devices.save(
        id: first.device.id,
        clientId: client.id,
        type: 'other',
        macAddress: '02:aa:bb:cc:dd:02',
        notes: 'Equipo de prueba',
      );
      expect(edited.hasDuplicateMac, isFalse);
      expect(edited.device.type, 'other');
      expect(edited.device.macAddress, '02:AA:BB:CC:DD:02');
      await expectLater(
        devices.save(
          clientId: client.id,
          type: 'router',
          macAddress: 'invalid',
        ),
        throwsArgumentError,
      );
      await devices.remove(duplicate.device.id);
      expect((await devices.forClient(client.id)).length, 2);
      await expectLater(devices.remove('missing'), throwsStateError);
    });

    test(
      'Foreign keys reject orphans and prevent deleting financial clients',
      () async {
        final client = await create();
        await expectLater(
          devices.save(clientId: 'missing', type: 'router'),
          throwsA(isA<SqliteException>()),
        );
        await expectLater(
          db.customStatement(
            "INSERT INTO charges VALUES ('orphan','missing','2026-12','2026-11-30','2026-12-03',100,0)",
          ),
          throwsA(isA<SqliteException>()),
        );
        await expectLater(
          db.customStatement('DELETE FROM clients WHERE id = ?', [client.id]),
          throwsA(isA<SqliteException>()),
        );
        expect(await db.select(db.devices).get(), isEmpty);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );

    test('SQL constraints enforce charge uniqueness, exact payments and immutable payment history', () async {
      final client = await create();
      final stored = await charge(client.id, '2026-12');
      await expectLater(
        db.into(db.charges).insert(stored.copyWith(id: 'duplicate')),
        throwsA(isA<SqliteException>()),
      );
      for (final assignment in [
        "amount_minor = -1",
        "period_key = '2026-13'",
        "collection_date = '2026-02-30'",
        "suspension_candidate_date = '2026-12-04'",
      ]) {
        await expectLater(
          db.customStatement('UPDATE charges SET $assignment WHERE id = ?', [
            stored.id,
          ]),
          throwsA(isA<SqliteException>()),
        );
      }
      await expectLater(
        db
            .into(db.payments)
            .insert(
              PaymentsCompanion.insert(
                id: 'wrong-amount',
                chargeId: stored.id,
                amountMinor: 9999,
                paidAt: 0,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      final paid = await payments.register(
        chargeId: stored.id,
        amountMinor: 10000,
        paidAt: audit,
      );
      await expectLater(
        db.into(db.payments).insert(paid.copyWith(id: 'duplicate-active')),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.customStatement(
          "UPDATE payments SET note = 'changed' WHERE id = ?",
          [paid.id],
        ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.customStatement(
          'UPDATE charges SET amount_minor = 20000 WHERE id = ?',
          [stored.id],
        ),
        throwsA(isA<SqliteException>()),
      );
      await payments.voidPayment(paid.id, voidedAt: audit);
      await expectLater(
        db.customStatement(
          'UPDATE payments SET voided_at = NULL WHERE id = ?',
          [paid.id],
        ),
        throwsA(isA<SqliteException>()),
      );
      expect((await payments.historyForCharge(stored.id)).length, 1);
    });

    test('Voided historical amounts remain valid when an unpaid charge is explicitly corrected', () async {
      final client = await create();
      final stored = await charge(client.id, '2026-12');
      final paid = await payments.register(
        chargeId: stored.id,
        amountMinor: 10000,
        paidAt: audit,
      );
      await payments.voidPayment(paid.id, voidedAt: audit);
      // Exercise the SQL invariant only. The confirmed editing UI/API is T04.
      await db.customStatement(
        'UPDATE charges SET amount_minor = 20000 WHERE id = ?',
        [stored.id],
      );
      final archivedPayment = paid.copyWith(
        id: 'synthetic-voided-history',
        voidedAt: Value(audit.millisecondsSinceEpoch),
      );
      await db.into(db.payments).insert(archivedPayment);
      await expectLater(
        payments.register(
          chargeId: stored.id,
          amountMinor: 10000,
          paidAt: audit,
        ),
        throwsArgumentError,
      );
      await payments.register(
        chargeId: stored.id,
        amountMinor: 20000,
        paidAt: audit,
      );
      final history = await payments.historyForCharge(stored.id);
      expect(
        history
            .where((row) => row.voidedAt != null)
            .map((row) => row.amountMinor),
        [10000, 10000],
      );
      expect(
        history.singleWhere((row) => row.voidedAt == null).amountMinor,
        20000,
      );
    });

    test('A failing reconciliation rolls back every newly generated month for all clients', () async {
      await create(today: LocalDate(2026, 9, 5));
      await create(id: 'synthetic-b', today: LocalDate(2026, 9, 5));
      final before = await db.select(db.charges).get();
      await db.customStatement(
        "CREATE TRIGGER test_reject_december BEFORE INSERT ON charges WHEN NEW.period_key = '2026-12' BEGIN SELECT RAISE(ABORT, 'Fallo de prueba'); END",
      );
      await expectLater(
        billing.reconcile(today: LocalDate(2026, 12, 3)),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.select(db.charges).get(), before);
      await db.customStatement('DROP TRIGGER test_reject_december');
      expect(await billing.reconcile(today: LocalDate(2026, 12, 3)), 6);
    });

    test('Client creation and payment changes roll back together with nested failures', () async {
      await db.customStatement(
        "CREATE TRIGGER test_reject_charge BEFORE INSERT ON charges BEGIN SELECT RAISE(ABORT, 'Fallo de prueba'); END",
      );
      await expectLater(create(), throwsA(isA<SqliteException>()));
      expect(await clients.list(), isEmpty);
      expect(await db.select(db.charges).get(), isEmpty);
      await db.customStatement('DROP TRIGGER test_reject_charge');
      final client = await create();
      final stored = await charge(client.id, '2026-12');
      await expectLater(
        db.transaction(() async {
          await payments.register(
            chargeId: stored.id,
            amountMinor: 10000,
            paidAt: audit,
          );
          await devices.save(clientId: 'missing', type: 'router');
        }),
        throwsA(isA<SqliteException>()),
      );
      expect(await payments.historyForCharge(stored.id), isEmpty);
    });

    test('Concurrent reconciliation and payment attempts still leave one charge and active payment', () async {
      final client = await create();
      final results = await Future.wait([
        billing.reconcile(today: LocalDate(2026, 12, 30)),
        billing.reconcile(today: LocalDate(2026, 12, 30)),
      ]);
      expect(results.reduce((a, b) => a + b), 1);
      final stored = await charge(client.id, '2027-01');
      Future<bool> pay() async {
        try {
          await payments.register(
            chargeId: stored.id,
            amountMinor: 10000,
            paidAt: audit,
          );
          return true;
        } on StateError {
          return false;
        }
      }

      expect(
        (await Future.wait([pay(), pay()])).where((success) => success).length,
        1,
      );
      expect((await payments.historyForCharge(stored.id)).length, 1);
    });

    test(
      'Contact and settings edits persist without modifying financial data',
      () async {
        final client = await create();
        final original = await charge(client.id, '2026-12');
        await clients.updateContactDetails(
          client.id,
          fullName: 'Cliente de prueba editado',
          notes: 'Nota de prueba',
          recordedAt: audit,
        );
        expect(
          (await clients.get(client.id)).fullName,
          'Cliente de prueba editado',
        );
        expect(await charge(client.id, '2026-12'), original);
        expect((await clients.list(status: ServiceStatus.active)).length, 1);
        await settings.update(
          businessName: 'Negocio de prueba',
          currencyLabel: 'unidad',
          notificationsEnabled: false,
        );
        expect((await settings.read()).currencyLabel, 'unidad');
        expect((await charge(client.id, '2026-12')).amountMinor, 10000);
        await expectLater(
          settings.update(
            businessName: ' ',
            currencyLabel: '',
            notificationsEnabled: false,
          ),
          throwsArgumentError,
        );
      },
    );

    test('Providers share one injected database and service instances', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      expect(container.read(databaseProvider), same(db));
      expect(container.read(clientServiceProvider).db, same(db));
      expect(container.read(billingServiceProvider).db, same(db));
      expect(container.read(paymentServiceProvider).db, same(db));
      expect(container.read(deviceServiceProvider).db, same(db));
      expect(container.read(settingsServiceProvider).db, same(db));
      expect(
        container.read(clientServiceProvider).billing,
        same(container.read(billingServiceProvider)),
      );
    });
  });

  test('File database preserves all records and reactivation boundary across close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('mi_red_t02_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}persist.sqlite',
    );
    AppDatabase? disk;
    try {
      disk = AppDatabase(NativeDatabase(file));
      final diskBilling = BillingService(disk);
      final diskClients = ClientService(disk, diskBilling);
      final client = await diskClients.create(
        id: 'synthetic-disk',
        fullName: 'Cliente de prueba',
        monthlyFeeMinor: 12500,
        today: opening,
        recordedAt: audit,
      );
      final december = (await diskBilling.chargesForPeriod(
        BillingPeriod(2026, 12),
        today: opening,
      )).single.charge;
      final payment = await PaymentService(disk)
          .register(chargeId: december.id, amountMinor: 12500, paidAt: audit);
      await DeviceService(disk).save(clientId: client.id, type: 'router');
      await SettingsService(disk).update(
        businessName: 'Negocio de prueba',
        currencyLabel: 'unidad',
        notificationsEnabled: false,
      );
      await diskClients.changeStatus(
        client.id,
        ServiceStatus.archived,
        today: LocalDate(2026, 12, 10),
      );
      await diskClients.changeStatus(
        client.id,
        ServiceStatus.active,
        today: LocalDate(2027, 4, 10),
      );
      await disk.close();
      disk = AppDatabase(NativeDatabase(file));
      final reopenedBilling = BillingService(disk);
      expect(await reopenedBilling.reconcile(today: LocalDate(2027, 4, 10)), 0);
      expect(await reopenedBilling.reconcile(today: LocalDate(2027, 4, 10)), 0);
      final history = await reopenedBilling.historyForClient(
        client.id,
        today: LocalDate(2027, 4, 10),
      );
      expect(history.map((row) => row.charge.periodKey), [
        '2026-12',
        '2027-04',
      ]);
      expect(history.first.charge, december);
      expect(await PaymentService(disk).historyForClient(client.id), [payment]);
      expect((await DeviceService(disk).forClient(client.id)).length, 1);
      expect((await SettingsService(disk).read()).currencyLabel, 'unidad');
      expect(
        await disk.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await disk.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
    } finally {
      await disk?.close();
      // Only remove the uniquely created directory directly beneath systemTemp.
      if (await directory.parent.resolveSymbolicLinks() !=
          await Directory.systemTemp.resolveSymbolicLinks()) {
        throw StateError(
          'La carpeta temporal no está en la ubicación esperada.',
        );
      }
      await directory.delete(recursive: true);
    }
  });
}
