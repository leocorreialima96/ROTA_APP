import 'package:flutter/material.dart';

/// Cores do protótipo.
class RotaColors {
  static const ink = Color(0xFF0B1730);
  static const inkSoft = Color(0xFF2B3A55);
  static const muted = Color(0xFF4A5A70);
  static const paper = Color(0xFFFBF8F2);
  static const card = Colors.white;
  static const line = Color(0xFFE7E1D4);
  static const lineSoft = Color(0xFFF1ECE2);
  static const band = Color(0xFFF6F1E7);
  static const sun = Color(0xFFFFB020);
  static const sunSoft = Color(0xFFFFF1D6);
  static const violet = Color(0xFF8B5CF6);
  static const mint = Color(0xFF2EE6C5);
  static const mintSoft = Color(0xFFCCFBF1);
  static const coral = Color(0xFFFF6B4A);
  static const link = Color(0xFFB45309);
  static const navy2 = Color(0xFF14244A);
  static const navy3 = Color(0xFF2A4677);
  static const onNavyMuted = Color(0xFFB9C6DA);
  static const ok = Color(0xFF2F9E5B);
  static const okText = Color(0xFF22603F);
  static const okSoft = Color(0xFFA7F3D0);
  static const alert = Color(0xFFE5483A);
  static const alertText = Color(0xFFB42318);
  static const alertDeep = Color(0xFF8F1D13);
  static const alertSoft = Color(0xFFFDECEA);
  static const alertLine = Color(0xFFF5C2BC);
}

/// Títulos em Space Grotesk (fonte variável: o peso vai por "wght").
TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color color = RotaColors.ink}) => TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      letterSpacing: -0.02 * size,
      color: color,
      height: 1.2,
    );

ThemeData rotaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RotaColors.sun,
    primary: RotaColors.ink,
    onPrimary: Colors.white,
    secondary: RotaColors.sun,
    onSecondary: RotaColors.ink,
    error: RotaColors.alertText,
    surface: RotaColors.paper,
    onSurface: RotaColors.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: RotaColors.paper,
  );
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: RotaColors.paper,
      foregroundColor: RotaColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: display(17),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: RotaColors.muted, fontWeight: FontWeight.w600, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: RotaColors.muted, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: Color(0xFF8A96A8)),
      border: border(RotaColors.line),
      enabledBorder: border(RotaColors.line),
      focusedBorder: border(RotaColors.ink, 2),
      errorBorder: border(RotaColors.alert),
      focusedErrorBorder: border(RotaColors.alert, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RotaColors.sun,
        foregroundColor: RotaColors.ink,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RotaColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: Color(0xFFDCD5C6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RotaColors.link,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: RotaColors.sunSoft,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? RotaColors.ink : RotaColors.muted,
          )),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: RotaColors.ink),
    dividerTheme: const DividerThemeData(color: RotaColors.lineSoft, space: 1),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RotaColors.ink : null),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RotaColors.ink : null),
    ),
  );
}
