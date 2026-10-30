import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/core/database/app_database.dart';
import 'package:mi_red/features/backups/backup_service.dart';
import 'package:mi_red/features/settings/appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../backups/backup_fixture.dart';
import 'fake_appearance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAppearanceRepository repository;
  late FakeNativeAppearance native;
  late ProviderContainer container;
  setUp(() {
    repository = FakeAppearanceRepository();
    native = FakeNativeAppearance();
    container = ProviderContainer(
      overrides: [
        appearanceRepositoryProvider.overrideWithValue(repository),
        nativeAppearanceProvider.overrideWithValue(native),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('real async repository survives recreation and handles missing/unknown values', () async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    expect(await DeviceAppearanceRepository().read(), ThemeMode.system);
    for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
      await DeviceAppearanceRepository().write(mode);
      expect(await DeviceAppearanceRepository().read(), mode);
    }
    expect(
      await SharedPreferencesAsync().getString(DeviceAppearanceRepository.key),
      isNull,
    );
    await SharedPreferencesAsync().setString(
      DeviceAppearanceRepository.key,
      'future-value',
    );
    expect(await DeviceAppearanceRepository().read(), ThemeMode.system);
  });

  test(
    'startup read failure falls back to automatic and a real retry succeeds',
    () async {
      repository.failRead = true;
      final initial = await loadAppearance(repository);
      expect(initial.mode, ThemeMode.system);
      expect(initial.notice, contains('No se pudo leer'));
      final retryContainer = ProviderContainer(
        overrides: [
          initialAppearanceProvider.overrideWithValue(initial),
          appearanceRepositoryProvider.overrideWithValue(repository),
          nativeAppearanceProvider.overrideWithValue(native),
        ],
      );
      addTearDown(retryContainer.dispose);
      repository.failRead = false;
      repository.mode = ThemeMode.dark;
      await retryContainer.read(appearanceProvider.notifier).reload();
      expect(retryContainer.read(appearanceProvider).mode, ThemeMode.dark);
      expect(retryContainer.read(appearanceProvider).notice, isNull);
    },
  );

  testWidgets(
    'a hung startup read is bounded to 500ms and late completion is ignored',
    (tester) async {
      final pending = Completer<ThemeMode>();
      AppearanceState? result;
      loadAppearance(_PendingAppearance(pending.future))
          .then((value) => result = value);
      await tester.pump(const Duration(milliseconds: 499));
      expect(result, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(result!.mode, ThemeMode.system);
      expect(result!.notice, isNotNull);
      pending.complete(ThemeMode.dark);
      await tester.pump();
      expect(result!.mode, ThemeMode.system);
    },
  );

  test('selection is immediate, ignores overlapping writes and survives a new provider scope', () async {
    repository.writeGate = Completer<void>();
    final saving = container
        .read(appearanceProvider.notifier)
        .select(ThemeMode.dark);
    expect(container.read(appearanceProvider).mode, ThemeMode.dark);
    expect(container.read(appearanceProvider).saving, isTrue);
    await container.read(appearanceProvider.notifier).select(ThemeMode.light);
    expect(repository.writes, 1);
    repository.writeGate!.complete();
    await saving;
    final restarted = ProviderContainer(
      overrides: [
        initialAppearanceProvider.overrideWithValue(
          await loadAppearance(repository),
        ),
      ],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(appearanceProvider).mode, ThemeMode.dark);
    expect(native.modes, [ThemeMode.dark]);
  });

  test(
    'write failure uses automatic now, reports it, and allows a new selection',
    () async {
      repository.failWrite = true;
      await container.read(appearanceProvider.notifier).select(ThemeMode.light);
      expect(container.read(appearanceProvider).mode, ThemeMode.system);
      expect(container.read(appearanceProvider).saving, isFalse);
      expect(
        container.read(appearanceProvider).notice,
        contains('No se pudo guardar'),
      );
      expect(native.modes, [ThemeMode.system]);
      repository.failWrite = false;
      await container.read(appearanceProvider.notifier).select(ThemeMode.dark);
      expect(repository.mode, ThemeMode.dark);
      expect(container.read(appearanceProvider).notice, isNull);
    },
  );

  test('native failure preserves a successful preference and reports the splash limitation', () async {
    native.fail = true;
    await container.read(appearanceProvider.notifier).select(ThemeMode.light);
    expect(repository.mode, ThemeMode.light);
    expect(container.read(appearanceProvider).mode, ThemeMode.light);
    expect(
      container.read(appearanceProvider).notice,
      contains('Android no confirmó'),
    );
  });

  test('T07 restore preserves local appearance and all five snapshot tables exactly', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final service = BackupService(db);
    final original = syntheticBackup();
    await service.restore(original);
    await container.read(appearanceProvider.notifier).select(ThemeMode.dark);
    expect((await service.capture(backupTestDate)).records, original.records);
    final replacement = syntheticBackup(notifications: false);
    await service.restore(replacement);
    expect(
      (await service.capture(backupTestDate)).records,
      replacement.records,
    );
    expect(container.read(appearanceProvider).mode, ThemeMode.dark);
    expect(await repository.read(), ThemeMode.dark);
    expect(
      replacement.records.keys,
      unorderedEquals([
        'clients',
        'devices',
        'charges',
        'payments',
        'app_settings',
      ]),
    );
    expect(
      replacement.toJson().toString(),
      isNot(contains(DeviceAppearanceRepository.key)),
    );
    final freshDevice = FakeAppearanceRepository();
    expect((await loadAppearance(freshDevice)).mode, ThemeMode.system);
  });
}

class _PendingAppearance implements AppearanceRepository {
  _PendingAppearance(this.pending);
  final Future<ThemeMode> pending;
  @override
  Future<ThemeMode> read() => pending;
  @override
  Future<void> write(ThemeMode mode) async {}
}
