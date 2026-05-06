import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: kBackground,
    cardColor: kCard,
    dividerColor: kDivider,
    useMaterial3: true,
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: kTextPrimary,
      displayColor: kTextPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kCard,
      foregroundColor: kTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
      ),
    ),
    cardTheme: CardTheme(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
        side: BorderSide(color: kDivider),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: kDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: kDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: const TextStyle(color: kTextSecondary, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kCard,
      selectedItemColor: kPrimary,
      unselectedItemColor: kTextSecondary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}
