import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../communications/communication_actions.dart';
import 'settings_page.dart';

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
  retry: (count, error) => null,
);

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});
  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  bool _opening = false;
  String? _error;
  Future<void> _openSite() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      if (!await ref
          .read(communicationActionsProvider)
          .openLink(Uri.https('corex4dev.com'))) {
        throw StateError('No compatible application');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo abrir el sitio. Puedes volver a intentarlo cuando tengas una aplicación compatible.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Acerca de Mi Red',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            'assets/branding/mi_red_logo_master.png',
            width: 100,
            height: 100,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Mi Red',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const Text('Gestión de clientes y cobros', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ref
            .watch(packageInfoProvider)
            .when(
              data: (info) => Text(
                'Versión ${info.version} (${info.buildNumber})',
                key: const Key('about-version'),
                textAlign: TextAlign.center,
              ),
              loading: () => const Text(
                'Consultando versión…',
                textAlign: TextAlign.center,
              ),
              error: (_, _) => Column(
                children: [
                  const Text('No se pudo consultar la versión instalada.'),
                  TextButton(
                    onPressed: () => ref.invalidate(packageInfoProvider),
                    child: const Text('Reintentar versión'),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 24),
        const FCard(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Desarrollado por CoreX4Dev',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          key: const Key('about-website-link'),
          link: true,
          child: OutlinedButton.icon(
            key: const Key('about-website'),
            onPressed: _opening ? null : _openSite,
            icon: const Icon(FLucideIcons.externalLink, size: 18),
            label: const Text(
              'https://corex4dev.com',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        const SizedBox(height: 24),
        const Text(
          'La gestión de clientes y cobros funciona sin internet. El sitio del desarrollador y el envío por WhatsApp requieren conectividad.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Conserva copias cifradas fuera del teléfono y guarda su contraseña por separado. Mi Red no puede recuperar una contraseña olvidada.',
        ),
      ],
    ),
  );
}
