import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../clients/client_providers.dart';
import '../../clients/client_values.dart';
import '../billing_calendar.dart';
import '../billing_providers.dart';
import '../billing_values.dart';
import '../data/payment_service.dart';

Future<void> showBatchPayment(
  BuildContext context,
  String clientId, {
  String? selectedPeriod,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CollectionDialog(clientId, selectedPeriod),
);

class BatchPaymentAction extends StatelessWidget {
  const BatchPaymentAction(this.clientId, {this.selectedPeriod, super.key});
  final String clientId;
  final String? selectedPeriod;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('pay-months'),
    onPressed: () =>
        showBatchPayment(context, clientId, selectedPeriod: selectedPeriod),
    icon: const Icon(FLucideIcons.receiptText, size: 18),
    label: const Text('Registrar pago'),
  );
}

String monthsLabel(int count) =>
    count == 1 ? '1 mensualidad' : '$count mensualidades';
String _period(String key) => periodLabel(BillingPeriod.parse(key));
String _batchStatus(BatchStatus status) => switch (status) {
  BatchStatus.active => 'Vigente',
  BatchStatus.partiallyVoided => 'Parcialmente anulado',
  BatchStatus.voided => 'Totalmente anulado',
};

class _CollectionDialog extends ConsumerStatefulWidget {
  const _CollectionDialog(this.clientId, this.selectedPeriod);
  final String clientId;
  final String? selectedPeriod;

  @override
  ConsumerState<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends ConsumerState<_CollectionDialog> {
  final _note = TextEditingController();
  final _feedback = GlobalKey();
  BatchQuote? _quote;
  int _count = 1;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run(_load);
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final quote = await ref
        .read(paymentServiceProvider)
        .previewBatch(
          widget.clientId,
          ref.read(clientClockProvider)(),
          count: _count,
        );
    if (mounted) setState(() => _quote = quote);
  }

  Future<void> _selectCount() async {
    FocusScope.of(context).unfocus();
    final count = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Cantidad de mensualidades'),
        children: [
          for (var value = 1; value <= maxPaymentMonths; value++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(monthsLabel(value)),
                ),
              ),
            ),
        ],
      ),
    );
    if (!mounted || count == null || count == _count) return;
    setState(() {
      _count = count;
      _quote = null;
    });
    await _run(_load);
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await work();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is StateError ? error.message : 'No se pudo registrar el pago. Tu nota sigue aquí; vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (_message != null) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _feedback.currentContext != null) {
        await Scrollable.ensureVisible(_feedback.currentContext!, alignment: 0);
      }
    }
  }

  Future<void> _save() => _run(() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(paymentServiceProvider)
          .registerBatch(
            _quote!,
            paidAt: ref.read(clientClockProvider)(),
            note: optionalText(_note.text),
          );
    } on PaymentReviewChanged {
      if (!mounted) return;
      setState(() => _quote = null);
      await _load();
      if (mounted) {
        setState(
          () => _message = 'Los cobros cambiaron. Revisa la selección actualizada y vuelve a confirmar.',
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _count == 1
              ? 'Pago registrado.'
              : 'Pago de ${monthsLabel(_count)} registrado.',
        ),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final selected = widget.selectedPeriod ?? quote?.period.key;
    return PopScope<Object?>(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Registrar pago completo'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cantidad de mensualidades'),
            OutlinedButton.icon(
              key: const Key('payment-month-count'),
              onPressed: _busy ? null : _selectCount,
              icon: const Icon(FLucideIcons.chevronDown),
              label: Text(monthsLabel(_count), textAlign: TextAlign.center),
            ),
            if (_message case final message?)
              Padding(
                key: _feedback,
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(liveRegion: true, child: Text(message)),
              ),
            if (quote != null) ...[
              const SizedBox(height: 12),
              Text(
                quote.client.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (quote.client.status == 'suspended')
                const Text(
                  'El servicio está suspendido. El cobro mantiene ese estado.',
                ),
              if (_count > 1)
                Text(
                  'Total: ${formatMoneyMinor(quote.totalMinor, currencyLabel: quote.currency)}',
                ),
              for (final month in quote.months)
                Padding(
                  key: ValueKey('review-month-${month.periodKey}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_period(month.periodKey)),
                      Text(
                        formatMoneyMinor(
                          month.amountMinor,
                          currencyLabel: quote.currency,
                        ),
                      ),
                      Text(
                        [
                          if (month.periodKey.compareTo(quote.period.key) < 0)
                            'Atrasado',
                          if (month.periodKey == selected)
                            'Período seleccionado',
                          if (month.periodKey.compareTo(quote.period.key) > 0)
                            'Anticipo',
                          if (month.periodKey == quote.period.key &&
                              month.periodKey != selected)
                            'Período vigente',
                        ].join(' · '),
                      ),
                    ],
                  ),
                ),
              if (_count > 1)
                const Text('Las mensualidades se registrarán juntas.'),
              if (quote.remaining.isNotEmpty)
                Text(
                  'Quedarán ${quote.remaining.length} mensualidades impagas.',
                ),
              if (quote.nextPeriod case final next?)
                Text('Próxima mensualidad pendiente: ${periodLabel(next)}.'),
              Text(
                'Revisado: ${paymentDateLabel(quote.reviewedAt.millisecondsSinceEpoch)}',
              ),
              if (_count == 1)
                TextField(
                  key: const Key('payment-note'),
                  controller: _note,
                  enabled: !_busy,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                  ),
                ),
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('cancel-payment'),
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          if (quote == null && _message != null)
            FilledButton(
              onPressed: _busy ? null : () => _run(_load),
              child: const Text('Volver a revisar'),
            )
          else
            FilledButton(
              key: const Key('confirm-payment'),
              onPressed: _busy || quote == null ? null : _save,
              child: const Text('Confirmar pago'),
            ),
        ],
      ),
    );
  }
}

