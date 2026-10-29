import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

/// Shared tokens for Forui and the retained Material editing controls.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const page = 16.0;
  static const lg = 24.0;
  static const radius = 12.0;
}

class AppPalette {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.text,
    required this.secondary,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
  });
  final Color canvas, surface, text, secondary, border, accent, onAccent;
  final Color success, warning, danger;
  static const light = AppPalette(
    canvas: Color(0xFFF8FAFC),
    surface: Colors.white,
    text: Color(0xFF0F172A),
    secondary: Color(0xFF64748B),
    border: Color(0xFFE2E8F0),
    accent: Color(0xFF0F766E),
    onAccent: Colors.white,
    success: Color(0xFF15803D),
    warning: Color(0xFF92400E),
    danger: Color(0xFFB91C1C),
  );
  static const dark = AppPalette(
    canvas: Color(0xFF0B1220),
    surface: Color(0xFF111B2B),
    text: Color(0xFFF1F5F9),
    secondary: Color(0xFF94A3B8),
    border: Color(0xFF263449),
    accent: Color(0xFF2DD4BF),
    onAccent: Color(0xFF0B1220),
    success: Color(0xFF86EFAC),
    warning: Color(0xFFFCD34D),
    danger: Color(0xFFFCA5A5),
  );
  static AppPalette of(BuildContext context) =>
      Theme.brightnessOf(context) == Brightness.dark ? dark : light;
}

abstract final class AppDesign {
  static final light = _create(Brightness.light);
  static final dark = _create(Brightness.dark);
  static FThemeData _create(Brightness brightness) {
    final base = brightness == Brightness.light
        ? FTheme.neutral.light.touch
        : FTheme.neutral.dark.touch;
    final p = brightness == Brightness.light
        ? AppPalette.light
        : AppPalette.dark;
    final colors = base.colors.copyWith(
      background: p.canvas,
      card: p.surface,
      foreground: p.text,
      primary: p.accent,
      primaryForeground: p.onAccent,
      secondary: p.surface,
      secondaryForeground: p.text,
      muted: p.canvas,
      mutedForeground: p.secondary,
      border: p.border,
      destructive: p.danger,
      destructiveForeground: p.canvas,
      error: p.danger,
      errorForeground: p.surface,
    );
    // Rebuild component styles so they inherit the updated palette.
    return FThemeData(
      colors: colors,
      touch: true,
      typography: base.typography,
      style: base.style.copyWith(
        borderRadius: const FBorderRadius(
          md: BorderRadius.all(Radius.circular(AppSpace.radius)),
        ),
        shadow: const [],
      ),
      hapticFeedback: const FHapticFeedback.none(),
    );
  }

  static ThemeData material(Brightness brightness) {
    final forui = brightness == Brightness.light ? light : dark;
    final p = brightness == Brightness.light
        ? AppPalette.light
        : AppPalette.dark;
    // Forui's approximate adapter targets package:material_ui. Keep the
    // existing Flutter Material controls and bridge their shared primitives.
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: forui.typography.body.fontFamily,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: p.onAccent,
        secondary: p.surface,
        onSecondary: p.text,
        error: p.danger,
        onError: p.canvas,
        surface: p.surface,
        onSurface: p.text,
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpace.radius),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: p.border),
    );
    final text = base.textTheme
        .copyWith(
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: p.text,
            height: 1.25,
          ),
          headlineSmall: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: p.text,
            height: 1.25,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: p.text,
            height: 1.25,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: p.text,
            height: 1.3,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: p.text,
            height: 1.3,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: p.text, height: 1.4),
          bodyMedium: TextStyle(fontSize: 14, color: p.text, height: 1.45),
          bodySmall: TextStyle(fontSize: 12, color: p.secondary, height: 1.4),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        )
        .apply(fontFamily: base.textTheme.bodyMedium?.fontFamily);
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      shape: WidgetStatePropertyAll(shape),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
    );
    return base.copyWith(
      scaffoldBackgroundColor: p.canvas,
      textTheme: text,
      colorScheme: base.colorScheme.copyWith(
        surface: p.surface,
        onSurface: p.text,
        onSurfaceVariant: p.secondary,
        outline: p.border,
        outlineVariant: p.border,
        surfaceContainerLow: p.surface,
        surfaceContainerHighest: p.surface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: p.canvas,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpace.page,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          statusBarBrightness: brightness,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: p.surface,
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: border.copyWith(borderSide: BorderSide(color: p.danger)),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: p.secondary),
        hintStyle: text.bodyMedium?.copyWith(color: p.secondary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: p.danger),
        errorMaxLines: 4,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: shape.copyWith(side: BorderSide(color: p.border)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? p.border : p.accent,
          ),
          foregroundColor: WidgetStatePropertyAll(p.onAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.copyWith(
          foregroundColor: WidgetStatePropertyAll(p.text),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: button.copyWith(
          foregroundColor: WidgetStatePropertyAll(p.accent),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accent.withValues(alpha: 0.12),
        checkmarkColor: p.accent,
        labelStyle: text.bodyMedium,
        side: BorderSide(color: p.border),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape.copyWith(side: BorderSide(color: p.border)),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.surface),
        shape: shape,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      iconTheme: IconThemeData(color: p.secondary, size: 20),
    );
  }
}
