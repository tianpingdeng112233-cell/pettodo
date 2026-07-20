import 'package:flutter/material.dart';

import 'pet_colors.dart';

abstract final class PetTextStyles {
  static const String displayFamily = 'Baloo 2';
  static const List<String> displayFallback = <String>[
    'Arial Rounded MT Bold',
    'sans-serif',
  ];
  static const TextStyle display30 = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: displayFallback,
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: PetColors.display,
    letterSpacing: 2,
  );
  static const TextStyle display28 = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: displayFallback,
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: PetColors.display,
  );
  static const TextStyle display26 = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: displayFallback,
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: PetColors.display,
  );
  static const TextStyle display24 = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: displayFallback,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: PetColors.display,
  );
  static const TextStyle theaterLine = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: displayFallback,
    fontSize: 20,
    height: 1.5,
    fontWeight: FontWeight.w600,
    color: PetColors.theaterText,
  );
  static const TextStyle task = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: PetColors.bodyStrong,
  );
  static const TextStyle body17 = TextStyle(
    fontSize: 17,
    color: PetColors.bodyStrong,
  );
  static const TextStyle body16Strong = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: PetColors.bodyStrong,
  );
  static const TextStyle body16 = TextStyle(
    fontSize: 16,
    color: PetColors.bodyStrong,
  );
  static const TextStyle body15 = TextStyle(
    fontSize: 15,
    color: PetColors.body,
  );
  static const TextStyle body15Soft = TextStyle(
    fontSize: 15,
    color: PetColors.bodySoft,
  );
  static const TextStyle body15Strong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: PetColors.bodyStrong,
  );
  static const TextStyle status = TextStyle(
    fontSize: 14,
    color: PetColors.bodySoft,
  );
  static const TextStyle button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: PetColors.white,
  );
  static const TextStyle button16 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: PetColors.white,
  );
  static const TextStyle chip = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: PetColors.bodySoft,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: PetColors.caption,
  );
  static const TextStyle captionSoft = TextStyle(
    fontSize: 12.5,
    color: PetColors.bodySoft,
  );
  static const TextStyle small = TextStyle(
    fontSize: 12,
    color: PetColors.bodySoft,
  );
  static const TextStyle soon = TextStyle(
    fontSize: 11,
    color: PetColors.disabledCaption,
  );
  static const TextStyle secondaryLink = TextStyle(
    fontSize: 15,
    color: PetColors.disabledText,
  );
  static const TextStyle disabledSmall = TextStyle(
    fontSize: 12,
    color: PetColors.disabledCaption,
  );
  static const TextStyle chevron = TextStyle(
    fontSize: 16,
    color: PetColors.systemIcon,
  );
  static const TextStyle theaterLabel = TextStyle(
    fontSize: 11,
    letterSpacing: 3,
    fontWeight: FontWeight.w600,
    color: PetColors.theaterLabel,
  );
}
