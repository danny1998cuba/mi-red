import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _destinations = [
    (
      path: '/',
      label: 'Inicio',
      icon: Icons.home_outlined,
      selected: Icons.home,
    ),
    (
      path: '/clients',
      label: 'Clientes',
      icon: Icons.people_outline,
      selected: Icons.people,
    ),
    (
      path: '/billing',
      label: 'Cobros',
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long,
    ),
    (
      path: '/settings',
      label: 'Ajustes',
      icon: Icons.settings_outlined,
      selected: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _destinations.indexWhere(
      (destination) => destination.path == location,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Red')),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (index) => context.go(_destinations[index].path),
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selected),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
