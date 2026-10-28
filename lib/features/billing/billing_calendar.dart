import 'dart:math';

int _daysInMonth(int year, int month) {
  if (month == 2) {
    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    return leap ? 29 : 28;
  }
  return const [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];
}

/// A local calendar date. No timezone or elapsed-time arithmetic is involved.
class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    if (year < 1 ||
        year > 9999 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > _daysInMonth(year, month)) {
      throw ArgumentError('Fecha de calendario inválida.');
    }
  }

  factory LocalDate.fromDateTime(DateTime instant) {
    final local = instant.toLocal();
    return LocalDate(local.year, local.month, local.day);
  }

  factory LocalDate.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw FormatException('La fecha debe tener formato YYYY-MM-DD.');
    }
    return LocalDate(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }

  final int year;
  final int month;
  final int day;

  @override
  int compareTo(LocalDate other) => (year * 10000 + month * 100 + day)
      .compareTo(other.year * 10000 + other.month * 100 + other.day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) => other is LocalDate && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(year, month, day);
}

class BillingPeriod implements Comparable<BillingPeriod> {
  BillingPeriod(this.year, this.month) {
    if (year < 1 || year > 9999 || month < 1 || month > 12) {
      throw ArgumentError('Período inválido.');
    }
  }

  factory BillingPeriod.parse(String key) {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(key)) {
      throw FormatException('El período debe tener formato YYYY-MM.');
    }
    return BillingPeriod(
      int.parse(key.substring(0, 4)),
      int.parse(key.substring(5)),
    );
  }

  final int year;
  final int month;

  String get key =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
  BillingPeriod get next =>
      month == 12 ? BillingPeriod(year + 1, 1) : BillingPeriod(year, month + 1);

  LocalDate get collectionDate {
    final previousYear = month == 1 ? year - 1 : year;
    final previousMonth = month == 1 ? 12 : month - 1;
    return LocalDate(
      previousYear,
      previousMonth,
      min(30, _daysInMonth(previousYear, previousMonth)),
    );
  }

  LocalDate get suspensionCandidateDate => LocalDate(year, month, 3);

  @override
  int compareTo(BillingPeriod other) =>
      (year * 12 + month).compareTo(other.year * 12 + other.month);

  @override
  bool operator ==(Object other) =>
      other is BillingPeriod && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(year, month);
}

BillingPeriod currentPeriod(LocalDate today) {
  final calendarMonth = BillingPeriod(today.year, today.month);
  final next = calendarMonth.next;
  return today.compareTo(next.collectionDate) >= 0 ? next : calendarMonth;
}

enum ChargeStatus { paid, pending, suspensionCandidate }

ChargeStatus chargeStatus({
  required bool hasActivePayment,
  required LocalDate suspensionCandidateDate,
  required LocalDate today,
}) => hasActivePayment
    ? ChargeStatus.paid
    : today.compareTo(suspensionCandidateDate) >= 0
    ? ChargeStatus.suspensionCandidate
    : ChargeStatus.pending;
