import 'package:flutter/material.dart';

abstract final class PetRadii {
  static const double small = 8;
  static const double sprite = 16;
  static const double input = 16;
  static const double cardSmall = 20;
  static const double banner = 22;
  static const double card = 24;
  static const double pill = 999;
  static const BorderRadius spriteBorder = BorderRadius.all(
    Radius.circular(sprite),
  );
  static const BorderRadius inputBorder = BorderRadius.all(
    Radius.circular(input),
  );
  static const BorderRadius cardSmallBorder = BorderRadius.all(
    Radius.circular(cardSmall),
  );
  static const BorderRadius bannerBorder = BorderRadius.all(
    Radius.circular(banner),
  );
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius pillBorder = BorderRadius.all(
    Radius.circular(pill),
  );
}
