import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mi_red/features/settings/appearance.dart';

class FakeAppearanceRepository implements AppearanceRepository {
  ThemeMode mode = ThemeMode.system;
  bool failRead = false, failWrite = false;
  Completer<void>? writeGate;
  int writes = 0;
  @override
  Future<ThemeMode> read() async {
    if (failRead) throw StateError('Synthetic read failure');
    return mode;
  }

  @override
  Future<void> write(ThemeMode value) async {
    writes++;
    if (writeGate != null) await writeGate!.future;
    if (failWrite) throw StateError('Synthetic write failure');
    mode = value;
  }
}

class FakeNativeAppearance implements NativeAppearance {
  final modes = <ThemeMode>[];
  bool fail = false;
  @override
  Future<void> apply(ThemeMode mode) async {
    modes.add(mode);
    if (fail) throw StateError('Synthetic native failure');
  }
}
