import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/record_id.dart';
import 'client_providers.dart';
import 'client_values.dart';
import 'data/device_service.dart';
import 'widgets/client_widgets.dart';

class DeviceFormScreen extends ConsumerWidget {
  const DeviceFormScreen({required this.clientId, this.deviceId, super.key});
  final String clientId;
  final String? deviceId;

  Widget _notice(BuildContext context, String title, {VoidCallback? retry}) =>
      Scaffold(
        appBar: AppBar(
          title: const Text('Dispositivo'),
          leading: BackButton(
            onPressed: () => backToClients(
              context,
              '/clients/${Uri.encodeComponent(clientId)}',
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: ClientNotice(title: title, onAction: retry),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(clientProvider(clientId))
      .when(
        loading: () => _notice(context, 'Cargando cliente…'),
        error: (error, stack) => _notice(
          context,
          'No se pudo cargar el cliente',
          retry: () => ref.invalidate(clientProvider(clientId)),
        ),
        data: (client) {
          if (client == null) return _notice(context, 'Cliente no encontrado');
          if (client.status == 'archived') {
            return _notice(
              context,
              'Reactiva el cliente antes de editar sus dispositivos.',
            );
          }
          if (deviceId == null) return _DeviceEditor(clientId: clientId);
          return ref
              .watch(devicesProvider(clientId))
              .when(
                loading: () => _notice(context, 'Cargando dispositivo…'),
                error: (error, stack) => _notice(
                  context,
                  'No se pudo cargar el dispositivo',
                  retry: () => ref.invalidate(devicesProvider(clientId)),
                ),
                data: (devices) {
                  final matching = devices.where((row) => row.id == deviceId);
                  return matching.isEmpty
                      ? _notice(context, 'Dispositivo no encontrado')
                      : _DeviceEditor(
                          key: ValueKey(deviceId),
                          clientId: clientId,
                          device: matching.single,
                        );
                },
              );
        },
      );
}

class _DeviceEditor extends ConsumerStatefulWidget {
  const _DeviceEditor({required this.clientId, this.device, super.key});
  final String clientId;
  final DeviceRecord? device;
  @override
  ConsumerState<_DeviceEditor> createState() => _DeviceEditorState();
}

class _DeviceEditorState extends ConsumerState<_DeviceEditor> {
  final _form = GlobalKey<FormState>();
  late final DeviceRecord? _initial = widget.device;
  late final _id = _initial?.id ?? newRecordId();
  late DeviceType _type = _initial == null
      ? DeviceType.antenna
      : DeviceType.values.byName(_initial.type);
  late final _mac = TextEditingController(text: _initial?.macAddress ?? '');
  late final _ip = TextEditingController(text: _initial?.ipAddress ?? '');
  late final _notes = TextEditingController(text: _initial?.notes ?? '');
  bool _saving = false;
  bool _saved = false;
  String? _error;
  String get _fallback => '/clients/${Uri.encodeComponent(widget.clientId)}';
  bool get _dirty =>
      !_saved &&
      (_mac.text != (_initial?.macAddress ?? '') ||
          _ip.text != (_initial?.ipAddress ?? '') ||
          _notes.text != (_initial?.notes ?? '') ||
          _type.name != (_initial?.type ?? 'antenna'));
  @override
  void dispose() {
    _mac.dispose();
    _ip.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(deviceServiceProvider);
      final duplicate = await service.hasDuplicateMac(
        _mac.text,
        excludingId: _id,
      );
      if (!mounted) return;
      if (duplicate || _initial != null) {
        final confirmed = await confirmClientAction(
          context,
          title: duplicate
              ? 'MAC ya registrada'
              : 'Guardar cambios del dispositivo',
          message: duplicate
              ? 'Esta MAC ya está asociada a otro dispositivo. Puedes revisar el dato o guardar de todos modos.'
              : 'Se actualizarán el tipo, la MAC, la IP y las notas de este dispositivo.',
          confirmLabel: duplicate
              ? 'Guardar de todos modos'
              : 'Guardar cambios',
          cancelLabel: duplicate ? 'Revisar' : 'Cancelar',
        );
        if (!mounted) return;
        if (!confirmed) {
          setState(() => _saving = false);
          return;
        }
      }
      await service.save(
        id: _id,
        clientId: widget.clientId,
        type: _type,
        macAddress: _mac.text,
        ipAddress: Value(_ip.text),
        notes: optionalText(_notes.text),
        allowArchived: false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar el dispositivo. Tus cambios siguen aquí; vuelve a intentarlo.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _initial == null
              ? 'Dispositivo añadido.'
              : 'Dispositivo actualizado.',
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) backToClients(context, _fallback);
  }

  @override
  Widget build(BuildContext context) => GuardedFormPage(
    title: _initial == null ? 'Añadir dispositivo' : 'Editar dispositivo',
    hasChanges: _dirty,
    isSaving: _saving,
    fallback: _fallback,
    child: Form(
      key: _form,
      onChanged: () => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<DeviceType>(
            key: const Key('device-type'),
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de dispositivo',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final type in DeviceType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(deviceTypeLabel(type)),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _type = value!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('device-mac'),
            controller: _mac,
            enabled: !_saving,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              try {
                normalizeMacAddress(value);
                return null;
              } on ArgumentError {
                return 'Introduce una MAC válida de 12 caracteres hexadecimales.';
              }
            },
            decoration: const InputDecoration(
              labelText: 'MAC (opcional)',
              hintText: 'AA:BB:CC:DD:EE:FF',
              helperText: 'Puedes usar dos puntos, guiones o escribirla sin separadores.',
              helperMaxLines: 4,
              errorMaxLines: 4,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('device-ip'),
            controller: _ip,
            enabled: !_saving,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            validator: (value) {
              try {
                normalizeIpAddress(value);
                return null;
              } on ArgumentError {
                return 'Introduce una dirección IPv4 o IPv6 válida, sin puerto ni prefijo de red.';
              }
            },
            decoration: const InputDecoration(
              labelText: 'Dirección IP (opcional)',
              helperText: 'Ej.: 192.168.1.20 o fe80::1',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('device-notes'),
            controller: _notes,
            enabled: !_saving,
            minLines: 2,
            maxLines: 6,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Semantics(liveRegion: true, child: Text(_error!)),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('device-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                : const Text(
                    'Guardar dispositivo',
                    textAlign: TextAlign.center,
                  ),
          ),
        ],
      ),
    ),
  );
}
