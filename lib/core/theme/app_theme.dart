import 'package:flutter/material.dart';

import '../design_system/app_design.dart';

abstract final class AppTheme {
  static final light = AppDesign.material(Brightness.light);
  static final dark = AppDesign.material(Brightness.dark);
}
