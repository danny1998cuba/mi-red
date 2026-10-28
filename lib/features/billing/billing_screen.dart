import 'package:flutter/material.dart';

import '../../core/widgets/feature_placeholder.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Cobros',
      description:
          'Aquí consultarás mensualidades y pagos. '
          'Esta función aún no está disponible.',
      icon: Icons.receipt_long_outlined,
    );
  }
}
