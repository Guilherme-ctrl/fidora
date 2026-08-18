import 'package:flutter/material.dart';

const ink = Color(0xFF17211B);
const moss = Color(0xFF1F6B4F);
const mint = Color(0xFFCDEBDD);
const canvas = Color(0xFFF5F3EC);
const coral = Color(0xFFE06B4F);
const gold = Color(0xFFE5B653);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: moss, surface: canvas);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: moss,
      secondary: coral,
      tertiary: gold,
      surface: canvas,
      onSurface: ink,
    ),
    scaffoldBackgroundColor: canvas,
    cardTheme: const CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: mint,
      height: 72,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: mint,
      selectedIconTheme: IconThemeData(color: moss),
    ),
  );
}
