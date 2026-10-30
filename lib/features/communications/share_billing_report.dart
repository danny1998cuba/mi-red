import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../core/design_system/app_components.dart';
import '../../core/design_system/app_design.dart';
import '../billing/billing_calendar.dart';
import '../billing/data/billing_queries.dart';
import '../clients/client_providers.dart';
import 'communication_actions.dart';
import 'communication_text.dart';

class ShareBillingReportAction extends StatefulWidget {
  const ShareBillingReportAction({
    required this.period,
    required this.data,
    required this.visibleRows,
    required this.filterDescription,
    super.key,
  });
  final BillingPeriod period;
  final BillingPeriodData data;
  final List<BillingRow> visibleRows;
  final String filterDescription;
  @override
  State<ShareBillingReportAction> createState() =>
      _ShareBillingReportActionState();
}

class _ShareBillingReportActionState extends State<ShareBillingReportAction> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _opening = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReportDialog(
          period: widget.period,
          currency: widget.data.currencyLabel,
          all: widget.data.rows.map(ReportEntry.fromRow).toList(),
          filtered: widget.visibleRows.map(ReportEntry.fromRow).toList(),
          filterDescription: widget.filterDescription,
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('billing-share-list'),
    onPressed: _opening ? null : _open,
    icon: const Icon(FLucideIcons.share2, size: 18),
    tooltip: 'Compartir listado',
  );
}

class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({
    required this.period,
    required this.currency,
    required this.all,
    required this.filtered,
    required this.filterDescription,
  });
  final BillingPeriod period;
  final String currency, filterDescription;
  final List<ReportEntry> all, filtered;
  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  late final DateTime _generatedAt = ref.read(clientClockProvider)();
  final _feedbackKey = GlobalKey();
  ReportScope? _scope;
  bool _busy = false;
  String? _error, _notice;
  BillingReport get _report => BillingReport(
    period: widget.period,
    scope: _scope!,
    generatedAt: _generatedAt,
    currency: widget.currency,
    entries: _scope == ReportScope.fullPeriod ? widget.all : widget.filtered,
    filterDescription: widget.filterDescription,
  );

  Future<void> _act({required bool copy}) async {
    if (_busy || _scope == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final text = _report.render();
      if (text.length > 60000) {
        throw StateError(
          'El listado es demasiado largo para compartir con seguridad. Cierra y usa un filtro más acotado; no se compartirá un texto truncado.',
        );
      }
      final actions = ref.read(communicationActionsProvider);
      final notice = copy
          ? await (() async {
              await actions.copyText(text);
              return 'Listado copiado. No se ha enviado desde Mi Red.';
            })()
          : shareOutcomeMessage(await actions.shareText(text));
      if (mounted) setState(() => _notice = notice);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError ? error.message.toString() : 'No se pudo abrir la acción de compartir. Puedes copiar el listado o volver a intentarlo.',
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
          'Compartir listado',
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
                const Text(
                  'Elige conscientemente el alcance. El listado revelará nombres, importes y estados; no incluye teléfonos, direcciones, notas, MAC ni IP.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final scope in ReportScope.values)
                      ChoiceChip(
                        key: ValueKey('report-scope-${scope.name}'),
                        label: Text(
                          scope == ReportScope.fullPeriod
                              ? 'Período completo'
                              : 'Vista filtrada',
                        ),
                        selected: _scope == scope,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                _scope = scope;
                                _error = null;
                                _notice = null;
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Filtro de la vista: ${widget.filterDescription}. El resumen de Cobros sigue representando el período completo; este listado usa el alcance elegido.',
                ),
                const SizedBox(height: 16),
                if (_scope == null)
                  const Text(
                    'Selecciona un alcance para revisar la vista previa.',
                  )
                else ...[
                  const AppSection('Vista previa'),
                  SelectableText(
                    _report.render(previewLimit: 20),
                    key: const Key('report-preview'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Al pulsar Compartir listado confirmas que revisaste el contenido. Tú eliges la aplicación y el destinatario; Mi Red no confirma envío ni entrega.',
                  ),
                ],
                if (_busy)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Abriendo panel de compartir',
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
                      key: const Key('report-share'),
                      onPressed: _busy || _scope == null
                          ? null
                          : () => _act(copy: false),
                      icon: const Icon(FLucideIcons.share2, size: 18),
                      label: const Text('Compartir listado'),
                    ),
                    TextButton.icon(
                      key: const Key('report-copy'),
                      onPressed: _busy || _scope == null
                          ? null
                          : () => _act(copy: true),
                      icon: const Icon(FLucideIcons.copy, size: 18),
                      label: const Text('Copiar listado'),
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
