import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Inicio',
      description:
          'Aquí verás el resumen de clientes y cobros. '
          'Esta función aún no está disponible.',
      icon: Icons.home_outlined,
    );
  }
}
