import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/settings/appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initial = await loadAppearance(DeviceAppearanceRepository());
  try {
    await AndroidAppearance().apply(initial.mode);
  } catch (_) {
    /* Appearance cannot prevent startup. */
  }
  runApp(
    ProviderScope(
      overrides: [initialAppearanceProvider.overrideWithValue(initial)],
      child: const MiRedApp(),
    ),
  );
}
