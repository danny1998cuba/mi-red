import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:forui/forui.dart';

import '../../core/design_system/app_components.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/record_id.dart';
import '../billing/billing_calendar.dart';
import 'client_providers.dart';
import 'client_values.dart';
import 'data/client_service.dart';
import 'widgets/client_widgets.dart';

class ClientFormScreen extends ConsumerWidget {
  const ClientFormScreen({this.clientId, super.key});
  final String? clientId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (clientId == null) return const _ClientEditor();
    return ref
        .watch(clientProvider(clientId!))
        .when(
          loading: () => Scaffold(
            appBar: AppPageHeader(context, 'Editar cliente'),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            appBar: AppPageHeader(context, 'Editar cliente'),
            body: SingleChildScrollView(
              child: ClientNotice(
                title: 'No se pudo cargar el cliente',
                onAction: () => ref.invalidate(clientProvider(clientId!)),
              ),
            ),
          ),
          data: (client) {
            if (client == null || client.status == 'archived') {
              return Scaffold(
                appBar: AppPageHeader(
                  context,
                  'Editar cliente',
                  leading: IconButton(
                    tooltip: 'Atrás',
                    icon: const Icon(FLucideIcons.arrowLeft),
                    onPressed: () => backToClients(context),
                  ),
                ),
                body: SingleChildScrollView(
                  child: ClientNotice(
                    title: client == null
                        ? 'Cliente no encontrado'
                        : 'Cliente archivado',
                    message: client == null
                        ? 'El cliente ya no está disponible.'
                        : 'Reactiva el cliente desde su ficha antes de editarlo.',
                    actionLabel: 'Volver a Clientes',
                    onAction: () => context.go('/clients'),
                  ),
                ),
              );
            }
            return _ClientEditor(key: ValueKey(client.id), client: client);
          },
        );
  }
}

class _ClientEditor extends ConsumerStatefulWidget {
  const _ClientEditor({this.client, super.key});
  final ClientRecord? client;
  @override
  ConsumerState<_ClientEditor> createState() => _ClientEditorState();
}

class _ClientEditorState extends ConsumerState<_ClientEditor> {
  final _form = GlobalKey<FormState>();
  late final ClientRecord? _initial = widget.client;
  late final String _id = _initial?.id ?? newRecordId();
  late final _name = TextEditingController(text: _initial?.fullName ?? '');
  late final _phone = TextEditingController(text: _initial?.phone ?? '');
  late final _address = TextEditingController(text: _initial?.address ?? '');
  late final _fee = TextEditingController(
    text: _initial == null ? '' : formatMoneyMinor(_initial.monthlyFeeMinor),
  );
  late final _notes = TextEditingController(text: _initial?.notes ?? '');
  late ServiceStatus _status = _initial?.status == 'suspended'
      ? ServiceStatus.suspended
      : ServiceStatus.active;
  bool _saving = false;
  bool _saved = false;
  String? _error;
  bool get _dirty =>
      !_saved &&
      (_name.text != (_initial?.fullName ?? '') ||
          _phone.text != (_initial?.phone ?? '') ||
          _address.text != (_initial?.address ?? '') ||
          _fee.text !=
              (_initial == null
                  ? ''
                  : formatMoneyMinor(_initial.monthlyFeeMinor)) ||
          _notes.text != (_initial?.notes ?? '') ||
          _status.name != (_initial?.status ?? 'active'));

  @override
  void dispose() {
    for (final controller in [_name, _phone, _address, _fee, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = await validateAppForm(_form);
    if (!mounted || _saving || !valid) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    if (_initial != null && _status.name != _initial.status) {
      final confirmed = await confirmClientAction(
        context,
        title: 'Cambiar estado del servicio',
        message:
            'El servicio quedará ${serviceStatusLabel(_status.name).toLowerCase()}. Es una decisión manual y no depende del estado de pago.',
        confirmLabel: 'Cambiar estado',
      );
      if (!mounted) return;
      if (!confirmed) {
        setState(() => _saving = false);
        return;
      }
    }
    try {
      final service = ref.read(clientServiceProvider);
      final now = ref.read(clientClockProvider)();
      final fee = parseMoneyMinor(_fee.text);
      if (_initial == null) {
        await service.create(
          id: _id,
          fullName: _name.text.trim(),
          monthlyFeeMinor: fee,
          phone: optionalText(_phone.text),
          address: optionalText(_address.text),
          notes: optionalText(_notes.text),
          status: _status,
          today: LocalDate.fromDateTime(now),
          recordedAt: now,
        );
      } else {
        await service.updateProfile(
          _id,
          fullName: _name.text.trim(),
          monthlyFeeMinor: fee,
          phone: optionalText(_phone.text),
          address: optionalText(_address.text),
          notes: optionalText(_notes.text),
          status: _status,
          today: LocalDate.fromDateTime(now),
          recordedAt: now,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar el cliente. Tus cambios siguen aquí; vuelve a intentarlo.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _saved = true;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _initial == null ? 'Cliente añadido.' : 'Cliente actualizado.',
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (_initial == null) {
      context.replace('/clients/${Uri.encodeComponent(_id)}');
    } else {
      backToClients(context, '/clients/${Uri.encodeComponent(_id)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyLabelProvider).asData?.value ?? '';
    return GuardedFormPage(
      title: _initial == null ? 'Añadir cliente' : 'Editar cliente',
      hasChanges: _dirty,
      isSaving: _saving,
      fallback: _initial == null
          ? '/clients'
          : '/clients/${Uri.encodeComponent(_id)}',
      child: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSection('Datos básicos'),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('client-name'),
                controller: _name,
                enabled: !_saving,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: validateClientName,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo *',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('client-phone'),
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                validator: validatePhone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('client-address'),
                controller: _address,
                enabled: !_saving,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.streetAddress,
                autofillHints: const [AutofillHints.fullStreetAddress],
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Dirección (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              const AppSection('Servicio'),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('client-fee'),
                controller: _fee,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: validateMonthlyFee,
                decoration: InputDecoration(
                  labelText: currency.isEmpty
                      ? 'Mensualidad *'
                      : 'Mensualidad ($currency) *',
                  helperText: 'Hasta 2 decimales, con coma o punto. Sin separadores de miles.',
                  helperMaxLines: 4,
                ),
              ),
              if (_initial != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'La tarifa se aplicará a los cargos que se generen después. El historial se conserva.',
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ServiceStatus>(
                key: const Key('client-status'),
                initialValue: _status,
                isExpanded: true,
                icon: const Icon(FLucideIcons.chevronDown, size: 18),
                decoration: const InputDecoration(
                  labelText: 'Estado del servicio',
                ),
                items: [
                  for (final value in [
                    ServiceStatus.active,
                    ServiceStatus.suspended,
                  ])
                    DropdownMenuItem(
                      value: value,
                      child: Text(serviceStatusLabel(value.name)),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _status = value!),
              ),
              const SizedBox(height: 12),
              const AppSection('Notas'),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('client-notes'),
                controller: _notes,
                enabled: !_saving,
                minLines: 2,
                maxLines: 6,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(liveRegion: true, child: Text(_error!)),
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('client-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      )
                    : const Text(
                        'Guardar cliente',
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
