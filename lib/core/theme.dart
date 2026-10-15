import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/decor.dart';

/// "Reading room": desk-lamp green, paper white, ink gray, and lamp amber
/// used only where something needs attention.
class AppColors {
  static const Color green = Color(0xFF1F5F45);      // desk-lamp green
  static const Color greenDark = Color(0xFF15473A);
  static const Color greenSoft = Color(0xFFE6F0EA);
  static const Color lamp = Color(0xFFF2C14E);       // lamp light (seat grid, highlights on green)
  static const Color ink = Color(0xFF1E2522);
  static const Color muted = Color(0xFF66706B);
  static const Color line = Color(0xFFE3E7E4);
  static const Color bg = Color(0xFFFAFAF8);         // paper
  static const Color danger = Color(0xFFC62828);
  static const Color dangerSoft = Color(0xFFFCEBEB);
  static const Color warn = Color(0xFFB7791F);
  static const Color warnSoft = Color(0xFFFFF5E1);
  static const Color blue = Color(0xFF2B5DAA);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      surface: Colors.white,
      brightness: Brightness.light,
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    // Mukta has both Latin and Devanagari, so Hindi names look the same as English text.
    final text = GoogleFonts.getTextTheme('Mukta', ThemeData.light().textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.bg,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SoftPageTransitions(),
        TargetPlatform.iOS: SoftPageTransitions(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 21, color: AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: rounded),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.line),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.greenSoft,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
