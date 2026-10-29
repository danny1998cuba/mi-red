import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../billing/billing_providers.dart';
import '../billing/data/billing_queries.dart';

final dashboardProvider = StreamProvider.autoDispose<DashboardData>((
  ref,
) async* {
  final queries = ref.watch(billingQueriesProvider);
  final today = await ref.watch(billingSessionProvider.future);
  if (ref.mounted) yield* queries.watchDashboard(today);
}, retry: (count, error) => null);
