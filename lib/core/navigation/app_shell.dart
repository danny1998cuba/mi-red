import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../design_system/app_components.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;
  static const _destinations = [
    (path: '/', label: 'Inicio', icon: FLucideIcons.house),
    (path: '/clients', label: 'Clientes', icon: FLucideIcons.users),
    (path: '/billing', label: 'Cobros', icon: FLucideIcons.receiptText),
    (path: '/settings', label: 'Ajustes', icon: FLucideIcons.settings),
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
      bottomNavigationBar: FBottomNavigationBar(
        safeAreaBottom: true,
        index: selected,
        onChange: (index) => context.go(_destinations[index].path),
        children: [
          for (final destination in _destinations)
            FBottomNavigationBarItem(
              icon: Icon(destination.icon),
              label: Text(
                destination.label,
                softWrap: true,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
