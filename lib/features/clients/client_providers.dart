import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';

final clientsProvider = StreamProvider.autoDispose<List<ClientRecord>>(
  (ref) => ref.watch(clientServiceProvider).watchAll(),
  retry: (count, error) => null,
);
final clientProvider = StreamProvider.autoDispose.family<ClientRecord?, String>(
  (ref, id) => ref.watch(clientServiceProvider).watchById(id),
);
final devicesProvider = StreamProvider.autoDispose
    .family<List<DeviceRecord>, String>(
      (ref, id) => ref.watch(deviceServiceProvider).watchForClient(id),
    );
final currencyLabelProvider = StreamProvider.autoDispose<String>(
  (ref) => ref
      .watch(settingsServiceProvider)
      .watch()
      .map((settings) => settings.currencyLabel),
);
final clientClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
