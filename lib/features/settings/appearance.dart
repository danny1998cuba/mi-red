import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AppearanceRepository {
  Future<ThemeMode> read();
  Future<void> write(ThemeMode mode);
}

class DeviceAppearanceRepository implements AppearanceRepository {
  DeviceAppearanceRepository() : _preferences = SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  static const key = 'mi_red.appearance_mode';
  @override
  Future<ThemeMode> read() async => switch (await _preferences.getString(key)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  @override
  Future<void> write(ThemeMode mode) => mode == ThemeMode.system
      ? _preferences.remove(key)
      : _preferences.setString(key, mode.name);
}

class AppearanceState {
  const AppearanceState({
    this.mode = ThemeMode.system,
    this.saving = false,
    this.notice,
  });
  final ThemeMode mode;
  final bool saving;
  final String? notice;
}

Future<AppearanceState> loadAppearance(AppearanceRepository repository) async {
  try {
    return AppearanceState(
      mode: await repository.read().timeout(const Duration(milliseconds: 500)),
    );
  } catch (_) {
    return const AppearanceState(
      notice: 'No se pudo leer la apariencia. Se usa Automático; puedes reintentar.',
    );
  }
}

abstract class NativeAppearance {
  Future<void> apply(ThemeMode mode);
}

class AndroidAppearance implements NativeAppearance {
  static const _channel = MethodChannel('com.mired.offline/appearance');
  @override
  Future<void> apply(ThemeMode mode) async {
    if (Platform.isAndroid) {
      await _channel
          .invokeMethod<void>('apply', mode.name)
          .timeout(const Duration(milliseconds: 300));
    }
  }
}

final appearanceRepositoryProvider = Provider<AppearanceRepository>(
  (ref) => DeviceAppearanceRepository(),
);
final nativeAppearanceProvider = Provider<NativeAppearance>(
  (ref) => AndroidAppearance(),
);
final initialAppearanceProvider = Provider((ref) => const AppearanceState());
final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );

class AppearanceController extends Notifier<AppearanceState> {
  @override
  AppearanceState build() => ref.read(initialAppearanceProvider);

  Future<void> select(ThemeMode mode) async {
    if (state.saving) return;
    state = AppearanceState(mode: mode, saving: true);
    try {
      await ref
          .read(appearanceRepositoryProvider)
          .write(mode)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      if (!ref.mounted) return;
      state = const AppearanceState(
        notice: 'No se pudo guardar la apariencia. Se usa Automático ahora; vuelve a intentarlo.',
      );
      try {
        await ref.read(nativeAppearanceProvider).apply(ThemeMode.system);
      } catch (_) {
        /* Flutter remains usable. */
      }
      return;
    }
    String? warning;
    try {
      await ref.read(nativeAppearanceProvider).apply(mode);
    } catch (_) {
      warning = 'Apariencia guardada. Android no confirmó el tema del arranque; revisa al abrir de nuevo.';
    }
    if (ref.mounted) state = AppearanceState(mode: mode, notice: warning);
  }

  Future<void> reload() async {
    if (state.saving) return;
    state = AppearanceState(mode: state.mode, saving: true);
    final loaded = await loadAppearance(ref.read(appearanceRepositoryProvider));
    if (!ref.mounted) return;
    state = loaded;
    try {
      await ref.read(nativeAppearanceProvider).apply(loaded.mode);
    } catch (_) {
      /* No startup blocker. */
    }
  }
}

String appearanceLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Automático según el sistema',
  ThemeMode.light => 'Claro',
  ThemeMode.dark => 'Oscuro',
};
