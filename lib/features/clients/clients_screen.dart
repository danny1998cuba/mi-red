import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Clientes',
      description:
          'Aquí gestionarás clientes y dispositivos. '
          'Esta función aún no está disponible.',
      icon: Icons.people_outline,
    );
  }
}
