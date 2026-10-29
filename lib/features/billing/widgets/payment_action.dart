import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/design_system/app_design.dart';
import '../../clients/client_providers.dart';
import '../../clients/client_values.dart';
import '../billing_calendar.dart';
import '../billing_values.dart';

class PaymentAction extends StatefulWidget {
  const PaymentAction({
    required this.charge,
    required this.clientName,
    required this.currencyLabel,
    this.payment,
    super.key,
  });
  final ChargeRecord charge;
  final String clientName, currencyLabel;
  final PaymentRecord? payment;
  @override
  State<PaymentAction> createState() => _PaymentActionState();
}

class _PaymentActionState extends State<PaymentAction> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    FocusScope.of(context).unfocus();
    setState(() => _opening = true);
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PaymentDialog(
          charge: widget.charge,
          clientName: widget.clientName,
          currencyLabel: widget.currencyLabel,
          payment: widget.payment,
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.payment == null
      ? FilledButton.icon(
          key: ValueKey('pay-${widget.charge.id}'),
          onPressed: _opening ? null : _open,
          icon: const Icon(FLucideIcons.check, size: 18),
          label: const Text('Registrar pago'),
        )
      : TextButton.icon(
          key: ValueKey('void-${widget.payment!.id}'),
          onPressed: _opening ? null : _open,
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.of(context).danger,
          ),
          icon: const Icon(FLucideIcons.undo2, size: 18),
          label: const Text('Anular pago'),
        );
}

class _PaymentDialog extends ConsumerStatefulWidget {
  const _PaymentDialog({
    required this.charge,
    required this.clientName,
    required this.currencyLabel,
    required this.payment,
  });
  final ChargeRecord charge;
  final String clientName, currencyLabel;
  final PaymentRecord? payment;
  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  final _note = TextEditingController();
  final _errorKey = GlobalKey();
  bool _saving = false;
  String? _error;
  bool get _voiding => widget.payment != null;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = ref.read(clientClockProvider)();
      final service = ref.read(paymentServiceProvider);
      if (_voiding) {
        await service.voidPayment(widget.payment!.id, voidedAt: now);
      } else {
        await service.register(
          chargeId: widget.charge.id,
          amountMinor: widget.charge.amountMinor,
          paidAt: now,
          note: optionalText(_note.text),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError ? error.message : null;
      setState(() {
        _saving = false;
        _error = switch (message) {
          'El cargo ya tiene un pago vigente.' => 'Este cargo ya tiene un pago vigente. Cancela y revisa el historial.',
          'El cargo no existe.' =>
            'Este cargo ya no está disponible. Cancela y actualiza los cobros.',
          'El pago no existe o ya fue anulado.' => 'El pago ya fue anulado o no está disponible. Cancela y revisa el historial.',
          _ => _voiding ? 'No se pudo anular el pago. Vuelve a intentarlo.' : 'No se pudo registrar el pago. Tu nota sigue aquí; vuelve a intentarlo.',
        };
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _errorKey.currentContext != null) {
        await Scrollable.ensureVisible(
          _errorKey.currentContext!,
          alignment: 1,
          duration: const Duration(milliseconds: 180),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _voiding
              ? 'Pago anulado. El cargo vuelve a estar sin pagar.'
              : 'Pago registrado.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(_voiding ? 'Anular pago' : 'Registrar pago completo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.clientName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(periodLabel(BillingPeriod.parse(widget.charge.periodKey))),
          const SizedBox(height: 8),
          Text(
            formatMoneyMinor(
              widget.charge.amountMinor,
              currencyLabel: widget.currencyLabel,
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            _voiding
                ? 'El pago se conservará como anulado y esta mensualidad volverá a estar sin pagar. El servicio no cambiará.'
                : 'Se registrará un pago completo por el importe histórico de esta mensualidad. No se pagarán otros cargos.',
          ),
          if (_voiding)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pago del ${paymentDateLabel(widget.payment!.paidAt)}',
              ),
            ),
          if (!_voiding)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                key: const Key('payment-note'),
                controller: _note,
                enabled: !_saving,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
            ),
          if (_error != null)
            Padding(
              key: _errorKey,
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: AppPalette.of(context).danger),
                ),
              ),
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancel-payment'),
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm-payment'),
          onPressed: _saving ? null : _save,
          child: Text(_voiding ? 'Confirmar anulación' : 'Confirmar pago'),
        ),
      ],
    ),
  );
}
