import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import 'core/design_system/app_design.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/billing/billing_lifecycle.dart';
import 'features/settings/appearance.dart';

class MiRedApp extends ConsumerWidget {
  const MiRedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mi Red',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        ...FLocalizations.localizationsDelegates,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(appearanceProvider).mode,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemBars(Theme.brightnessOf(context)),
        child: FTheme(
          data: Theme.brightnessOf(context) == Brightness.dark
              ? AppDesign.dark
              : AppDesign.light,
          child: BillingLifecycle(child: child!),
        ),
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
