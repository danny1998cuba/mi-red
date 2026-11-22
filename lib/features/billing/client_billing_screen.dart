import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../core/database/app_database.dart';
import '../../core/design_system/app_components.dart';
import '../clients/client_values.dart';
import '../clients/widgets/client_widgets.dart';
import 'billing_calendar.dart';
import 'billing_providers.dart';
import 'billing_values.dart';
import 'data/billing_queries.dart';
import 'data/billing_service.dart';
import 'data/payment_service.dart';
import 'widgets/batch_payment_action.dart';
import 'widgets/billing_widgets.dart';
import 'widgets/payment_action.dart';

class ClientBillingScreen extends ConsumerStatefulWidget {
  const ClientBillingScreen({
    required this.clientId,
    this.focusPeriod,
    super.key,
  });
  final String clientId;
  final String? focusPeriod;

  @override
  ConsumerState<ClientBillingScreen> createState() =>
      _ClientBillingScreenState();
}

class _ClientBillingScreenState extends ConsumerState<ClientBillingScreen> {
  String? _selectedPeriod;
  bool _showOperations = false;

  @override
  void didUpdateWidget(covariant ClientBillingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clientId != oldWidget.clientId ||
        widget.focusPeriod != oldWidget.focusPeriod) {
      _selectedPeriod = null;
      _showOperations = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageHeader(
      context,
      'Historial de cobros',
      leading: IconButton(
        tooltip: 'Atrás',
        icon: const Icon(FLucideIcons.arrowLeft),
        onPressed: () => backToClients(context, '/billing'),
      ),
    ),
    body: SafeArea(
      child: ref
          .watch(clientBillingProvider(widget.clientId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => SingleChildScrollView(
              child: AppEmptyState(
                title: 'No se pudo cargar el historial',
                message: 'Vuelve a intentarlo para consultar las mensualidades guardadas.',
                onAction: () {
                  ref.invalidate(billingSessionProvider);
                  ref.invalidate(clientBillingProvider(widget.clientId));
                },
              ),
            ),
            data: (data) => data == null
                ? SingleChildScrollView(
                    child: AppEmptyState(
                      title: 'Cliente no encontrado',
                      actionLabel: 'Volver a Cobros',
                      onAction: () => backToClients(context, '/billing'),
                    ),
                  )
                : _content(
                    data,
                    ref.watch(billingSessionProvider).asData?.value,
                  ),
          ),
    ),
  );

  Widget _content(ClientBillingData data, LocalDate? today) {
    final months = {for (final row in data.charges) row.charge.periodKey: row};
    final current = today == null ? null : currentPeriod(today).key;
    String? routePeriod;
    try {
      final focus = widget.focusPeriod;
      if (focus != null) routePeriod = BillingPeriod.parse(focus).key;
    } on FormatException {
      // A malformed deep link still opens the current period.
    } on ArgumentError {
      // The year or month is outside the billing calendar.
    }
    final available = {...months.keys, ?routePeriod, ?current}.toList()..sort();
    final selected = available.contains(_selectedPeriod)
        ? _selectedPeriod
        : routePeriod ?? current ?? available.lastOrNull;
    final focus = months[selected];
    final upcoming = [
      for (final key in available)
        if (selected != null &&
            key.compareTo(selected) > 0 &&
            months.containsKey(key))
          months[key]!,
    ];
    final past = [
      for (final key in available.reversed)
        if (selected != null &&
            key.compareTo(selected) < 0 &&
            months.containsKey(key))
          months[key]!,
    ];
    final groups = {
      for (final history in data.batches) history.batch.id: history,
    };
    final paid = data.lastValidPayment;
    final lastAmount = groups[paid?.batchId]?.activeMinor ?? paid?.amountMinor;
    final paymentsByCharge = <String, List<PaymentRecord>>{};
    for (final payment in data.payments) {
      (paymentsByCharge[payment.chargeId] ??= []).add(payment);
    }
    final oldest = data.charges
        .where((row) => row.activePayment == null)
        .firstOrNull
        ?.charge
        .periodKey;

    Widget monthCard(
      ChargeWithStatus item, {
      bool selected = false,
      bool upcoming = false,
    }) => BillingChargeCard(
      key: ValueKey('history-month-${item.charge.periodKey}'),
      client: data.client,
      item: item,
      currencyLabel: data.currencyLabel,
      showHistoryLink: false,
      batches: groups,
      selected: selected,
      upcoming: upcoming,
      hasPreviousDebt:
          oldest != null && oldest.compareTo(item.charge.periodKey) < 0,
      payments: paymentsByCharge[item.charge.id] ?? const [],
    );

    return CustomScrollView(
      key: PageStorageKey('client-billing-${data.client.id}-$_showOperations'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  data.client.fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Servicio: ${serviceStatusLabel(data.client.status).toLowerCase()}',
                ),
                const SizedBox(height: 8),
                Text(
                  paid == null
                      ? 'Sin pagos vigentes'
                      : 'Último pago vigente del cliente: ${formatMoneyMinor(lastAmount!, currencyLabel: data.currencyLabel)} · ${paymentDateLabel(paid.paidAt)}',
                  key: const Key('payment-history-status'),
                ),
                if (today != null) Text(data.coverageLabel(today)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('show-billing-operations'),
                    onPressed: () =>
                        setState(() => _showOperations = !_showOperations),
                    icon: Icon(
                      _showOperations
                          ? FLucideIcons.calendarDays
                          : FLucideIcons.history,
                    ),
                    label: Text(
                      _showOperations ? 'Ver mensualidades' : 'Ver operaciones',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showOperations)
          ..._operations(data)
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSection('Período seleccionado'),
                  if (selected != null)
                    DropdownButton<String>(
                      key: const Key('client-history-period'),
                      isExpanded: true,
                      value: selected,
                      onChanged: available.length <= 1
                          ? null
                          : (key) => setState(() => _selectedPeriod = key),
                      items: [
                        for (final key in available)
                          DropdownMenuItem(
                            value: key,
                            child: Text(periodLabel(BillingPeriod.parse(key))),
                          ),
                      ],
                    ),
                  if (focus != null)
                    monthCard(focus, selected: true)
                  else
                    Text(
                      months.isEmpty
                          ? 'Sin mensualidades registradas'
                          : 'Sin cargo para este período',
                    ),
                  if (data.client.status != 'archived' &&
                      (focus == null || focus.activePayment != null))
                    BatchPaymentAction(
                      data.client.id,
                      selectedPeriod: selected,
                    ),
                ],
              ),
            ),
          ),
          ..._section('Próximos meses / Anticipos', upcoming.length, (index) {
            final item = upcoming[index];
            final future =
                today != null &&
                LocalDate.parse(item.charge.collectionDate).compareTo(today) >
                    0;
            return monthCard(item, upcoming: future);
          }),
          ..._section(
            'Períodos anteriores',
            past.length,
            (index) => monthCard(past[index]),
          ),
        ],
      ],
    );
  }

  Iterable<Widget> _operations(ClientBillingData data) {
    final operations =
        <({String id, int at, BatchHistory? group, PaymentRecord? single})>[
          for (final group in data.batches)
            (
              id: group.batch.id,
              at: group.batch.paidAt,
              group: group,
              single: null,
            ),
          for (final payment in data.payments)
            if (payment.batchId == null)
              (
                id: payment.id,
                at: payment.paidAt,
                group: null,
                single: payment,
              ),
        ]..sort((a, b) {
          final date = b.at.compareTo(a.at);
          return date == 0 ? a.id.compareTo(b.id) : date;
        });
    final charges = {for (final row in data.charges) row.charge.id: row.charge};
    return _section('Operaciones de cobro', operations.length, (index) {
      final operation = operations[index];
      if (operation.group case final group?) {
        return BatchHistoryCard(
          group,
          data.currencyLabel,
          key: ValueKey('operation-${operation.id}'),
        );
      }
      final payment = operation.single!;
      final charge = charges[payment.chargeId]!;
      return FCard(
        key: ValueKey('operation-${operation.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pago de 1 mensualidad · ${periodLabel(BillingPeriod.parse(charge.periodKey))}',
              ),
              Text(
                '${paymentDateLabel(payment.paidAt)} · ${formatMoneyMinor(payment.amountMinor, currencyLabel: data.currencyLabel)}',
              ),
              if (payment.voidedAt case final stamp?)
                Text('Anulado: ${paymentDateLabel(stamp)}')
              else
                PaymentAction(
                  charge: charge,
                  clientName: data.client.fullName,
                  currencyLabel: data.currencyLabel,
                  payment: payment,
                ),
              if (payment.note case final note?) Text('Nota: $note'),
            ],
          ),
        ),
      );
    });
  }

  Iterable<Widget> _section(
    String label,
    int count,
    Widget Function(int) item,
  ) sync* {
    yield SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      sliver: SliverToBoxAdapter(child: AppSection(label)),
    );
    yield SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: count == 0
          ? const SliverToBoxAdapter(child: Text('Sin registros'))
          : SliverList.builder(
              itemCount: count,
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: item(index),
              ),
            ),
    );
  }
}
