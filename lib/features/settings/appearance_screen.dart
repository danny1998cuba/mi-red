import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import 'appearance.dart';
import 'settings_page.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return SettingsPage(
      title: 'Apariencia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Elige cómo se ve Mi Red en este dispositivo.'),
          const SizedBox(height: 16),
          FCard(
            child: Material(
              color: Colors.transparent,
              child: RadioGroup<ThemeMode>(
                groupValue: appearance.mode,
                onChanged: (mode) {
                  if (mode != null && !appearance.saving) {
                    ref.read(appearanceProvider.notifier).select(mode);
                  }
                },
                child: Column(
                  children: [
                    for (final mode in ThemeMode.values)
                      RadioListTile<ThemeMode>(
                        key: ValueKey('appearance-${mode.name}'),
                        value: mode,
                        enabled: !appearance.saving,
                        title: Text(appearanceLabel(mode)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Esta preferencia pertenece al dispositivo. No forma parte de las copias cifradas de clientes y cobros.',
          ),
          if (appearance.saving) const LinearProgressIndicator(),
          if (appearance.notice != null) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(appearance.notice!)),
            TextButton(
              onPressed: appearance.saving
                  ? null
                  : () => ref.read(appearanceProvider.notifier).reload(),
              child: const Text('Volver a leer preferencia'),
            ),
          ],
        ],
      ),
    );
  }
}
