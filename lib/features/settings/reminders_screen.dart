import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../core/design_system/app_components.dart';
import '../../core/design_system/app_design.dart';
import '../reminders/reminder_providers.dart';
import '../reminders/reminder_scheduler.dart';
import 'settings_page.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(remindersProvider.notifier).refresh());
    });
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Recordatorios',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ref
            .watch(remindersProvider)
            .when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Actualizando recordatorios',
                  ),
                ),
              ),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppEmptyState(
                    title: 'No se pudieron preparar los recordatorios',
                    message: 'La gestión de clientes y cobros sigue disponible. Puedes reintentar o desactivar los avisos.',
                    onAction: () =>
                        ref.read(remindersProvider.notifier).refresh(),
                  ),
                  TextButton(
                    key: const Key('reminders-disable'),
                    onPressed: () =>
                        ref.read(remindersProvider.notifier).setEnabled(false),
                    child: const Text('Desactivar recordatorios'),
                  ),
                ],
              ),
              data: (data) => _settings(data),
            ),
      ],
    ),
  );

  Widget _settings(ReminderState data) => FCard(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              key: const Key('reminders-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Activar recordatorios'),
              value: data.enabled,
              onChanged: data.permission == ReminderPermission.unsupported
                  ? null
                  : (enabled) => ref
                        .read(remindersProvider.notifier)
                        .setEnabled(enabled),
            ),
          ),
          const Text(
            'Día 2: revisar cobros pendientes. Día 3: revisar posibles suspensiones. A las 09:00, hora local aproximada.',
          ),
          const SizedBox(height: 12),
          Text(switch (data.permission) {
            ReminderPermission.granted => 'Permiso de Android: concedido.',
            ReminderPermission.denied => 'Permiso de Android: sin permiso. Se solicitará al activar los avisos.',
            ReminderPermission.unsupported =>
              'Recordatorios disponibles únicamente en Android.',
          }, key: const Key('reminders-permission-state')),
          if (data.enabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Próximos avisos preparados: ${data.scheduledCount}. Se renuevan al abrir o reanudar Mi Red.',
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Android o el ahorro de batería pueden retrasarlos. Estos avisos no crean cargos ni cambian el servicio; los datos se actualizan al abrir la app.',
          ),
          if (data.notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(liveRegion: true, child: Text(data.notice!)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                key: const Key('reminders-permission'),
                onPressed: data.permission == ReminderPermission.unsupported
                    ? null
                    : () => ref.read(remindersProvider.notifier).openSettings(),
                icon: const Icon(FLucideIcons.settings, size: 18),
                label: const Text('Revisar permiso en Android'),
              ),
              OutlinedButton.icon(
                key: const Key('reminders-test'),
                onPressed:
                    data.enabled &&
                        data.permission == ReminderPermission.granted
                    ? () => ref
                          .read(remindersProvider.notifier)
                          .testNotification()
                    : null,
                icon: const Icon(FLucideIcons.bell, size: 18),
                label: const Text('Probar notificación'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
