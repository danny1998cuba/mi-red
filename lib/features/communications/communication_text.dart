import '../billing/billing_calendar.dart';
import '../billing/billing_values.dart';
import '../billing/data/billing_queries.dart';
import '../billing/data/billing_service.dart';
import '../clients/client_values.dart';

/// Structural international format only; never infers a country/account.
String whatsappDigits(String input) {
  final value = input.trim();
  if (!RegExp(r'^\+[0-9 ()-]+$').hasMatch(value)) {
    throw const FormatException(
      'Usa +, código de país y número completo. No se puede adivinar el país.',
    );
  }
  final digits = value.substring(1).replaceAll(RegExp(r'[ ()-]'), '');
  if (!RegExp(r'^[1-9][0-9]{6,14}$').hasMatch(digits)) {
    throw const FormatException(
      'Revisa el número internacional: de 7 a 15 dígitos, con código de país sin cero inicial.',
    );
  }
  return digits;
}

Uri whatsappUri(String recipient, String message) =>
    Uri.https('wa.me', '/${whatsappDigits(recipient)}', {'text': message});

String reminderMessage(String name, ChargeWithStatus item, String currency) {
  if (item.activePayment != null || item.status == ChargeStatus.paid) {
    throw StateError('Esta mensualidad ya está pagada.');
  }
  return 'Hola, $name. Te recordamos que el pago del servicio de internet '
      'correspondiente a ${periodLabel(BillingPeriod.parse(item.charge.periodKey))} '
      'por ${formatMoneyMinor(item.charge.amountMinor, currencyLabel: currency)} está pendiente. '
      'Si ya realizaste el pago, puedes ignorar este aviso. Gracias.';
}

enum ReportScope { fullPeriod, filtered }

/// Whitelisted fields only: no contact, device, audit or internal identifiers.
class ReportEntry {
  const ReportEntry(
    this.name,
    this.status,
    this.amountMinor,
    this.hasPreviousDebt,
  );
  factory ReportEntry.fromRow(BillingRow row) => ReportEntry(
    row.client.fullName,
    row.item.status,
    row.item.charge.amountMinor,
    row.hasPreviousDebt,
  );
  final String name;
  final ChargeStatus status;
  final int amountMinor;
  final bool hasPreviousDebt;
}

class BillingReport {
  BillingReport({
    required this.period,
    required this.scope,
    required this.generatedAt,
    required this.currency,
    required List<ReportEntry> entries,
    this.filterDescription = '',
  }) : entries = List.unmodifiable(entries);
  final BillingPeriod period;
  final ReportScope scope;
  final DateTime generatedAt;
  final String currency, filterDescription;
  final List<ReportEntry> entries;
  int get paidCount =>
      entries.where((row) => row.status == ChargeStatus.paid).length;
  int get unpaidCount => entries.length - paidCount;
  int get outstandingMinor => entries
      .where((row) => row.status != ChargeStatus.paid)
      .fold(0, (sum, row) => sum + row.amountMinor);
  int get paidMinor => entries
      .where((row) => row.status == ChargeStatus.paid)
      .fold(0, (sum, row) => sum + row.amountMinor);
  String get scopeLabel =>
      scope == ReportScope.fullPeriod ? 'Período completo' : 'Vista filtrada';
  String _money(int value) =>
      formatMoneyMinor(value, currencyLabel: _oneLine(currency));
  String render({int? previewLimit}) {
    final shown = previewLimit == null ? entries : entries.take(previewLimit);
    return [
      'Mi Red · Cobros · ${periodLabel(period)}',
      'Generado: ${paymentDateLabel(generatedAt.millisecondsSinceEpoch)}',
      'Alcance: $scopeLabel${scope == ReportScope.filtered && filterDescription.isNotEmpty ? ' · ${_oneLine(filterDescription)}' : ''}',
      'Clientes: ${entries.length}',
      'Pagados: $paidCount · Sin pagar: $unpaidCount',
      'Pagado: ${_money(paidMinor)}',
      'Por cobrar: ${_money(outstandingMinor)}',
      '',
      if (entries.isEmpty) 'No hay cargos en este listado.',
      for (final row in shown)
        '${_oneLine(row.name)} — ${chargeStatusLabel(row.status)} — ${_money(row.amountMinor)}${row.hasPreviousDebt ? ' · Tiene deuda anterior' : ''}',
      if (previewLimit != null && entries.length > previewLimit)
        '\nVista previa: $previewLimit de ${entries.length}. El listado compartido incluirá todos los registros del alcance elegido.',
      if (entries.any((row) => row.hasPreviousDebt)) '\nLas deudas anteriores no están sumadas en los totales de este período.',
    ].join('\n');
  }
}

String _oneLine(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
