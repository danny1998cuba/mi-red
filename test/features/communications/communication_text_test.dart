import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';
import 'package:mi_red/features/billing/data/billing_queries.dart';
import 'package:mi_red/features/billing/data/billing_service.dart';
import 'package:mi_red/features/billing/data/payment_service.dart';
import 'package:mi_red/features/clients/data/client_service.dart';
import 'package:mi_red/features/clients/data/device_service.dart';
import 'package:mi_red/features/communications/communication_actions.dart';
import 'package:mi_red/features/communications/communication_text.dart';

void main() {
  test(
    'International recipient normalizes decorations but never guesses country',
    () {
      for (final value in [
        '+1 202-555-0123',
        ' +1 (202) 555 0123 ',
        '+12025550123',
      ]) {
        expect(whatsappDigits(value), '12025550123');
      }
      for (final value in [
        '',
        '2025550123',
        '12025550123',
        '0012025550123',
        '+02025550123',
        '+1 202 555 0123 ext 4',
        '+1+2025550123',
        '+12',
        '+1234567890123456',
        '+1 202/5550123',
      ]) {
        expect(
          () => whatsappDigits(value),
          throwsFormatException,
          reason: value,
        );
      }
    },
  );
  test('HTTPS wa.me URI round trips accents, symbols, plus, ampersand and newlines', () {
    const text = 'Hola, José & Ana + 👋.\nMes: marzo; importe 10,25 €? #1';
    final uri = whatsappUri('+1 (202) 555-0123', text);
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/12025550123');
    expect(uri.queryParameters, {'text': text});
    expect(uri.toString(), isNot(contains('\n')));
    expect(uri.path, isNot(contains('+')));
  });

  late AppDatabase db;
  late BillingService billing;
  late PaymentService payments;
  late ClientService clients;
  late BillingQueries queries;
  final today = LocalDate(2026, 12, 3);
  final now = DateTime(2026, 12, 3, 12);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    billing = BillingService(db);
    payments = PaymentService(db);
    clients = ClientService(db, billing);
    queries = BillingQueries(db, billing, payments);
  });
  tearDown(() => db.close());
  Future<void> create(String id, String name, int amount, {LocalDate? start}) =>
      clients.create(
        id: id,
        fullName: name,
        monthlyFeeMinor: amount,
        today: start ?? today,
        recordedAt: now,
        phone: '+12025550123',
        address: 'Dirección sintética privada',
        notes: 'Nota sintética privada',
      );
  BillingReport report(
    List<ReportEntry> entries, {
    ReportScope scope = ReportScope.fullPeriod,
  }) => BillingReport(
    period: BillingPeriod(2026, 12),
    scope: scope,
    generatedAt: now,
    currency: '€',
    entries: entries,
    filterDescription: 'Pendientes · búsqueda activa',
  );

  test('Reminder uses one historical charge, not current tariff or a sum of old debt', () async {
    await create(
      'history',
      'José\nCliente sintético',
      12345,
      start: LocalDate(2026, 11, 2),
    );
    await billing.reconcile(today: today, recordedAt: now);
    await clients.changeMonthlyFee(
      'history',
      99999,
      today: today,
      recordedAt: now,
    );
    final item = (await billing.chargesForPeriod(
      BillingPeriod(2026, 12),
      today: today,
    )).single;
    final text = reminderMessage('José\nCliente sintético', item, '€');
    expect(text, contains('José\nCliente sintético'));
    expect(text, contains('Diciembre 2026'));
    expect(text, contains('123,45 €'));
    expect(text, isNot(contains('999,99')));
    expect(text, isNot(contains('246,90')));
    expect(text, isNot(contains('suspend')));
    expect(text, contains('Si ya realizaste el pago'));
  });

  test('Paid charge never builds a false pending reminder; void restores the existing status', () async {
    await create('paid', 'Cliente sintético', 2500);
    final payment = await payments.register(
      chargeId: 'paid:2026-12',
      amountMinor: 2500,
      paidAt: now,
    );
    var item = (await billing.historyForClient('paid', today: today)).single;
    expect(
      () => reminderMessage('Cliente sintético', item, ''),
      throwsStateError,
    );
    await payments.voidPayment(payment.id, voidedAt: now);
    item = (await billing.historyForClient('paid', today: today)).single;
    expect(item.status, ChargeStatus.suspensionCandidate);
    expect(reminderMessage('Cliente sintético', item, ''), contains('25,00'));
  });

  test('Full and filtered reports calculate only their explicit rows and preserve stable source order', () async {
    await create('a', 'Alfa sintético', 10025);
    await create('b', 'Beta sintético', 5075);
    await payments.register(
      chargeId: 'a:2026-12',
      amountMinor: 10025,
      paidAt: now,
    );
    final data = await queries.periodData(BillingPeriod(2026, 12), today);
    final full = report(data.rows.map(ReportEntry.fromRow).toList());
    final filtered = report(
      data.rows
          .where((row) => row.item.activePayment == null)
          .map(ReportEntry.fromRow)
          .toList(),
      scope: ReportScope.filtered,
    );
    expect(full.paidCount, 1);
    expect(full.unpaidCount, 1);
    expect(full.outstandingMinor, data.outstandingMinor);
    expect(full.paidMinor, data.summary.collectedMinor);
    expect(full.render(), contains('Alcance: Período completo'));
    expect(
      full.render().indexOf('Beta sintético'),
      lessThan(full.render().indexOf('Alfa sintético')),
    );
    expect(filtered.render(), contains('Clientes: 1'));
    expect(filtered.render(), contains('Vista filtrada · Pendientes'));
    expect(filtered.render(), isNot(contains('Alfa sintético')));
    expect(filtered.paidCount, 0);
    expect(filtered.outstandingMinor, 5075);
  });

  test('Reports whitelist fields, exclude audit/devices/contact data, and separate older debt', () async {
    await create(
      'private-internal-id',
      'Nombre\nsintético',
      12999,
      start: LocalDate(2026, 11, 2),
    );
    await DeviceService(db).save(
      clientId: 'private-internal-id',
      type: 'router',
      macAddress: '02:00:00:00:06:01',
      ipAddress: const Value('192.0.2.6'),
      notes: 'Equipo sintético privado',
    );
    await billing.reconcile(today: today, recordedAt: now);
    final paid = await payments.register(
      chargeId: 'private-internal-id:2026-12',
      amountMinor: 12999,
      paidAt: now,
      note: 'Nota de pago privada',
    );
    await payments.voidPayment(paid.id, voidedAt: now);
    final data = await queries.periodData(BillingPeriod(2026, 12), today);
    final text = report(data.rows.map(ReportEntry.fromRow).toList()).render();
    expect(
      text,
      contains(
        'Nombre sintético — Candidato a suspensión — 129,99 € · Tiene deuda anterior',
      ),
    );
    expect(text, contains('Las deudas anteriores no están sumadas'));
    expect(text, isNot(contains('259,98')));
    for (final privateValue in [
      'private-internal-id',
      '+12025550123',
      'Dirección sintética privada',
      'Nota sintética privada',
      paid.id,
      'Nota de pago privada',
      'voided_at',
      '02:00:00:00:06:01',
      '192.0.2.6',
      'Equipo sintético privado',
      'MAC',
      'IP',
      'paid_at',
    ]) {
      expect(text, isNot(contains(privateValue)), reason: privateValue);
    }
  });

  test(
    'Preview limits rendering without silently truncating the selected report',
    () {
      final entries = [
        for (var index = 0; index < 25; index++)
          ReportEntry(
            'Cliente sintético $index',
            ChargeStatus.pending,
            100,
            false,
          ),
      ];
      final value = report(entries);
      expect(value.render(previewLimit: 20), contains('20 de 25'));
      expect(
        value.render(previewLimit: 20),
        isNot(contains('Cliente sintético 24 —')),
      );
      expect(value.render(), contains('Cliente sintético 24 —'));
      expect(value.render(), contains('Por cobrar: 25,00 €'));
    },
  );
  test('Empty report is explicit and zero remains a valid full charge', () {
    expect(report([]).render(), contains('No hay cargos en este listado.'));
    expect(report([]).outstandingMinor, 0);
    expect(
      report([
        const ReportEntry(
          'Cuota cero sintética',
          ChargeStatus.pending,
          0,
          false,
        ),
      ]).render(),
      contains('0,00 €'),
    );
  });
  test('Share outcomes never certify WhatsApp delivery and cancellation never reports success', () {
    expect(shareOutcomeMessage(ShareOutcome.dismissed), 'Compartir cancelado.');
    expect(
      shareOutcomeMessage(ShareOutcome.selected),
      contains('no confirma envío ni entrega'),
    );
    expect(
      shareOutcomeMessage(ShareOutcome.unavailable),
      contains('sin confirmación'),
    );
  });
}
