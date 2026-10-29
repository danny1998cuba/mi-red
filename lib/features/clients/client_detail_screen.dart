import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:forui/forui.dart';

import '../../core/design_system/app_components.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../billing/billing_calendar.dart';
import 'client_providers.dart';
import 'client_values.dart';
import 'data/client_service.dart';
import 'data/device_service.dart';
import 'widgets/client_widgets.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({required this.clientId, super.key});
  final String clientId;
  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  bool _busy = false;
  String get _location => '/clients/${Uri.encodeComponent(widget.clientId)}';

  Future<void> _changeStatus(ClientRecord client) async {
    if (_busy) return;
    setState(() => _busy = true);
    final archived = client.status == 'archived';
    final confirmed = await confirmClientAction(
      context,
      title: archived ? 'Reactivar cliente' : 'Archivar cliente',
      message: archived
          ? 'Volverá a estar activo desde el período vigente, conservando su historial. No se crearán cargos de los períodos inactivos.'
          : 'Se ocultará de Activos y dejará de generar cargos nuevos. Sus datos, cargos y pagos anteriores se conservarán.',
      confirmLabel: archived ? 'Reactivar' : 'Archivar',
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _busy = false);
      return;
    }
    try {
      final now = ref.read(clientClockProvider)();
      await ref
          .read(clientServiceProvider)
          .changeStatus(
            client.id,
            archived ? ServiceStatus.active : ServiceStatus.archived,
            today: LocalDate.fromDateTime(now),
            recordedAt: now,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              archived ? 'Cliente reactivado.' : 'Cliente archivado.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cambiar el estado. Vuelve a intentarlo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeDevice(DeviceRecord device) async {
    if (_busy) return;
    setState(() => _busy = true);
    final confirmed = await confirmClientAction(
      context,
      title: 'Eliminar dispositivo',
      message: 'Se eliminará únicamente este dispositivo. El cliente, sus cargos y pagos se conservarán.',
      confirmLabel: 'Eliminar',
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _busy = false);
      return;
    }
    try {
      await ref
          .read(deviceServiceProvider)
          .remove(device.id, allowArchived: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dispositivo eliminado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo eliminar el dispositivo. Vuelve a intentarlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageHeader(
      context,
      'Ficha de cliente',
      leading: IconButton(
        tooltip: 'Atrás',
        icon: const Icon(FLucideIcons.arrowLeft),
        onPressed: () => backToClients(context),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ref
            .watch(clientProvider(widget.clientId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ClientNotice(
                title: 'No se pudo cargar el cliente',
                onAction: () => ref.invalidate(clientProvider(widget.clientId)),
              ),
              data: (client) => client == null
                  ? ClientNotice(
                      title: 'Cliente no encontrado',
                      message: 'Este cliente ya no está disponible.',
                      actionLabel: 'Volver a Clientes',
                      onAction: () => context.go('/clients'),
                    )
                  : _content(client),
            ),
      ),
    ),
  );

  Widget _content(ClientRecord client) {
    final archived = client.status == 'archived';
    final currency = ref.watch(currencyLabelProvider).asData?.value ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  client.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ServiceStatusBadge(client.status),
                ),
                const SizedBox(height: 12),
                Text(
                  '${formatMoneyMinor(client.monthlyFeeMinor, currencyLabel: currency)} al mes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (archived)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Reactiva este cliente para editar sus datos o dispositivos.',
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('client-billing'),
              onPressed: _busy
                  ? null
                  : () => context.push(
                      '/billing/clients/${Uri.encodeComponent(client.id)}',
                    ),
              icon: const Icon(FLucideIcons.receiptText),
              label: const Text('Cobros e historial'),
            ),
            if (!archived)
              OutlinedButton.icon(
                key: const Key('edit-client'),
                onPressed: _busy ? null : () => context.push('$_location/edit'),
                icon: const Icon(FLucideIcons.pencil),
                label: const Text('Editar cliente'),
              ),
            OutlinedButton.icon(
              key: const Key('archive-client'),
              onPressed: _busy ? null : () => _changeStatus(client),
              icon: Icon(
                archived ? FLucideIcons.archiveRestore : FLucideIcons.archive,
              ),
              label: Text(archived ? 'Reactivar cliente' : 'Archivar cliente'),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        for (final field in [
          ('Teléfono', client.phone),
          ('Dirección', client.address),
          ('Notas', client.notes),
        ])
          if (field.$2?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    field.$1,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(field.$2!),
                ],
              ),
            ),
        const SizedBox(height: 16),
        const AppSection('Dispositivos'),
        const SizedBox(height: 12),
        if (!archived)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              key: const Key('add-device'),
              onPressed: _busy
                  ? null
                  : () => context.push('$_location/devices/new'),
              child: const Text('Añadir dispositivo'),
            ),
          ),
        const SizedBox(height: 12),
        ref
            .watch(devicesProvider(client.id))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ClientNotice(
                title: 'No se pudieron cargar los dispositivos',
                onAction: () => ref.invalidate(devicesProvider(client.id)),
              ),
              data: (devices) => devices.isEmpty
                  ? const ClientNotice(title: 'Todavía no hay dispositivos')
                  : Column(
                      children: [
                        for (final device in devices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      deviceTypeLabel(
                                        DeviceType.values.byName(device.type),
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: SelectableText(
                                        device.macAddress ??
                                            'Sin MAC registrada',
                                      ),
                                    ),
                                    if (device.ipAddress != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: AppCopyableValue(
                                          value: device.ipAddress!,
                                          label: 'dirección IP',
                                          copyKey: ValueKey(
                                            'copy-ip-${device.id}',
                                          ),
                                        ),
                                      ),
                                    if (device.notes?.isNotEmpty ?? false)
                                      Text(device.notes!),
                                    if (!archived)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          TextButton.icon(
                                            key: ValueKey(
                                              'edit-device-${device.id}',
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () => context.push(
                                                    '$_location/devices/${Uri.encodeComponent(device.id)}/edit',
                                                  ),
                                            icon: const Icon(
                                              FLucideIcons.pencil,
                                            ),
                                            label: const Text('Editar'),
                                          ),
                                          TextButton.icon(
                                            key: ValueKey(
                                              'delete-device-${device.id}',
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () => _removeDevice(device),
                                            icon: const Icon(
                                              FLucideIcons.trash2,
                                            ),
                                            label: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
        const SizedBox(height: 16),
      ],
    );
  }
}
