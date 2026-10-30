import 'package:timezone/timezone.dart' as tz;

import '../billing/billing_calendar.dart';

enum ReminderKind { review, candidates }

const reminderTestId = 200000000;
bool isReminderId(int id) => id >= 100000000 && id < reminderTestId;

class PlannedReminder {
  const PlannedReminder(this.kind, this.when);
  final ReminderKind kind;
  final tz.TZDateTime when;
  int get id => 100000000 + when.year * 10000 + when.month * 100 + when.day;
  String get title => kind == ReminderKind.review
      ? 'Revisa tus cobros'
      : 'Revisa posibles suspensiones';
  String get body => kind == ReminderKind.review
      ? 'Revisa los cobros pendientes en Mi Red.'
      : 'Revisa en Mi Red los clientes con cargos candidatos a suspensión. El servicio se cambia manualmente.';
}

/// Six calendar months at 09:00 in a real IANA location. No financial mutations.
List<PlannedReminder> planReminders(DateTime instant, tz.Location location) {
  final now = tz.TZDateTime.from(instant, location);
  final plan = <PlannedReminder>[];
  for (var offset = 0; offset < 6; offset++) {
    final month = tz.TZDateTime(location, now.year, now.month + offset, 1);
    final candidate = BillingPeriod(
      month.year,
      month.month,
    ).suspensionCandidateDate;
    for (final kind in ReminderKind.values) {
      final day = kind == ReminderKind.review
          ? candidate.day - 1
          : candidate.day;
      final when = tz.TZDateTime(
        location,
        candidate.year,
        candidate.month,
        day,
        9,
      );
      if (when.isAfter(now)) plan.add(PlannedReminder(kind, when));
    }
  }
  return plan;
}
