import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/design_system/app_components.dart';
import '../../../core/design_system/app_design.dart';
import '../../clients/client_providers.dart';
import '../../clients/client_values.dart';
import '../billing_calendar.dart';
import '../billing_providers.dart';
import '../billing_values.dart';

class ChargeCorrectionAction extends ConsumerStatefulWidget {
  const ChargeCorrectionAction({
    required this.charge,
    required this.clientName,
    required this.currencyLabel,
    super.key,
  });
  final ChargeRecord charge;
  final String clientName, currencyLabel;

  @override
  ConsumerState<ChargeCorrectionAction> createState() =>
      _ChargeCorrectionActionState();
}

class _ChargeCorrectionActionState
    extends ConsumerState<ChargeCorrectionAction> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _opening = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CorrectionDialog(
          charge: widget.charge,
          clientName: widget.clientName,
          currencyLabel: widget.currencyLabel,
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(billingSessionProvider).asData?.value;
    if (today == null || widget.charge.periodKey != currentPeriod(today).key) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      key: ValueKey('correct-${widget.charge.id}'),
      onPressed: _opening ? null : _open,
      icon: const Icon(FLucideIcons.pencil, size: 18),
      label: const Text('Corregir importe'),
    );
  }
}

class _CorrectionDialog extends ConsumerStatefulWidget {
  const _CorrectionDialog({
    required this.charge,
    required this.clientName,
    required this.currencyLabel,
  });
  final ChargeRecord charge;
  final String clientName, currencyLabel;
  @override
  ConsumerState<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends ConsumerState<_CorrectionDialog> {
  final _form = GlobalKey<FormState>();
  final _feedback = GlobalKey();
  late final _amount = TextEditingController(
    text: formatMoneyMinor(widget.charge.amountMinor),
  );
  bool _saving = false;
  int? _proposed;
  String? _error;
  String _money(int value) =>
      formatMoneyMinor(value, currencyLabel: widget.currencyLabel);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    if (_saving) return;
    final valid = await validateAppForm(_form);
    if (!mounted || _saving || !valid) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _proposed = parseMoneyMinor(_amount.text);
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _proposed == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(billingServiceProvider)
          .correctChargeAmount(
            chargeId: widget.charge.id,
            expectedAmountMinor: widget.charge.amountMinor,
            amountMinor: _proposed!,
            today: LocalDate.fromDateTime(ref.read(clientClockProvider)()),
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is StateError ? error.message.toString() : 'No se pudo corregir el importe. No se guardó el cambio; puedes reintentar.';
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _feedback.currentContext != null) {
        await Scrollable.ensureVisible(_feedback.currentContext!, alignment: 1);
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Importe corregido. La tarifa y los pagos históricos se conservaron.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        _proposed == null ? 'Corregir importe' : 'Confirmar corrección',
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.clientName),
            const SizedBox(height: 8),
            Text(periodLabel(BillingPeriod.parse(widget.charge.periodKey))),
            const SizedBox(height: 12),
            Text('Importe actual: ${_money(widget.charge.amountMinor)}'),
            const SizedBox(height: 12),
            if (_proposed == null)
              TextFormField(
                key: const Key('correction-amount'),
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  final invalid = validateMonthlyFee(value);
                  if (invalid != null) return invalid;
                  return parseMoneyMinor(value!) == widget.charge.amountMinor
                      ? 'Introduce un importe distinto del actual.'
                      : null;
                },
                decoration: const InputDecoration(labelText: 'Nuevo importe'),
              )
            else
              Text(
                'Nuevo importe: ${_money(_proposed!)}',
                key: const Key('correction-preview'),
              ),
            const SizedBox(height: 12),
            const Text(
              'Solo cambia esta mensualidad vigente sin pago activo. La tarifa del cliente y los pagos anulados conservan sus valores. No cambia el servicio ni liquida otras deudas.',
            ),
            if (_proposed != null) ...[
              const SizedBox(height: 8),
              const Text(
                'No se guarda un historial de correcciones del importe.',
              ),
            ],
            if (_error != null)
              Padding(
                key: _feedback,
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppPalette.of(context).danger),
                  ),
                ),
              ),
            if (_saving) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const Key('correction-cancel'),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                if (_proposed != null)
                  TextButton(
                    key: const Key('correction-edit'),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _proposed = null;
                            _error = null;
                          }),
                    child: const Text('Editar importe'),
                  ),
                FilledButton(
                  key: Key(
                    _proposed == null
                        ? 'correction-review'
                        : 'correction-confirm',
                  ),
                  onPressed: _saving
                      ? null
                      : _proposed == null
                      ? _review
                      : _save,
                  child: Text(
                    _proposed == null
                        ? 'Revisar cambio'
                        : 'Confirmar corrección',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
