import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/navigation/app_router.dart';
import '../clients/client_providers.dart';
import 'reminder_plan.dart';
import 'reminder_scheduler.dart';

final reminderNavigationProvider = Provider<void Function(ReminderKind)>((ref) {
  final router = ref.watch(appRouterProvider);
  var request = 0;
  return (kind) => router.go(
    '/billing?filter=unpaid&reminder=${kind.name}&request=${++request}',
  );
});

class ReminderState {
  const ReminderState({
    required this.enabled,
    required this.permission,
    this.scheduledCount = 0,
    this.notice,
  });
  final bool enabled;
  final ReminderPermission permission;
  final int scheduledCount;
  final String? notice;
}

final remindersProvider =
    AsyncNotifierProvider<RemindersController, ReminderState>(
      RemindersController.new,
      retry: (count, error) => null,
    );

class RemindersController extends AsyncNotifier<ReminderState> {
  Future<String?>? _initialization;
  bool _handledLaunch = false;
  String? _signature;
  Future<void>? _operation;
  String? _operationKey;
  ReminderScheduler get _scheduler => ref.read(reminderSchedulerProvider);

  @override
  Future<ReminderState> build() => _refresh();

  void _onTap(String payload) {
    if (!ref.mounted) return;
    for (final kind in ReminderKind.values) {
      if (payload == kind.name) {
        ref.read(reminderNavigationProvider)(kind);
        return;
      }
    }
  }

  Future<void> _initialize() async {
    String? launch;
    try {
      launch = await (_initialization ??= _scheduler.initialize(_onTap));
    } catch (_) {
      _initialization = null;
      rethrow;
    }
    if (!_handledLaunch) {
      _handledLaunch = true;
      if (launch != null) _onTap(launch);
    }
  }

  Future<void> _cancel() async {
    for (final id in await _scheduler.pendingIds()) {
      if (isReminderId(id)) await _scheduler.cancel(id);
    }
    await _scheduler.cancel(reminderTestId);
    _signature = null;
  }

  Future<int> _schedule() async {
    final zone = await _scheduler.localZone();
    final now = ref.read(clientClockProvider)();
    final plan = planReminders(now, zone);
    final pending = (await _scheduler.pendingIds()).where(isReminderId).toSet();
    final desired = plan.map((item) => item.id).toSet();
    for (final id in pending.difference(desired)) {
      await _scheduler.cancel(id);
    }
    final signature =
        '${zone.name}:${plan.map((item) => '${item.id}:${item.when.millisecondsSinceEpoch}').join(',')}';
    if (_signature != signature || !pending.containsAll(desired)) {
      for (final item in plan) {
        await _scheduler.schedule(item);
      }
    }
    _signature = signature;
    return plan.length;
  }

  Future<ReminderState> _refresh() async {
    await _initialize();
    final settings = await ref.read(settingsServiceProvider).read();
    final permission = await _scheduler.permission();
    if (permission != ReminderPermission.granted ||
        !settings.notificationsEnabled) {
      await _cancel();
      if (settings.notificationsEnabled) {
        await ref.read(settingsServiceProvider).setNotificationsEnabled(false);
      }
      return ReminderState(enabled: false, permission: permission);
    }
    return ReminderState(
      enabled: true,
      permission: permission,
      scheduledCount: await _schedule(),
    );
  }

  Future<void> _run(String key, Future<ReminderState> Function() action) {
    final pending = _operation;
    if (pending != null) {
      if (_operationKey == key) return pending;
      // Coalesce duplicate taps, but never drop a different intent (especially opt-out).
      return pending.then((_) => _run(key, action));
    }
    late final Future<void> operation;
    operation = _execute(action).whenComplete(() {
      if (identical(_operation, operation)) {
        _operation = null;
        _operationKey = null;
      }
    });
    _operation = operation;
    _operationKey = key;
    return operation;
  }

  Future<void> _execute(Future<ReminderState> Function() action) async {
    if (state.isLoading) {
      try {
        await future;
      } catch (_) {
        /* A failed initialization can be retried. */
      }
    }
    if (!ref.mounted) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
  }

  Future<void> refresh() => _run('refresh', _refresh);

  Future<void> setEnabled(bool enabled) => _run(
    enabled ? 'enable' : 'disable',
    () async {
      if (!enabled) {
        // Persist opt-out first; reopening will retry cancellation if Android fails.
        await ref.read(settingsServiceProvider).setNotificationsEnabled(false);
        await _cancel();
        return ReminderState(
          enabled: false,
          permission: await _scheduler.permission(),
        );
      }
      await _initialize();
      var permission = await _scheduler.permission();
      if (permission != ReminderPermission.granted) {
        permission = await _scheduler.requestPermission();
      }
      if (permission != ReminderPermission.granted) {
        await ref.read(settingsServiceProvider).setNotificationsEnabled(false);
        await _cancel();
        return ReminderState(
          enabled: false,
          permission: permission,
          notice: 'Android no concedió el permiso. Los recordatorios siguen desactivados; puedes revisar el permiso en Ajustes.',
        );
      }
      try {
        final count = await _schedule();
        await ref.read(settingsServiceProvider).setNotificationsEnabled(true);
        return ReminderState(
          enabled: true,
          permission: permission,
          scheduledCount: count,
        );
      } catch (_) {
        await ref.read(settingsServiceProvider).setNotificationsEnabled(false);
        await _cancel();
        rethrow;
      }
    },
  );

  Future<void> testNotification() => _run('test', () async {
    final current = await _refresh();
    if (!current.enabled) return current;
    await _scheduler.showTest();
    return ReminderState(
      enabled: true,
      permission: current.permission,
      scheduledCount: current.scheduledCount,
      notice: 'Prueba solicitada. Revisa las notificaciones de Android; su entrega depende del sistema.',
    );
  });

  Future<void> openSettings() => _run('settings', () async {
    await _scheduler.openSettings();
    return _refresh();
  });
}
