import 'package:flutter/material.dart';

/// Palet Mineral Stoneware & Deep Spring Teal (selaras DESIGN.md v4.0).
abstract final class ShcPalette {
  static const canvas = Color(0xFFF4F6F5);
  static const surface = Color(0xFFFBFCFB);
  static const subtle = Color(0xFFEAEEEC);
  static const hairline = Color(0xFFD7DFDC);
  static const controlBorder = Color(0xFF768782);

  static const ink = Color(0xFF16201E);
  static const inkSoft = Color(0xFF475652);
  static const muted = Color(0xFF5B6B66);

  static const accent = Color(0xFF0B5D6B);
  static const accentHover = Color(0xFF084853);
  static const accentSoft = Color(0xFFE3F0F2);
  static const accentInk = Color(0xFFFBFCFB);
  static const waterTop = Color(0xFF3B93A1);

  static const ok = Color(0xFF16654B);
  static const okBg = Color(0xFFE6F3EE);
  static const okBorder = Color(0xFFB7DDD0);

  static const warn = Color(0xFF8C4B0C);
  static const warnBg = Color(0xFFFDF3E3);
  static const warnBorder = Color(0xFFEED0A0);

  static const danger = Color(0xFF9B2C2C);
  static const dangerBg = Color(0xFFFBECEC);
  static const dangerBorder = Color(0xFFEBC1C1);
}

const String shcDisplayFont = 'SpaceGrotesk';
const String shcMonoFont = 'JetBrainsMono';
const List<FontFeature> _tabularFigures = [FontFeature.tabularFigures()];

TextStyle shcSans(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: shcDisplayFont,
      fontSize: size,
      color: color ?? ShcPalette.ink,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

TextStyle shcMono(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w500,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: shcMonoFont,
      fontSize: size,
      color: color ?? ShcPalette.ink,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: _tabularFigures,
    );

BoxDecoration shcCardDecoration({
  Color? color,
  Color? borderColor,
  double borderWidth = 1,
  double radius = 16,
}) =>
    BoxDecoration(
      color: color ?? ShcPalette.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? ShcPalette.hairline,
        width: borderWidth,
      ),
    );

InputDecoration shcInputDecoration({
  required String label,
  String? hint,
  String? helper,
  String? error,
  bool dense = false,
}) =>
    InputDecoration(
      isDense: dense,
      labelText: label,
      labelStyle: shcSans(12, color: ShcPalette.inkSoft, weight: FontWeight.w500),
      hintText: hint,
      hintStyle: shcSans(12, color: ShcPalette.muted),
      helperText: helper,
      helperStyle: shcSans(11, color: ShcPalette.muted),
      errorText: error,
      errorStyle: shcSans(11, color: ShcPalette.danger, weight: FontWeight.w500),
      filled: true,
      fillColor: ShcPalette.subtle,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ShcPalette.controlBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ShcPalette.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ShcPalette.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ShcPalette.danger, width: 2),
      ),
    );

ThemeData buildShcTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: ShcPalette.canvas,
      fontFamily: shcDisplayFont,
      colorScheme: const ColorScheme.light(
        surface: ShcPalette.surface,
        primary: ShcPalette.accent,
        onPrimary: ShcPalette.accentInk,
        secondary: ShcPalette.accent,
        onSecondary: ShcPalette.accentInk,
        error: ShcPalette.danger,
        onError: ShcPalette.accentInk,
        onSurface: ShcPalette.ink,
        outline: ShcPalette.controlBorder,
        outlineVariant: ShcPalette.hairline,
      ),
      dividerColor: ShcPalette.hairline,
      focusColor: ShcPalette.accent.withValues(alpha: 0.18),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ShcPalette.accent,
        selectionColor: ShcPalette.accentSoft,
        selectionHandleColor: ShcPalette.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ShcPalette.accentInk
              : ShcPalette.inkSoft,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ShcPalette.accent
              : ShcPalette.subtle,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ShcPalette.accent
              : ShcPalette.controlBorder,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ShcPalette.ink,
        contentTextStyle: shcSans(13, color: ShcPalette.surface, weight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ShcPalette.accent,
          foregroundColor: ShcPalette.accentInk,
          textStyle: shcSans(13, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ShcPalette.ink,
          side: const BorderSide(color: ShcPalette.controlBorder),
          textStyle: shcSans(12, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(48, 48),
        ),
      ),
    );
