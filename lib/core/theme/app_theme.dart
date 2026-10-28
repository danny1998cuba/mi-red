import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final light = _create(Brightness.light);
  static final dark = _create(Brightness.dark);

  static ThemeData _create(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF006B60),
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
