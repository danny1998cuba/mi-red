import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_components.dart';
import '../../core/design_system/app_design.dart';
import '../billing/billing_calendar.dart';
import '../billing/billing_providers.dart';
import '../billing/billing_values.dart';
import '../billing/data/billing_queries.dart';
import '../clients/client_values.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
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

  Future<void> _open(String location) async {
    await context.push<void>(location);
    if (mounted) await _prepare();
  }

  @override
  Widget build(BuildContext context) => !_prepared
      ? const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando Inicio'),
        )
      : ref
            .watch(dashboardProvider)
            .when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Cargando Inicio',
                ),
              ),
              error: (_, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.page),
                child: AppEmptyState(
                  title: 'No se pudo actualizar Inicio',
                  message: 'Vuelve a intentarlo para consultar los clientes y cobros guardados.',
                  onAction: _prepare,
                ),
              ),
              data: _content,
            );

  Widget _content(DashboardData data) {
    final billing = data.billing;
    return CustomScrollView(
      key: const PageStorageKey('dashboard-list'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            4,
            AppSpace.page,
            AppSpace.page,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Período de cobro',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            periodLabel(data.period),
                            key: const Key('dashboard-period'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('dashboard-refresh'),
                      tooltip: 'Actualizar Inicio',
                      onPressed: _prepare,
                      icon: const Icon(FLucideIcons.refreshCw, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                _DashboardMetrics(data),
                const SizedBox(height: AppSpace.md),
                FCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Recaudado este período'),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          formatMoneyMinor(
                            billing.summary.collectedMinor,
                            currencyLabel: billing.currencyLabel,
                          ),
                          key: const Key('dashboard-collected'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Text(
                          'Pagos vigentes del período mostrado. No incluye pagos anulados ni otros períodos.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                if (data.totalClients == 0)
                  AppEmptyState(
                    title: 'Añade tu primer cliente',
                    message:
                        'Registra sus datos y su mensualidad para comenzar.',
                    actionLabel: 'Añadir cliente',
                    onAction: () => _open('/clients/new'),
                  )
                else ...[
                  if (billing.summary.totalCharges == 0)
                    const _DashboardNotice(
                      label: 'Sin cargos en este período',
                      message: 'Hay clientes registrados, pero este período no tiene mensualidades emitidas.',
                    )
                  else if (billing.summary.unpaidCharges == 0)
                    const _DashboardNotice(
                      label: 'Período pagado',
                      message: 'Todos los cargos de este período tienen un pago vigente. Revisa también si hay deuda anterior.',
                      positive: true,
                    ),
                  const AppSection('Acciones rápidas'),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      FilledButton.icon(
                        key: const Key('dashboard-add-client'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(AppSpace.md),
                        ),
                        onPressed: () => _open('/clients/new'),
                        icon: const Icon(FLucideIcons.userPlus, size: 18),
                        label: const Text('Añadir cliente'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('dashboard-billing'),
                        onPressed: () => context.go('/billing'),
                        icon: const Icon(FLucideIcons.receiptText, size: 18),
                        label: const Text('Ver cobros'),
                      ),
                      TextButton.icon(
                        key: const Key('dashboard-view-unpaid'),
                        onPressed: () => context.go('/billing?filter=unpaid'),
                        icon: const Icon(FLucideIcons.clock3, size: 18),
                        label: const Text('Ver pendientes'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                const AppSection('Requieren revisión'),
                FCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${data.reviewCount} ${data.reviewCount == 1 ? 'cliente activo' : 'clientes activos'}',
                          key: const Key('dashboard-review-count'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          'Con cargos sin pagar desde su fecha de posible suspensión, incluidos períodos anteriores. El servicio se cambia manualmente.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (data.reviewCount == 0)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpace.sm),
                            child: Text(
                              'No hay clientes activos que requieran revisión por suspensión.',
                            ),
                          ),
                        for (final client in data.reviewClients) ...[
                          const Divider(height: AppSpace.lg),
                          Text(
                            client.fullName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            'Sin pagar desde ${periodLabel(BillingPeriod.parse(client.oldestPeriodKey))}.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: ValueKey('review-${client.id}'),
                              onPressed: () => _open(
                                '/billing/clients/${Uri.encodeComponent(client.id)}?period=${client.oldestPeriodKey}',
                              ),
                              icon: const Icon(FLucideIcons.history, size: 18),
                              label: const Text('Ver historial'),
                            ),
                          ),
                        ],
                        if (data.reviewCount > data.reviewClients.length)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Text(
                              'Mostrando ${data.reviewClients.length} de ${data.reviewCount}. Revisa también las mensualidades anteriores en Cobros.',
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('dashboard-review-billing'),
                            onPressed: () => context.go('/billing'),
                            icon: const Icon(
                              FLucideIcons.receiptText,
                              size: 18,
                            ),
                            label: const Text('Ver cobros'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics(this.data);
  final DashboardData data;
  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = MediaQuery.textScalerOf(context).scale(14) >= 21;
          final width = singleColumn
              ? constraints.maxWidth
              : (constraints.maxWidth - AppSpace.md) / 2;
          return Wrap(
            spacing: AppSpace.md,
            runSpacing: AppSpace.md,
            children: [
              for (final metric in [
                (
                  'active',
                  'Clientes activos',
                  '${data.billing.summary.activeClients}',
                ),
                (
                  'paid',
                  'Pagados del período',
                  '${data.billing.summary.paidCharges}',
                ),
                (
                  'unpaid',
                  'Pendientes del período',
                  '${data.billing.summary.unpaidCharges}',
                ),
                (
                  'outstanding',
                  'Por cobrar del período',
                  formatMoneyMinor(
                    data.billing.outstandingMinor,
                    currencyLabel: data.billing.currencyLabel,
                  ),
                ),
              ])
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.$2,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        metric.$3,
                        key: ValueKey('dashboard-${metric.$1}'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _DashboardNotice extends StatelessWidget {
  const _DashboardNotice({
    required this.label,
    required this.message,
    this.positive = false,
  });
  final String label, message;
  final bool positive;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppStatusBadge(
          label: label,
          icon: positive ? FLucideIcons.circleCheck : FLucideIcons.info,
          tone: positive ? AppStatusTone.positive : AppStatusTone.neutral,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(message),
      ],
    ),
  );
}
