import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../core/database/app_database.dart';
import '../../core/design_system/app_components.dart';
import '../../core/design_system/app_design.dart';
import '../billing/billing_calendar.dart';
import '../billing/billing_providers.dart';
import '../billing/billing_values.dart';
import '../billing/data/billing_service.dart';
import '../clients/client_providers.dart';
import '../clients/client_values.dart';
import 'communication_actions.dart';
import 'communication_text.dart';

class WhatsAppReminderAction extends StatefulWidget {
  const WhatsAppReminderAction({
    required this.client,
    required this.item,
    required this.currency,
    super.key,
  });
  final ClientRecord client;
  final ChargeWithStatus item;
  final String currency;
  @override
  State<WhatsAppReminderAction> createState() => _WhatsAppReminderActionState();
}

class _WhatsAppReminderActionState extends State<WhatsAppReminderAction> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening || widget.item.activePayment != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _opening = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReminderDialog(
          client: widget.client,
          item: widget.item,
          currency: widget.currency,
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: ValueKey('whatsapp-${widget.item.charge.id}'),
    onPressed: _opening || widget.item.activePayment != null ? null : _open,
    icon: const Icon(FLucideIcons.messageCircle, size: 18),
    label: const Text('Recordar por WhatsApp'),
  );
}

class _ReminderDialog extends ConsumerStatefulWidget {
  const _ReminderDialog({
    required this.client,
    required this.item,
    required this.currency,
  });
  final ClientRecord client;
  final ChargeWithStatus item;
  final String currency;
  @override
  ConsumerState<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends ConsumerState<_ReminderDialog> {
  late final _phone = TextEditingController(text: widget.client.phone ?? '');
  late final _message = TextEditingController(
    text: reminderMessage(widget.client.fullName, widget.item, widget.currency),
  );
  final _feedbackKey = GlobalKey();
  bool _busy = false;
  String? _error, _notice;
  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_message.text.trim().isEmpty) {
        throw const FormatException('Escribe un mensaje antes de continuar.');
      }
      // A payment may have changed while returning from another app. Never export a stale pending reminder.
      final data = await ref
          .read(billingQueriesProvider)
          .clientData(
            widget.client.id,
            LocalDate.fromDateTime(ref.read(clientClockProvider)()),
          );
      final charge =
          data?.charges
              .where((row) => row.charge.id == widget.item.charge.id)
              .toList() ??
          [];
      if (charge.isEmpty) {
        throw StateError(
          'Esta mensualidad ya no está disponible. Cierra y actualiza el historial.',
        );
      }
      if (charge.single.activePayment != null) {
        throw StateError(
          'Esta mensualidad ya está pagada. No se abrirá un recordatorio pendiente.',
        );
      }
      final actions = ref.read(communicationActionsProvider);
      String notice;
      if (action == 'open') {
        final opened = await actions.openLink(
          whatsappUri(_phone.text, _message.text),
        );
        if (!opened) {
          throw StateError(
            'No se pudo abrir una aplicación compatible. Puedes copiar el mensaje o usar Compartir.',
          );
        }
        notice = 'Enlace abierto. Revisa el mensaje y decide si enviarlo; no confirma envío ni entrega.';
      } else if (action == 'copy') {
        await actions.copyText(_message.text);
        notice = 'Mensaje copiado. No se ha enviado desde Mi Red.';
      } else {
        notice = shareOutcomeMessage(await actions.shareText(_message.text));
      }
      if (mounted) setState(() => _notice = notice);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : error is StateError
              ? error.message.toString()
              : 'No se pudo completar la acción. Tu mensaje sigue aquí; copia el texto o vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && _feedbackKey.currentContext != null) {
          await Scrollable.ensureVisible(
            _feedbackKey.currentContext!,
            alignment: 1,
            duration: const Duration(milliseconds: 180),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_busy,
    child: Dialog.fullscreen(
      child: Scaffold(
        appBar: AppPageHeader(
          context,
          'Recordatorio',
          leading: IconButton(
            key: const Key('communication-close'),
            tooltip: 'Cerrar',
            icon: const Icon(FLucideIcons.x),
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.client.fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${periodLabel(BillingPeriod.parse(widget.item.charge.periodKey))} · ${chargeStatusLabel(widget.item.status)}',
                ),
                Text(
                  formatMoneyMinor(
                    widget.item.charge.amountMinor,
                    currencyLabel: widget.currency,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'El número debe empezar por + y código de país. La corrección solo se usará esta vez; no cambia la ficha.',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('whatsapp-recipient'),
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Número internacional para esta ocasión',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('whatsapp-message'),
                  controller: _message,
                  enabled: !_busy,
                  minLines: 4,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje editable',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mi Red solo abrirá el enlace. Revisa y pulsa Enviar en WhatsApp si decides hacerlo. Abrir o compartir no confirma entrega.',
                ),
                const SizedBox(height: 12),
                if (_busy)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Preparando acción',
                  ),
                if (_error != null || _notice != null)
                  Padding(
                    key: _feedbackKey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error ?? _notice!,
                        style: TextStyle(
                          color: _error != null
                              ? AppPalette.of(context).danger
                              : null,
                        ),
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('whatsapp-open'),
                      onPressed: _busy ? null : () => _act('open'),
                      icon: const Icon(FLucideIcons.externalLink, size: 18),
                      label: const Text('Abrir WhatsApp'),
                    ),
                    TextButton.icon(
                      key: const Key('whatsapp-copy'),
                      onPressed: _busy ? null : () => _act('copy'),
                      icon: const Icon(FLucideIcons.copy, size: 18),
                      label: const Text('Copiar mensaje'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('whatsapp-share'),
                      onPressed: _busy ? null : () => _act('share'),
                      icon: const Icon(FLucideIcons.share2, size: 18),
                      label: const Text('Compartir mensaje'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
