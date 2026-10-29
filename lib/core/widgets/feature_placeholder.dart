import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../design_system/app_components.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });
  final String title;
  final String description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Semantics(
          label: title,
          container: true,
          child: FCard(
            child: AppEmptyState(
              title: 'Pantalla provisional',
              message: description,
              icon: icon,
            ),
          ),
        ),
      ),
    ),
  );
}
