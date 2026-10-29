import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../core/widgets/feature_placeholder.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Ajustes',
      description:
          'Aquí configurarás el negocio y los respaldos. '
          'Esta función aún no está disponible.',
      icon: FLucideIcons.settings,
    );
  }
}
