import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../clients/client_providers.dart';
import 'billing_calendar.dart';
import 'data/billing_queries.dart';

final billingQueriesProvider = Provider(
  (ref) => BillingQueries(
    ref.watch(databaseProvider),
    ref.watch(billingServiceProvider),
    ref.watch(paymentServiceProvider),
  ),
);

/// Shared clock and readiness barrier for startup, resume and financial routes.
final billingSessionProvider = AsyncNotifierProvider<BillingSession, LocalDate>(
  BillingSession.new,
  retry: (count, error) => null,
);

class BillingSession extends AsyncNotifier<LocalDate> {
  Future<LocalDate> _reconcile() async {
    final now = ref.read(clientClockProvider)();
    final today = LocalDate.fromDateTime(now);
    await ref
        .read(billingServiceProvider)
        .reconcile(today: today, recordedAt: now);
    return today;
  }

  @override
  Future<LocalDate> build() => _reconcile();

  Future<void> refresh() async {
    if (state.isLoading) {
      // Coalesce overlapping entry/resume requests. Errors remain visible in state.
      try {
        await future;
      } catch (_) {
        /* Exposed by the readiness provider. */
      }
      return;
    }
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_reconcile);
    if (ref.mounted) state = result;
  }
}

final billingPeriodProvider = StreamProvider.autoDispose
    .family<BillingPeriodData, BillingPeriod>((ref, period) async* {
      final queries = ref.watch(billingQueriesProvider);
      final today = await ref.watch(billingSessionProvider.future);
      if (ref.mounted) yield* queries.watchPeriod(period, today);
    }, retry: (count, error) => null);

final clientBillingProvider = StreamProvider.autoDispose
    .family<ClientBillingData?, String>((ref, id) async* {
      final queries = ref.watch(billingQueriesProvider);
      final today = await ref.watch(billingSessionProvider.future);
      if (ref.mounted) yield* queries.watchClient(id, today);
    }, retry: (count, error) => null);