class BatchHistoryCard extends StatelessWidget {
  const BatchHistoryCard(this.history, this.currency, {super.key});
  final BatchHistory history;
  final String currency;

  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pago de ${monthsLabel(history.payments.length)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(paymentDateLabel(history.batch.paidAt)),
          _BatchTotals(history, currency),
          BatchDetailAction(
            history,
            currency,
            key: ValueKey('group-detail-${history.batch.id}'),
          ),
        ],
      ),
    ),
  );
}

class _BatchTotals extends StatelessWidget {
  const _BatchTotals(this.history, this.currency);
  final BatchHistory history;
  final String currency;

  @override
  Widget build(BuildContext context) {
    String money(int value) => formatMoneyMinor(value, currencyLabel: currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_batchStatus(history.status)),
        Text('Total original: ${money(history.batch.totalMinor)}'),
        Text(
          'Importe vigente: ${money(history.activeMinor)} · ${history.active.length} vigentes',
        ),
        Text(
          'Importe anulado: ${money(history.voidedMinor)} · ${history.voidedCount} anuladas',
        ),
      ],
    );
  }
}

class BatchDetailAction extends StatelessWidget {
  const BatchDetailAction(
    this.history,
    this.currency, {
    this.paymentId,
    super.key,
  });
  final BatchHistory history;
  final String currency;
  final String? paymentId;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BatchDetail(history, currency, paymentId),
    ),
    child: const Text('Ver detalle del grupo'),
  );
}

class _BatchDetail extends ConsumerStatefulWidget {
  const _BatchDetail(this.initial, this.currency, this.focusPaymentId);
  final BatchHistory initial;
  final String currency;
  final String? focusPaymentId;

  @override
  ConsumerState<_BatchDetail> createState() => _BatchDetailState();
}

