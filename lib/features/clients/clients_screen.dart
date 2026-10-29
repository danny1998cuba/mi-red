import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design_system/app_components.dart';
import '../../core/design_system/app_design.dart';
import 'client_providers.dart';
import 'client_values.dart';
import 'data/client_service.dart';
import 'widgets/client_widgets.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});
  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _search = TextEditingController();
  ServiceStatus? _status = ServiceStatus.active;
  bool _filtersExpanded = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final currency = ref.watch(currencyLabelProvider).asData?.value ?? '';
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchField(
                  key: const Key('client-search'),
                  controller: _search,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 8),
                AppFilterDisclosure(
                  controlKey: const Key('client-filters'),
                  expanded: _filtersExpanded,
                  summary: _status == null
                      ? 'Todos'
                      : serviceStatusLabel(_status!.name),
                  onPressed: () =>
                      setState(() => _filtersExpanded = !_filtersExpanded),
                  action: FButton(
                    key: const Key('add-client'),
                    onPress: () => context.push('/clients/new'),
                    mainAxisSize: MainAxisSize.min,
                    size: FButtonSizeVariant.lg,
                    semanticsLabel: 'Añadir cliente',
                    prefix: const Icon(FLucideIcons.userPlus, size: 18),
                    child: const Text('Añadir'),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final entry in <(ServiceStatus?, String)>[
                        (ServiceStatus.active, 'Activos'),
                        (ServiceStatus.suspended, 'Suspendidos'),
                        (ServiceStatus.archived, 'Archivados'),
                        (null, 'Todos'),
                      ])
                        ChoiceChip(
                          showCheckmark: true,
                          checkmarkColor: AppPalette.of(context).accent,
                          label: Text(entry.$2),
                          selected: _status == entry.$1,
                          onSelected: (_) => setState(() => _status = entry.$1),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ...clients.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          error: (error, stack) => [
            SliverToBoxAdapter(
              child: ClientNotice(
                title: 'No se pudieron cargar los clientes',
                message: 'Comprueba el almacenamiento del teléfono y vuelve a intentarlo.',
                onAction: () => ref.invalidate(clientsProvider),
              ),
            ),
          ],
          data: (all) {
            final rows = filterClients(
              all,
              query: _search.text,
              status: _status,
            );
            if (rows.isEmpty) {
              return [
                SliverToBoxAdapter(
                  child: ClientNotice(
                    title: _search.text.trim().isNotEmpty
                        ? 'No hay resultados'
                        : 'No hay clientes en este filtro',
                    message: all.isEmpty
                        ? 'Añade tu primer cliente para empezar.'
                        : 'Prueba otra búsqueda o selecciona otro estado.',
                    actionLabel: all.isEmpty ? 'Añadir cliente' : null,
                    onAction: all.isEmpty
                        ? () => context.push('/clients/new')
                        : null,
                  ),
                ),
              ];
            }
            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ClientCard(rows[index], currency: currency),
                  ),
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard(this.client, {required this.currency});
  final ClientRecord client;
  final String currency;
  @override
  Widget build(BuildContext context) => FCard(
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpace.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('client-${client.id}'),
        onTap: () => context.push('/clients/${Uri.encodeComponent(client.id)}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                client.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ServiceStatusBadge(client.status),
                  Text(
                    '${formatMoneyMinor(client.monthlyFeeMinor, currencyLabel: currency)} al mes',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              if (client.address?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    client.address!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppPalette.of(context).secondary),
                  ),
                ),
              if (client.phone?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    client.phone!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
