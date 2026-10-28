import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/billing/data/billing_service.dart';
import '../../features/billing/data/payment_service.dart';
import '../../features/clients/data/client_service.dart';
import '../../features/clients/data/device_service.dart';
import '../../features/settings/data/settings_service.dart';
import 'app_database.dart';
import 'database_connection.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(openAppDatabase());
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final billingServiceProvider = Provider(
  (ref) => BillingService(ref.watch(databaseProvider)),
);
final clientServiceProvider = Provider(
  (ref) => ClientService(
    ref.watch(databaseProvider),
    ref.watch(billingServiceProvider),
  ),
);
final deviceServiceProvider = Provider(
  (ref) => DeviceService(ref.watch(databaseProvider)),
);
final paymentServiceProvider = Provider(
  (ref) => PaymentService(ref.watch(databaseProvider)),
);
final settingsServiceProvider = Provider(
  (ref) => SettingsService(ref.watch(databaseProvider)),
);
