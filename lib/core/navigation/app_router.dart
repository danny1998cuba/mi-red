import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/billing/billing_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/clients/client_detail_screen.dart';
import '../../features/clients/client_form_screen.dart';
import '../../features/clients/device_form_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'app_shell.dart';
import 'route_error_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const RouteErrorScreen(),
    routes: [
      GoRoute(
        path: '/clients/new',
        builder: (context, state) => const ClientFormScreen(),
      ),
      GoRoute(
        path: '/clients/:clientId',
        builder: (context, state) =>
            ClientDetailScreen(clientId: state.pathParameters['clientId']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                ClientFormScreen(clientId: state.pathParameters['clientId']!),
          ),
          GoRoute(
            path: 'devices/new',
            builder: (context, state) =>
                DeviceFormScreen(clientId: state.pathParameters['clientId']!),
          ),
          GoRoute(
            path: 'devices/:deviceId/edit',
            builder: (context, state) => DeviceFormScreen(
              clientId: state.pathParameters['clientId']!,
              deviceId: state.pathParameters['deviceId']!,
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientsScreen(),
          ),
          GoRoute(
            path: '/billing',
            builder: (context, state) => const BillingScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
