import 'billing_calendar.dart';

const _months = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

String periodLabel(BillingPeriod period) =>
    '${_months[period.month - 1]} ${period.year}';
String calendarLabel(String date) {
  final value = LocalDate.parse(date);
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year.toString().padLeft(4, '0')}';
}

String paymentDateLabel(int instant) {
  final value = DateTime.fromMillisecondsSinceEpoch(instant);
  return '${calendarLabel(LocalDate.fromDateTime(value).toString())} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

BillingPeriod? adjacentPeriod(BillingPeriod period, int offset) {
  final index = (period.year - 1) * 12 + period.month - 1 + offset;
  return index < 0 || index >= 9999 * 12
      ? null
      : BillingPeriod(index ~/ 12 + 1, index % 12 + 1);
}

enum BillingFilter { all, unpaid, paid, suspensionCandidate }

String billingFilterLabel(BillingFilter filter) => switch (filter) {
  BillingFilter.all => 'Todos',
  BillingFilter.unpaid => 'Pendientes',
  BillingFilter.paid => 'Pagados',
  BillingFilter.suspensionCandidate => 'Posible suspensión',
};
String chargeStatusLabel(ChargeStatus status) => switch (status) {
  ChargeStatus.paid => 'Pagado',
  ChargeStatus.pending => 'Pendiente',
  ChargeStatus.suspensionCandidate => 'Candidato a suspensión',
};
