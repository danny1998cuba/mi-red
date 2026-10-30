import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../core/design_system/app_components.dart';
import '../clients/widgets/client_widgets.dart';
import 'business_values.dart';

final businessSettingsProvider = StreamProvider.autoDispose<SettingsRecord>(
  (ref) => ref.watch(settingsServiceProvider).watch(),
  retry: (count, error) => null,
);

class BusinessSettingsScreen extends ConsumerWidget {
  const BusinessSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(businessSettingsProvider)
      .when(
        loading: () => Scaffold(
          appBar: AppPageHeader(context, 'Mi negocio'),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Scaffold(
          appBar: AppPageHeader(context, 'Mi negocio'),
          body: SingleChildScrollView(
            child: AppEmptyState(
              title: 'No se pudo cargar el negocio',
              onAction: () => ref.invalidate(businessSettingsProvider),
            ),
          ),
        ),
        data: (settings) => _BusinessEditor(settings: settings),
      );
}

class _BusinessEditor extends ConsumerStatefulWidget {
  const _BusinessEditor({required this.settings});
  final SettingsRecord settings;

  @override
  ConsumerState<_BusinessEditor> createState() => _BusinessEditorState();
}

class _BusinessEditorState extends ConsumerState<_BusinessEditor> {
  final _form = GlobalKey<FormState>();
  final _feedback = GlobalKey();
  late final _name = TextEditingController(text: widget.settings.businessName);
  late final _currency = TextEditingController(
    text: widget.settings.currencyLabel,
  );
  late final _prefix = TextEditingController(
    text: widget.settings.defaultCallingCode ?? '',
  );
  bool _saving = false;
  String? _notice;

  @override
  void dispose() {
    for (final controller in [_name, _currency, _prefix]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = await validateAppForm(_form);
    if (!mounted || _saving || !valid) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      await ref
          .read(settingsServiceProvider)
          .update(
            businessName: _name.text,
            currencyLabel: _currency.text,
            defaultCallingCode: _prefix.text,
          );
      if (mounted) {
        setState(
          () => _notice = 'Cambios guardados. La moneda solo cambia el rótulo de los importes.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'No se pudo guardar. Tus cambios siguen aquí; vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && _feedback.currentContext != null) {
          await Scrollable.ensureVisible(
            _feedback.currentContext!,
            alignment: 1,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppPageHeader(
        context,
        'Mi negocio',
        leading: IconButton(
          tooltip: 'Atrás',
          icon: const Icon(FLucideIcons.arrowLeft),
          onPressed: _saving ? null : () => backToClients(context, '/settings'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          onChanged: () {
            if (_notice != null) setState(() => _notice = null);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppSection('Datos del negocio'),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('business-name'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: maxBusinessNameLength,
                  validator: validateBusinessName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del negocio',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('business-currency'),
                  controller: _currency,
                  enabled: !_saving,
                  maxLength: maxCurrencyLabelLength,
                  validator: validateCurrencyLabel,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta de moneda',
                  ),
                ),
                const Text(
                  'Símbolo o etiqueta, sin conversión. Vacío muestra solo el número; no cambia importes ni precisión.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('business-prefix'),
                  controller: _prefix,
                  enabled: !_saving,
                  maxLength: 4,
                  validator: validateCallingCode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Prefijo (opcional)',
                  ),
                ),
                const Text(
                  'Ejemplo: +53. Preferencia informativa; WhatsApp sigue exigiendo revisar un número internacional completo. No se añade a teléfonos locales.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('business-save'),
                  onPressed: _saving ? null : _save,
                  child: const Text(
                    'Guardar cambios',
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_saving) const LinearProgressIndicator(),
                if (_notice != null)
                  Padding(
                    key: _feedback,
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(liveRegion: true, child: Text(_notice!)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
