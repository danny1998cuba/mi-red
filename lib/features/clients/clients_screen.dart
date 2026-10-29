import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
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
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const Key('add-client'),
        onPressed: () => context.push('/clients/new'),
        tooltip: 'Añadir cliente',
        child: const Icon(Icons.person_add_outlined),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('client-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar clientes',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(Icons.close, size: 20),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      expanded: _filtersExpanded,
                      child: TextButton.icon(
                        key: const Key('client-filters'),
                        onPressed: () => setState(
                          () => _filtersExpanded = !_filtersExpanded,
                        ),
                        icon: Icon(
                          _filtersExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: Text(
                          'Filtros · ${_status == null ? 'Todos' : serviceStatusLabel(_status!.name)}',
                        ),
                      ),
                    ),
                  ),
                  if (_filtersExpanded)
                    Wrap(
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
                            label: Text(entry.$2),
                            selected: _status == entry.$1,
                            onSelected: (_) =>
                                setState(() => _status = entry.$1),
                          ),
                      ],
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
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ];
              }
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) =>
                        _ClientCard(rows[index], currency: currency),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard(this.client, {required this.currency});
  final ClientRecord client;
  final String currency;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('client-${client.id}'),
      onTap: () => context.push('/clients/${Uri.encodeComponent(client.id)}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              client.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ServiceStatusBadge(client.status),
            ),
            Text(
              '${formatMoneyMinor(client.monthlyFeeMinor, currencyLabel: currency)} al mes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (client.address?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(client.address!),
              ),
            if (client.phone?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(client.phone!),
              ),
          ],
        ),
      ),
    ),
  );
}
