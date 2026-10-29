import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design_system/app_components.dart';
import '../../../core/design_system/app_design.dart';
import '../../clients/client_values.dart';
import '../billing_calendar.dart';
import '../billing_values.dart';
import '../data/billing_queries.dart';
import '../data/billing_service.dart';
import 'payment_action.dart';

class ChargeStatusBadge extends StatelessWidget {
  const ChargeStatusBadge(this.status, {super.key});
  final ChargeStatus status;
  @override
  Widget build(BuildContext context) => AppStatusBadge(
    label: chargeStatusLabel(status),
    icon: switch (status) {
      ChargeStatus.paid => FLucideIcons.circleCheck,
      ChargeStatus.pending => FLucideIcons.clock3,
      ChargeStatus.suspensionCandidate => FLucideIcons.triangleAlert,
    },
    tone: switch (status) {
      ChargeStatus.paid => AppStatusTone.positive,
      ChargeStatus.pending => AppStatusTone.warning,
      ChargeStatus.suspensionCandidate => AppStatusTone.danger,
    },
  );
}

class BillingSummaryCard extends StatelessWidget {
  const BillingSummaryCard(this.data, {super.key});
  final BillingPeriodData data;
  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in [
              ('Clientes con cargo', '${data.summary.totalCharges}'),
              ('Pagados', '${data.summary.paidCharges}'),
              ('Sin pagar', '${data.summary.unpaidCharges}'),
              (
                'Por cobrar',
                formatMoneyMinor(
                  data.outstandingMinor,
                  currencyLabel: data.currencyLabel,
                ),
              ),
            ])
              SizedBox(
                width: (constraints.maxWidth - 12) / 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.$1,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      metric.$2,
                      key: ValueKey('summary-${metric.$1}'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class BillingChargeCard extends StatelessWidget {
  const BillingChargeCard({
    required this.client,
    required this.item,
    required this.currencyLabel,
    this.hasPreviousDebt = false,
    this.showHistoryLink = true,
    this.payments = const [],
    this.selected = false,
    super.key,
  });
  final ClientRecord client;
  final ChargeWithStatus item;
  final String currencyLabel;
  final bool hasPreviousDebt, showHistoryLink, selected;
  final List<PaymentRecord> payments;
  @override
  Widget build(BuildContext context) {
    final charge = item.charge;
    void openHistory() => context.push(
      '/billing/clients/${Uri.encodeComponent(client.id)}?period=${charge.periodKey}',
    );
    return FCard(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpace.radius),
        child: InkWell(
          key: ValueKey('billing-charge-${charge.id}'),
          onTap: showHistoryLink ? openHistory : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Mensualidad seleccionada',
                      style: TextStyle(color: AppPalette.of(context).accent),
                    ),
                  ),
                Text(
                  showHistoryLink
                      ? client.fullName
                      : periodLabel(BillingPeriod.parse(charge.periodKey)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChargeStatusBadge(item.status),
                    Text(
                      formatMoneyMinor(
                        charge.amountMinor,
                        currencyLabel: currencyLabel,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Servicio: ${serviceStatusLabel(client.status).toLowerCase()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.activePayment != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Pagado el ${paymentDateLabel(item.activePayment!.paidAt)}',
                    ),
                  ),
                if (hasPreviousDebt)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tiene mensualidades anteriores sin pagar.',
                      style: TextStyle(
                        color: AppPalette.of(context).warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!showHistoryLink) ...[
                  const SizedBox(height: 8),
                  Text('Cobro desde ${calendarLabel(charge.collectionDate)}'),
                  Text(
                    'Candidato desde ${calendarLabel(charge.suspensionCandidateDate)} si no se paga.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.activePayment == null)
                      PaymentAction(
                        charge: charge,
                        clientName: client.fullName,
                        currencyLabel: currencyLabel,
                      ),
                    if (showHistoryLink)
                      TextButton.icon(
                        onPressed: openHistory,
                        icon: const Icon(FLucideIcons.history, size: 18),
                        label: const Text('Ver historial'),
                      ),
                  ],
                ),
                if (!showHistoryLink && payments.isNotEmpty) ...[
                  const Divider(height: 24),
                  const AppSection('Pagos de esta mensualidad'),
                  for (final payment in payments.reversed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AppStatusBadge(
                              label: payment.voidedAt == null
                                  ? 'Pago vigente'
                                  : 'Pago anulado',
                              icon: payment.voidedAt == null
                                  ? FLucideIcons.check
                                  : FLucideIcons.undo2,
                              tone: payment.voidedAt == null
                                  ? AppStatusTone.positive
                                  : AppStatusTone.neutral,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatMoneyMinor(
                              payment.amountMinor,
                              currencyLabel: currencyLabel,
                            ),
                          ),
                          Text(
                            'Registrado: ${paymentDateLabel(payment.paidAt)}',
                          ),
                          if (payment.voidedAt != null)
                            Text(
                              'Anulado: ${paymentDateLabel(payment.voidedAt!)}',
                            ),
                          if (payment.note?.isNotEmpty ?? false)
                            Text('Nota: ${payment.note}'),
                          if (payment.voidedAt == null &&
                              item.activePayment?.id == payment.id)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: PaymentAction(
                                charge: charge,
                                clientName: client.fullName,
                                currencyLabel: currencyLabel,
                                payment: payment,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
