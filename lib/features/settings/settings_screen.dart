import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FTileGroup(
          intrinsicWidth: true,
          label: const Text('Preferencias'),
          children: [
            _tile(
              context,
              'business',
              'Mi negocio',
              'Nombre, moneda y prefijo',
              FLucideIcons.store,
            ),
            _tile(
              context,
              'appearance',
              'Apariencia',
              'Automático, claro u oscuro',
              FLucideIcons.palette,
            ),
            _tile(
              context,
              'reminders',
              'Recordatorios',
              'Avisos y permiso de Android',
              FLucideIcons.bell,
            ),
          ],
        ),
        const SizedBox(height: 24),
        FTileGroup(
          intrinsicWidth: true,
          label: const Text('Datos y seguridad'),
          children: [
            _tile(
              context,
              'backups',
              'Copias de seguridad',
              'Crear y recuperar copias cifradas',
              FLucideIcons.shieldCheck,
            ),
          ],
        ),
        const SizedBox(height: 24),
        FTileGroup(
          intrinsicWidth: true,
          label: const Text('Información'),
          children: [
            _tile(
              context,
              'about',
              'Acerca de Mi Red',
              'Versión y CoreX4Dev',
              FLucideIcons.info,
            ),
          ],
        ),
      ],
    ),
  );

  FTile _tile(
    BuildContext context,
    String route,
    String title,
    String subtitle,
    IconData icon,
  ) => FTile.raw(
    key: ValueKey('settings-$route'),
    onPress: () => context.push('/settings/$route'),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!,
              softWrap: true,
              overflow: TextOverflow.visible,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(FLucideIcons.chevronRight, size: 18),
        ],
      ),
    ),
  );
}