class _BatchDetailState extends ConsumerState<_BatchDetail> {
  final _focusMonth = GlobalKey();
  List<BatchMember>? _selection;
  bool _whole = false, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final monthContext = _focusMonth.currentContext;
      if (mounted && monthContext != null) {
        Scrollable.ensureVisible(monthContext);
      }
    });
  }

  void _review(List<BatchMember> selection, {required bool whole}) {
    setState(() {
      _selection = selection;
      _whole = whole;
      _error = null;
    });
  }

  Future<void> _void() async {
    final selection = _selection;
    if (_busy || selection == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final batch = widget.initial.batch;
    try {
      final service = ref.read(paymentServiceProvider);
      final now = ref.read(clientClockProvider)();
      if (_whole) {
        await service.voidBatch(
          batch.id,
          voidedAt: now,
          expectedActiveIds: selection.map((row) => row.payment.id).toSet(),
        );
      } else {
        await service.voidPayment(
          selection.single.payment.id,
          voidedAt: now,
          expectedBatchId: batch.id,
          expectedClientId: batch.clientId,
        );
      }
      if (!mounted) return;
      setState(() => _selection = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _whole
                ? 'Mensualidades vigentes del grupo anuladas.'
                : 'Pago de la mensualidad anulado.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is StateError) _selection = null;
          _error = error is StateError
              ? error.message
              : 'No se pudo anular el pago. Puedes volver a intentarlo.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.initial.batch;
    final data = ref.watch(clientBillingProvider(batch.clientId)).asData?.value;
    final history =
        data?.batches.where((item) => item.batch.id == batch.id).firstOrNull ??
        widget.initial;
    final selection = _selection;
    final active = history.active;
    final currency = data?.currencyLabel ?? widget.currency;
    String money(int amount) =>
        formatMoneyMinor(amount, currencyLabel: currency);
    return PopScope<Object?>(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          selection == null
              ? 'Pago de ${monthsLabel(history.payments.length)}'
              : _whole
              ? 'Anular ${monthsLabel(selection.length)} del grupo'
              : 'Anular esta mensualidad',
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error case final error?)
              Semantics(liveRegion: true, child: Text(error)),
            if (selection != null) ...[
              for (final row in selection)
                Text(
                  '${_period(row.charge.periodKey)} · ${money(row.payment.amountMinor)}',
                ),
              Text(
                'Importe a anular: ${money(selection.fold(0, (sum, row) => sum + row.payment.amountMinor))}',
              ),
              if (!_whole)
                const Text('Los demás pagos del grupo conservan su estado.'),
              const Text(
                'La anulación corrige el registro y no devuelve dinero.',
              ),
            ] else ...[
              Text('Registrado: ${paymentDateLabel(batch.paidAt)}'),
              _BatchTotals(history, currency),
              if (history.batch.voidedAt case final stamp?)
                Text('Anulación conjunta: ${paymentDateLabel(stamp)}'),
              for (final row in history.payments)
                Column(
                  key: row.payment.id == widget.focusPaymentId
                      ? _focusMonth
                      : ValueKey('batch-member-${row.payment.id}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(),
                    Text(
                      '${_period(row.charge.periodKey)} · ${money(row.payment.amountMinor)}',
                    ),
                    if (row.payment.voidedAt case final stamp?)
                      Text('Anulado: ${paymentDateLabel(stamp)}')
                    else ...[
                      Text(
                        isAdvancePayment(row.charge, row.payment)
                            ? 'Pagado anticipadamente'
                            : 'Vigente',
                      ),
                      TextButton(
                        key: ValueKey('void-member-${row.payment.id}'),
                        onPressed: _busy
                            ? null
                            : () => _review([row], whole: false),
                        child: const Text('Anular esta mensualidad'),
                      ),
                    ],
                    if (row.payment.note case final note?) Text('Nota: $note'),
                  ],
                ),
              if (active.isNotEmpty) ...[
                const Divider(),
                OutlinedButton(
                  key: const Key('void-payment-batch'),
                  onPressed: _busy ? null : () => _review(active, whole: true),
                  child: Text(
                    history.status == BatchStatus.active
                        ? 'Anular grupo completo'
                        : 'Anular mensualidades restantes del grupo',
                  ),
                ),
              ],
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    if (selection == null) {
                      Navigator.pop(context);
                    } else {
                      setState(() => _selection = null);
                    }
                  },
            child: Text(selection == null ? 'Cerrar' : 'Cancelar'),
          ),
          if (selection != null)
            FilledButton(
              key: const Key('confirm-void-batch'),
              onPressed: _busy ? null : _void,
              child: const Text('Confirmar anulación'),
            ),
        ],
      ),
    );
  }
}

bool isAdvancePayment(ChargeRecord charge, PaymentRecord payment) =>
    LocalDate.fromDateTime(DateTime.fromMillisecondsSinceEpoch(payment.paidAt))
        .compareTo(LocalDate.parse(charge.collectionDate)) <
    0;
