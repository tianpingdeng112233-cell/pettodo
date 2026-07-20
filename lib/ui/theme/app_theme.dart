import 'package:flutter/material.dart';

import 'pet_colors.dart';
import 'pet_radii.dart';
import 'pet_text_styles.dart';

abstract final class AppTheme {
  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[PetColors.screenTop, PetColors.screenBottom],
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: PetColors.screenTop,
    colorScheme: const ColorScheme.light(
      primary: PetColors.primary,
      onPrimary: PetColors.white,
      secondary: PetColors.accentText,
      surface: PetColors.white,
      onSurface: PetColors.bodyStrong,
    ),
    textTheme: const TextTheme(
      headlineMedium: PetTextStyles.display26,
      titleLarge: PetTextStyles.display24,
      titleMedium: PetTextStyles.body16Strong,
      bodyLarge: PetTextStyles.body16,
      bodyMedium: PetTextStyles.body15,
      bodySmall: PetTextStyles.captionSoft,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: PetColors.inputFill,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: PetRadii.inputBorder,
        borderSide: BorderSide(color: PetColors.stroke, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: PetRadii.inputBorder,
        borderSide: BorderSide(color: PetColors.stroke, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: PetRadii.inputBorder,
        borderSide: BorderSide(color: PetColors.primary, width: 2),
      ),
      hintStyle: TextStyle(fontSize: 16, color: PetColors.caption),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: PetColors.primary,
      selectionColor: PetColors.doneFill,
    ),
  );
}
