import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_components.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.title, required this.child, super.key});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageHeader(
      context,
      title,
      leading: IconButton(
        tooltip: 'Atrás',
        icon: const Icon(FLucideIcons.arrowLeft),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/settings'),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}
