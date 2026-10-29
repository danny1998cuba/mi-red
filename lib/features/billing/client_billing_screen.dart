import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../core/design_system/app_components.dart';
import '../clients/client_values.dart';
import '../clients/widgets/client_widgets.dart';
import 'billing_providers.dart';
import 'billing_values.dart';
import 'data/billing_queries.dart';
import 'widgets/billing_widgets.dart';

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
  bool _prepared = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare());
    });
  }

  Future<void> _prepare() async {
    setState(() => _prepared = false);
    await ref.read(billingSessionProvider.notifier).refresh();
    if (mounted) setState(() => _prepared = true);
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
      child: !_prepared
          ? const Center(child: CircularProgressIndicator())
          : ref
                .watch(clientBillingProvider(widget.clientId))
                .when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => SingleChildScrollView(
                    child: AppEmptyState(
                      title: 'No se pudo cargar el historial',
                      message: 'Vuelve a intentarlo para consultar las mensualidades guardadas.',
                      onAction: _prepare,
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
                      : _content(data),
                ),
    ),
  );

  Widget _content(ClientBillingData data) {
    final charges = data.charges.toList()
      ..sort((a, b) {
        final selectedA = a.charge.periodKey == widget.focusPeriod;
        final selectedB = b.charge.periodKey == widget.focusPeriod;
        if (selectedA != selectedB) return selectedA ? -1 : 1;
        return b.charge.periodKey.compareTo(a.charge.periodKey);
      });
    final last = data.lastValidPayment;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  data.client.fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Servicio: ${serviceStatusLabel(data.client.status).toLowerCase()}',
                ),
                const SizedBox(height: 8),
                Text(
                  last == null
                      ? 'Sin pagos vigentes'
                      : 'Último pago vigente del cliente: ${formatMoneyMinor(last.amountMinor, currencyLabel: data.currencyLabel)} · ${paymentDateLabel(last.paidAt)}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Una mensualidad pagada no elimina las deudas de otros períodos.',
                ),
                const AppSection('Mensualidades'),
              ],
            ),
          ),
        ),
        if (charges.isEmpty)
          const SliverToBoxAdapter(
            child: AppEmptyState(
              title: 'Sin mensualidades registradas',
              message: 'Se conserva el historial de los períodos elegibles.',
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.builder(
            itemCount: charges.length,
            itemBuilder: (context, index) {
              final item = charges[index];
              return Padding(
                key: ValueKey(item.charge.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: BillingChargeCard(
                  client: data.client,
                  item: item,
                  currencyLabel: data.currencyLabel,
                  showHistoryLink: false,
                  selected: item.charge.periodKey == widget.focusPeriod,
                  hasPreviousDebt: data.charges.any(
                    (prior) =>
                        prior.charge.periodKey.compareTo(
                              item.charge.periodKey,
                            ) <
                            0 &&
                        prior.activePayment == null,
                  ),
                  payments: data.payments
                      .where((payment) => payment.chargeId == item.charge.id)
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
