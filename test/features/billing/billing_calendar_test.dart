import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/features/billing/billing_calendar.dart';

void main() {
  group('Local billing calendar', () {
    final cases = [
      (
        date: '2026-11-29',
        period: '2026-11',
        opens: '2026-10-30',
        candidate: '2026-11-03',
      ),
      (
        date: '2026-11-30',
        period: '2026-12',
        opens: '2026-11-30',
        candidate: '2026-12-03',
      ),
      (
        date: '2026-12-02',
        period: '2026-12',
        opens: '2026-11-30',
        candidate: '2026-12-03',
      ),
      (
        date: '2026-12-29',
        period: '2026-12',
        opens: '2026-11-30',
        candidate: '2026-12-03',
      ),
      (
        date: '2026-12-30',
        period: '2027-01',
        opens: '2026-12-30',
        candidate: '2027-01-03',
      ),
      (
        date: '2026-12-31',
        period: '2027-01',
        opens: '2026-12-30',
        candidate: '2027-01-03',
      ),
      (
        date: '2027-01-01',
        period: '2027-01',
        opens: '2026-12-30',
        candidate: '2027-01-03',
      ),
      (
        date: '2027-02-27',
        period: '2027-02',
        opens: '2027-01-30',
        candidate: '2027-02-03',
      ),
      (
        date: '2027-02-28',
        period: '2027-03',
        opens: '2027-02-28',
        candidate: '2027-03-03',
      ),
      (
        date: '2028-02-28',
        period: '2028-02',
        opens: '2028-01-30',
        candidate: '2028-02-03',
      ),
      (
        date: '2028-02-29',
        period: '2028-03',
        opens: '2028-02-29',
        candidate: '2028-03-03',
      ),
      (
        date: '2028-03-01',
        period: '2028-03',
        opens: '2028-02-29',
        candidate: '2028-03-03',
      ),
    ];
    for (final scenario in cases) {
      test('${scenario.date} belongs to ${scenario.period}', () {
        final period = currentPeriod(LocalDate.parse(scenario.date));
        expect(period.key, scenario.period);
        expect(period.collectionDate.toString(), scenario.opens);
        expect(period.suspensionCandidateDate.toString(), scenario.candidate);
      });
    }

    test(
      'Status changes on local day 3 and an active payment takes priority',
      () {
        final candidate = BillingPeriod(2026, 12).suspensionCandidateDate;
        expect(
          chargeStatus(
            hasActivePayment: false,
            suspensionCandidateDate: candidate,
            today: LocalDate(2026, 12, 2),
          ),
          ChargeStatus.pending,
        );
        expect(
          chargeStatus(
            hasActivePayment: false,
            suspensionCandidateDate: candidate,
            today: LocalDate(2026, 12, 3),
          ),
          ChargeStatus.suspensionCandidate,
        );
        expect(
          chargeStatus(
            hasActivePayment: true,
            suspensionCandidateDate: candidate,
            today: LocalDate(2026, 12, 3),
          ),
          ChargeStatus.paid,
        );
      },
    );

    test(
      'Calendar extraction preserves local dates regardless of audit instants',
      () {
        for (final hour in [0, 12, 23]) {
          expect(
            currentPeriod(LocalDate.fromDateTime(DateTime(2026, 11, 30, hour)))
                .key,
            '2026-12',
          );
        }
        final instant = DateTime.parse('2026-12-01T01:30:00+09:00');
        final local = instant.toLocal();
        expect(
          LocalDate.fromDateTime(instant),
          LocalDate(local.year, local.month, local.day),
        );
      },
    );

    test(
      'Rejects malformed dates and periods instead of normalizing silently',
      () {
        for (final invalid in [
          '2027-02-29',
          '2028-02-30',
          '2026-00-10',
          '0000-01-01',
        ]) {
          expect(() => LocalDate.parse(invalid), throwsArgumentError);
        }
        expect(() => LocalDate.parse('2026-2-03'), throwsFormatException);
        expect(() => BillingPeriod.parse('2026-13'), throwsArgumentError);
        expect(() => BillingPeriod.parse('2026-1'), throwsFormatException);
      },
    );
  });
}
