import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/app_design.dart';

abstract final class AppTheme {
  static final light = AppDesign.material(Brightness.light);
  static final dark = AppDesign.material(Brightness.dark);
  static SystemUiOverlayStyle systemBars(Brightness brightness) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      );
}
