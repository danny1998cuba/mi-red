import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_components.dart';
import '../clients/client_providers.dart';
import 'billing_calendar.dart';
import 'billing_providers.dart';
import 'billing_values.dart';
import 'data/billing_queries.dart';
import 'widgets/billing_widgets.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});
  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final _search = TextEditingController();
  BillingPeriod? _selected;
  BillingFilter _filter = BillingFilter.all;
  bool _expanded = false;
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

  void _select(BillingPeriod? period) {
    setState(() => _selected = period);
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(billingSessionProvider);
    final today =
        session.asData?.value ??
        LocalDate.fromDateTime(ref.read(clientClockProvider)());
    final current = currentPeriod(today);
    final period = _selected ?? current;
    final previous = adjacentPeriod(period, -1);
    final next = adjacentPeriod(period, 1);
    final ready = _prepared && !session.isLoading;
    return CustomScrollView(
      key: const PageStorageKey('billing-list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          sliver: SliverToBoxAdapter(
            child: FCard(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      periodLabel(period),
                      key: const Key('billing-period'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          key: const Key('billing-previous'),
                          tooltip: 'Mes anterior',
                          onPressed: ready && previous != null
                              ? () => _select(previous)
                              : null,
                          icon: const Icon(FLucideIcons.chevronLeft),
                        ),
                        IconButton(
                          key: const Key('billing-current'),
                          tooltip: 'Ir al período actual',
                          onPressed: ready ? () => _select(null) : null,
                          icon: const Icon(FLucideIcons.calendarDays),
                        ),
                        IconButton(
                          key: const Key('billing-next'),
                          tooltip: 'Mes siguiente',
                          onPressed:
                              ready &&
                                  next != null &&
                                  next.compareTo(current) <= 0
                              ? () => _select(next)
                              : null,
                          icon: const Icon(FLucideIcons.chevronRight),
                        ),
                        IconButton(
                          key: const Key('billing-refresh'),
                          tooltip: 'Actualizar cobros',
                          onPressed: ready ? _prepare : null,
                          icon: const Icon(FLucideIcons.refreshCw, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!_prepared)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          ...ref
              .watch(billingPeriodProvider(period))
              .when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () => [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ],
                error: (_, _) => [
                  SliverToBoxAdapter(
                    child: AppEmptyState(
                      title: 'No se pudieron actualizar los cobros',
                      message: 'Vuelve a intentarlo para consultar los cargos y pagos guardados.',
                      onAction: _prepare,
                    ),
                  ),
                ],
                data: (data) => _content(data),
              ),
      ],
    );
  }

  List<Widget> _content(BillingPeriodData data) {
    final query = _search.text.trim().toLowerCase();
    final rows = data.rows
        .where(
          (row) =>
              row.client.fullName.toLowerCase().contains(query) &&
              switch (_filter) {
                BillingFilter.all => true,
                BillingFilter.unpaid => row.item.activePayment == null,
                BillingFilter.paid => row.item.status == ChargeStatus.paid,
                BillingFilter.suspensionCandidate =>
                  row.item.status == ChargeStatus.suspensionCandidate,
              },
        )
        .toList();
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BillingSummaryCard(data),
              const SizedBox(height: 12),
              AppSearchField(
                key: const Key('billing-search'),
                controller: _search,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 4),
              AppFilterDisclosure(
                controlKey: const Key('billing-filters'),
                expanded: _expanded,
                summary: billingFilterLabel(_filter),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final filter in BillingFilter.values)
                      ChoiceChip(
                        label: Text(billingFilterLabel(filter)),
                        selected: _filter == filter,
                        showCheckmark: true,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                  ],
                ),
              ),
              if (_expanded)
                Text(
                  'Pendientes incluye todos los cargos sin pagar, también los candidatos a suspensión.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (query.isNotEmpty || _filter != BillingFilter.all) ...[
                const SizedBox(height: 8),
                Text(
                  '${rows.length} de ${data.rows.length} mensualidades',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      if (rows.isEmpty)
        SliverToBoxAdapter(
          child: AppEmptyState(
            title: data.rows.isEmpty
                ? 'No hay cargos en este período'
                : 'No hay coincidencias',
            message: data.rows.isEmpty
                ? 'Los cargos dependen del alta y los períodos activos de cada cliente.'
                : 'Prueba otro nombre o filtro.',
            actionLabel: data.rows.isEmpty ? 'Ver clientes' : null,
            onAction: data.rows.isEmpty ? () => context.go('/clients') : null,
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return Padding(
              key: ValueKey(row.item.charge.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: BillingChargeCard(
                client: row.client,
                item: row.item,
                currencyLabel: data.currencyLabel,
                hasPreviousDebt: row.hasPreviousDebt,
              ),
            );
          },
        ),
      ),
    ];
  }
}
