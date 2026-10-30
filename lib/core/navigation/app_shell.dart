import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../design_system/app_components.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;
  static const _destinations = [
    (id: 'home', path: '/', label: 'Inicio', icon: FLucideIcons.house),
    (
      id: 'clients',
      path: '/clients',
      label: 'Clientes',
      icon: FLucideIcons.users,
    ),
    (
      id: 'billing',
      path: '/billing',
      label: 'Cobros',
      icon: FLucideIcons.receiptText,
    ),
    (
      id: 'settings',
      path: '/settings',
      label: 'Ajustes',
      icon: FLucideIcons.settings,
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final index = _destinations.indexWhere(
      (destination) => destination.path == location,
    );
    final selected = index < 0 ? 0 : index;
    return Scaffold(
      appBar: AppPageHeader(context, _destinations[selected].label),
      body: SafeArea(child: child),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final direction = Directionality.of(context);
          final barStyle = FTheme.of(context).bottomNavigationBarStyle;
          final availableLabelWidth =
              (constraints.maxWidth -
                      barStyle.padding.resolve(direction).horizontal) /
                  _destinations.length -
              barStyle.itemStyle.padding.resolve(direction).horizontal;
          final labelStyle = Theme.of(context).textTheme.bodyMedium!
              .copyWith(fontSize: 12, fontWeight: FontWeight.bold);
          final compact = _destinations.any((destination) {
            final painter = TextPainter(
              text: TextSpan(text: destination.label, style: labelStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final doesNotFit = painter.width > availableLabelWidth;
            painter.dispose();
            return doesNotFit;
          });
          return FBottomNavigationBar(
            safeAreaBottom: true,
            index: selected,
            onChange: (index) => context.go(_destinations[index].path),
            children: [
              for (final destination in _destinations)
                Tooltip(
                  key: ValueKey('navigation-${destination.id}'),
                  message: destination.label,
                  excludeFromSemantics: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FBottomNavigationBarItem(
                      icon: Icon(destination.icon),
                      semanticsLabel: compact ? destination.label : null,
                      label: compact
                          ? null
                          : Text(
                              destination.label,
                              softWrap: false,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
