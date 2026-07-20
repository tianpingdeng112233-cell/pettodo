import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color background = Color(0xFFFFF7E8);
  static const Color card = Color(0xFFFFFDF8);
  static const Color cocoa = Color(0xFF5A4034);
  static const Color honey = Color(0xFFF3B75B);
  static const Color mint = Color(0xFF9CC8AC);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: honey,
      brightness: Brightness.light,
      surface: card,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: cocoa, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: cocoa, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: cocoa, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: cocoa),
      bodyMedium: TextStyle(color: cocoa),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
}
