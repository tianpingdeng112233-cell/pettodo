import 'package:flutter/material.dart';

import 'pet_colors.dart';
import 'pet_text_styles.dart';
import 'stair_border.dart';

abstract final class AppTheme {
  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[PetColors.screenTop, PetColors.screenBottom],
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: PetTextStyles.bodyFamily,
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
      border: StairInputBorder(
        borderSide: BorderSide(color: PetColors.stroke, width: 2),
      ),
      enabledBorder: StairInputBorder(
        borderSide: BorderSide(color: PetColors.stroke, width: 2),
      ),
      focusedBorder: StairInputBorder(
        borderSide: BorderSide(color: PetColors.primary, width: 2),
      ),
      hintStyle: PetTextStyles.inputHint,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StairBorder.large(),
        textStyle: PetTextStyles.button,
        minimumSize: const Size(0, 54),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StairBorder.large(),
        side: const BorderSide(color: PetColors.bodyStrong, width: 2),
        textStyle: PetTextStyles.button.copyWith(color: PetColors.bodyStrong),
        minimumSize: const Size(0, 54),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StairBorder.small(),
        textStyle: PetTextStyles.body16Strong,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          StairBorder.small(),
        ),
        textStyle: const WidgetStatePropertyAll<TextStyle>(
          PetTextStyles.body15Strong,
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(shape: StairBorder.large()),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PetColors.screenTop,
      shape: StairBorder.large(),
    ),
    snackBarTheme: const SnackBarThemeData(shape: StairBorder.small()),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: PetColors.primary,
      selectionColor: PetColors.doneFill,
    ),
  );
}
